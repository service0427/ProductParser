const express = require('express');
const dotenv = require('dotenv');
const path = require('path');
const platform = require('./platform');

// 환경 변수 로드
const envFile = platform.isWindows() ? '.env.windows' : '.env.linux';
dotenv.config({ path: envFile });

// 모듈 로드
const heartbeatManager = require('./core/heartbeat');
const actionRunner = require('./core/actionRunner');
const config = require('./config.json');

// Express 앱 생성
const app = express();
app.use(express.json({ limit: '50mb' })); // 스크린샷 등 큰 데이터 처리

// 로깅 미들웨어
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// Health check 엔드포인트
app.get('/health', (req, res) => {
  const heartbeatStatus = heartbeatManager.getStatus();
  const runningActions = actionRunner.getRunningActions();
  
  res.json({
    status: 'active',
    agentId: config.agentId,
    pcId: config.pcId,
    port: config.port,
    platform: process.platform,
    uptime: process.uptime(),
    heartbeat: heartbeatStatus,
    runningActions: runningActions.length,
    timestamp: new Date().toISOString()
  });
});

// 에이전트 정보
app.get('/info', (req, res) => {
  res.json({
    agentId: config.agentId,
    pcId: config.pcId,
    version: require('./package.json').version,
    platform: {
      type: process.platform,
      node: process.version,
      chrome: platform.getChromePath()
    },
    capabilities: {
      actions: ['naver-finance'],
      features: ['screenshot', 'detailed-mode']
    }
  });
});

// 액션 실행
app.post('/execute', async (req, res) => {
  const { action, params = {} } = req.body;
  
  if (!action) {
    return res.status(400).json({
      success: false,
      error: 'Action name is required'
    });
  }
  
  console.log(`[Agent] Executing action: ${action}`);
  
  try {
    const result = await actionRunner.runAction(action, params);
    res.json(result);
  } catch (error) {
    console.error(`[Agent] Action execution failed:`, error);
    res.status(500).json({
      success: false,
      error: error.message,
      stack: error.stack
    });
  }
});

// 액션 업데이트 수신
app.post('/update-action', async (req, res) => {
  const { name, code, metadata } = req.body;
  
  if (!name || !code) {
    return res.status(400).json({
      success: false,
      error: 'Action name and code are required'
    });
  }
  
  console.log(`[Agent] Updating action: ${name} (v${metadata?.version || 'unknown'})`);
  
  try {
    const saved = await actionRunner.saveAction(name, code);
    
    res.json({
      success: saved,
      message: saved ? 'Action updated successfully' : 'Failed to save action'
    });
  } catch (error) {
    console.error(`[Agent] Failed to update action:`, error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// 실행 중인 액션 목록
app.get('/running', (req, res) => {
  const running = actionRunner.getRunningActions();
  res.json({
    count: running.length,
    actions: running
  });
});

// 프로필 관리
app.get('/profile', async (req, res) => {
  const profileManager = require('./core/profileManager');
  const profiles = await profileManager.listProfiles();
  
  res.json({
    currentPort: config.port,
    profilePath: platform.getProfilePath(config.port),
    allProfiles: profiles
  });
});

// 404 처리
app.use((req, res) => {
  res.status(404).json({
    error: 'Endpoint not found',
    available: [
      'GET /health',
      'GET /info',
      'POST /execute',
      'POST /update-action',
      'GET /running',
      'GET /profile'
    ]
  });
});

// 에러 처리
app.use((err, req, res, next) => {
  console.error('[Agent] Unhandled error:', err);
  res.status(500).json({
    error: 'Internal server error',
    message: err.message
  });
});

// 서버 시작
const PORT = process.env.AGENT_PORT || config.port || 3001;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`
===========================================
  ProductParser Agent Started
===========================================
  Agent ID: ${config.agentId}
  PC ID: ${config.pcId}
  Port: ${PORT}
  Platform: ${process.platform}
  Hub URL: ${config.hubUrl}
  Environment: ${envFile}
===========================================
  `);
  
  // 하트비트 시작
  heartbeatManager.start(config);
  
  console.log('[Agent] Ready to receive commands');
});

// 종료 처리
process.on('SIGINT', () => {
  console.log('\n[Agent] Shutting down...');
  heartbeatManager.stop();
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n[Agent] Shutting down...');
  heartbeatManager.stop();
  process.exit(0);
});