#!/bin/bash

# Heartbeat 수정 패치 스크립트
# 사용법: curl -sSL https://raw.githubusercontent.com/service0427/ProductParser/main/patch-heartbeat.sh | bash

set -e

echo "=== ProductParser 에이전트 Heartbeat 패치 ==="
echo ""

# 에이전트 디렉토리 찾기
AGENT_DIR=""
if [ -d "$HOME/product-agent" ]; then
    AGENT_DIR="$HOME/product-agent"
elif [ -d "/c/Users/tech/product-agent" ]; then
    AGENT_DIR="/c/Users/tech/product-agent"
elif [ -d "./agent" ]; then
    AGENT_DIR="./agent"
else
    echo "❌ 에이전트 디렉토리를 찾을 수 없습니다."
    exit 1
fi

echo "✅ 에이전트 디렉토리: $AGENT_DIR"

# heartbeat.js 백업
if [ -f "$AGENT_DIR/core/heartbeat.js" ]; then
    cp "$AGENT_DIR/core/heartbeat.js" "$AGENT_DIR/core/heartbeat.js.backup.$(date +%Y%m%d%H%M%S)"
    echo "✅ 백업 생성 완료"
fi

# 수정된 heartbeat.js 다운로드
echo "📥 수정된 heartbeat.js 다운로드 중..."
cat > "$AGENT_DIR/core/heartbeat.js" << 'EOF'
const axios = require('axios');
const os = require('os');

class HeartbeatManager {
  constructor() {
    this.interval = null;
    this.isRunning = false;
    this.lastHeartbeat = null;
    this.failureCount = 0;
  }

  async sendHeartbeat(config) {
    try {
      const systemInfo = this.getSystemInfo();
      
      // 허브의 올바른 엔드포인트 사용
      const url = `${config.hubUrl}/agents/${config.agentId}/heartbeat`;
      
      const data = {
        status: 'active',
        platform: process.platform,
        actions: ['naver-shopping-search', 'naver-finance'],
        metadata: {
          pcId: config.pcId,
          port: config.port,
          system: systemInfo,
          uptime: process.uptime()
        }
      };
      
      // PUT 메소드 사용
      const response = await axios.put(url, data, { 
        timeout: 5000,
        headers: {
          'Content-Type': 'application/json'
        }
      });
      
      this.lastHeartbeat = new Date();
      this.failureCount = 0;
      
      console.log(`[${new Date().toLocaleTimeString()}] Heartbeat sent successfully`);
      
      return response.data;
      
    } catch (error) {
      this.failureCount++;
      console.error(`[${new Date().toLocaleTimeString()}] Heartbeat failed:`, error.message);
      
      // 10번 연속 실패 시 경고
      if (this.failureCount >= 10) {
        console.error('WARNING: Unable to connect to hub for 10 consecutive attempts');
      }
      
      throw error;
    }
  }

  getSystemInfo() {
    return {
      hostname: os.hostname(),
      platform: os.platform(),
      arch: os.arch(),
      cpus: os.cpus().length,
      totalMemory: os.totalmem(),
      freeMemory: os.freemem(),
      nodeVersion: process.version
    };
  }

  start(config) {
    if (this.isRunning) {
      console.log('Heartbeat is already running');
      return;
    }

    console.log(`Starting heartbeat with interval: ${config.heartbeatInterval}ms`);
    this.isRunning = true;

    // 초기 하트비트
    this.sendHeartbeat(config).catch(err => {
      console.error('Initial heartbeat failed:', err.message);
    });

    // 정기적인 하트비트
    this.interval = setInterval(() => {
      this.sendHeartbeat(config).catch(err => {
        // 에러는 sendHeartbeat에서 처리됨
      });
    }, config.heartbeatInterval || 30000);
  }

  stop() {
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
      this.isRunning = false;
      console.log('Heartbeat stopped');
    }
  }

  getStatus() {
    return {
      isRunning: this.isRunning,
      lastHeartbeat: this.lastHeartbeat,
      failureCount: this.failureCount
    };
  }
}

module.exports = new HeartbeatManager();
EOF

echo "✅ heartbeat.js 수정 완료"

# PM2 재시작
if command -v pm2 &> /dev/null; then
    echo "🔄 PM2 프로세스 재시작..."
    pm2 restart all
    echo "✅ 재시작 완료"
else
    echo "⚠️  PM2가 없습니다. 에이전트를 수동으로 재시작하세요."
fi

echo ""
echo "=== 패치 완료 ==="
echo ""
echo "테스트:"
echo "  curl http://mkt.techb.kr:8888/agents"