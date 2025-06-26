import express from 'express';
import cors from 'cors';
import { config } from 'dotenv';
import { Pool } from 'pg';
import axios from 'axios';

// 환경 변수 로드
config();

const app = express();
const PORT = parseInt(process.env.PORT || '8888', 10);

// PostgreSQL 연결
const pool = new Pool({
  host: process.env.DB_HOST || 'mkt.techb.kr',
  user: process.env.DB_USER || 'techb_pp',
  password: process.env.DB_PASSWORD || 'Tech1324!',
  database: process.env.DB_NAME || 'productparser_db',
  port: parseInt(process.env.DB_PORT || '5432'),
});

// 미들웨어
app.use(cors());
app.use(express.json());

// 에이전트 관리
const agents = new Map();

// 헬스 체크
app.get('/health', (_, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    agents: agents.size
  });
});

// 에이전트 하트비트
app.put('/agents/:id/heartbeat', async (req, res) => {
  const { id } = req.params;
  const { status, platform, actions, metadata } = req.body;
  
  // 요청 IP 주소 가져오기
  const clientIp = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
  const agentHost = metadata?.host || clientIp?.toString().replace('::ffff:', '') || 'localhost';
  
  const now = new Date();
  agents.set(id, {
    id,
    status,
    platform,
    actions: actions || [],
    lastHeartbeat: now,
    isActive: true,
    metadata: {
      ...metadata,
      host: agentHost
    }
  });

  // DB 업데이트
  try {
    await pool.query(
      `INSERT INTO pp.agents (agent_id, pc_id, port, status, last_heartbeat, platform)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (agent_id) 
       DO UPDATE SET 
         status = $4,
         last_heartbeat = $5,
         platform = $6`,
      [id, id.split('-')[1], parseInt(id.split('-')[2]), status, now, platform]
    );
  } catch (error) {
    console.error('DB 업데이트 실패:', error);
  }

  console.log(`[Heartbeat] ${id} - Status: ${status}, Platform: ${platform}`);
  
  res.json({ 
    status: 'ok',
    message: 'Heartbeat received',
    timestamp: now.toISOString()
  });
});

// 에이전트 목록
app.get('/agents', (_, res) => {
  const activeAgents = Array.from(agents.values()).filter(agent => {
    const timeDiff = Date.now() - new Date(agent.lastHeartbeat).getTime();
    return timeDiff < 90000; // 90초 이내
  });

  res.json({
    total: activeAgents.length,
    agents: activeAgents
  });
});

// 파싱 요청
app.post('/parse', async (req, res): Promise<void> => {
  const { keyword, site = 'naver', mode = 'fast', agentCount = 2 } = req.body;
  
  console.log(`[Parse Request] Keyword: ${keyword}, Site: ${site}, Mode: ${mode}, AgentCount: ${agentCount}`);
  
  // 활성 에이전트 찾기
  const activeAgents = Array.from(agents.values()).filter(agent => {
    const timeDiff = Date.now() - new Date(agent.lastHeartbeat).getTime();
    return timeDiff < 90000 && agent.status === 'active';
  });

  if (activeAgents.length === 0) {
    res.status(503).json({
      error: 'No active agents available'
    });
    return;
  }

  // 요청할 에이전트 수 결정
  const selectedCount = Math.min(agentCount, activeAgents.length);
  const selectedAgents = activeAgents.slice(0, selectedCount);
  
  console.log(`[Parse] Selected ${selectedCount} agents for request`);

  // 요청 ID 생성
  const requestId = `req-${Date.now()}`;
  
  try {
    // 응답 타입 정의
    type AgentResponse = {
      agentId: string;
      responseTime: number;
      success: boolean;
      status: number | string;
      response?: any;
      error?: string;
    };

    // 각 에이전트에 파싱 요청 전송
    const agentPromises: Promise<AgentResponse>[] = selectedAgents.map(agent => {
      // 에이전트 메타데이터에서 URL 가져오기 (없으면 localhost 사용)
      const agentHost = agent.metadata?.host || 'localhost';
      const agentPort = agent.id.split('-')[2];
      const agentUrl = `http://${agentHost}:${agentPort}/execute`;
      console.log(`[Parse] Sending request to agent ${agent.id} at ${agentUrl}`);
      
      return axios.post(agentUrl, {
        action: 'naver-shopping-search',
        params: {
          keyword,
          site,
          requestId,
          screenshot: true
        }
      }, {
        timeout: 30000, // 30초 타임아웃
        validateStatus: () => true // 모든 상태 코드 허용
      }).then(response => ({
        agentId: agent.id,
        response: response.data,
        status: response.status,
        responseTime: Date.now() - startTime,
        success: true
      })).catch(error => ({
        agentId: agent.id,
        error: error.message,
        status: 'error',
        responseTime: Date.now() - startTime,
        success: false
      }));
    });

    const startTime = Date.now();
    let result: AgentResponse | undefined;

    if (mode === 'fast') {
      // Fast 모드: 가장 빠른 성공 응답 사용
      result = await Promise.race(agentPromises.map(promise => 
        promise.then(res => {
          if (res.success && res.status === 200 && res.response?.success) {
            console.log(`[Parse] Fast mode: Agent ${res.agentId} responded first in ${res.responseTime}ms`);
            return res;
          }
          throw new Error(`Agent ${res.agentId} failed`);
        })
      ));
    } else {
      // Reliable 모드: 모든 응답 대기 후 가장 좋은 결과 선택
      const results = await Promise.allSettled(agentPromises);
      const successResults = results
        .filter((r): r is PromiseFulfilledResult<AgentResponse> => 
          r.status === 'fulfilled' && r.value.success && r.value.status === 200 && r.value.response?.success
        )
        .map(r => r.value);
      
      if (successResults.length > 0) {
        result = successResults[0]; // 첫 번째 성공 결과 사용
        console.log(`[Parse] Reliable mode: ${successResults.length} successful responses`);
      } else {
        throw new Error('No successful responses from agents');
      }
    }

    if (!result) {
      throw new Error('No result available');
    }

    // 결과를 DB에 저장
    await pool.query(
      `INSERT INTO pp.parsing_results (request_id, keyword, site, mode, result, agent_id, response_time)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [requestId, keyword, site, mode, JSON.stringify(result.response), result.agentId, result.responseTime]
    );

    // 클라이언트에 응답
    res.json({
      status: 'success',
      requestId,
      keyword,
      site,
      mode,
      agentId: result.agentId,
      responseTime: result.responseTime,
      data: result.response?.data
    });

  } catch (error: any) {
    console.error('[Parse] Request failed:', error);
    res.status(500).json({
      status: 'error',
      requestId,
      error: error.message || 'Unknown error'
    });
  }
});

// 서버 시작
app.listen(PORT, '0.0.0.0', () => {
  console.log(`
===========================================
  ParserHub Server Started
===========================================
  Port: ${PORT}
  Environment: ${process.env.NODE_ENV || 'development'}
  Database: ${process.env.DB_HOST || 'mkt.techb.kr'}
  
  Endpoints:
  - Health: http://localhost:${PORT}/health
  - Agents: http://localhost:${PORT}/agents
  - Parse: http://localhost:${PORT}/parse
===========================================
  `);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing server...');
  await pool.end();
  process.exit(0);
});