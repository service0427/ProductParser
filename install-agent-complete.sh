#!/bin/bash

# ProductParser 에이전트 완전 자동 설치 스크립트
# 사용법: curl -sSL https://raw.githubusercontent.com/service0427/ProductParser/main/install-agent-complete.sh | bash

set -e

echo "=== ProductParser 에이전트 자동 설치 시작 ==="
echo "설치 날짜: $(date)"
echo ""

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 기본 설정
INSTALL_DIR="${AGENT_INSTALL_DIR:-$HOME/product-agent}"
HUB_URL="${HUB_URL:-http://mkt.techb.kr:8888}"
AGENT_PORT="${AGENT_PORT:-4001}"
AGENT_ID="${AGENT_ID:-agent-$(hostname)-$AGENT_PORT}"

echo -e "${YELLOW}설치 정보:${NC}"
echo "  설치 디렉토리: $INSTALL_DIR"
echo "  허브 URL: $HUB_URL"
echo "  에이전트 ID: $AGENT_ID"
echo "  에이전트 포트: $AGENT_PORT"
echo ""

# 1. OS 확인 및 패키지 매니저 설정
echo -e "${YELLOW}[1/8] 시스템 확인...${NC}"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        PKG_UPDATE="sudo apt-get update"
        PKG_INSTALL="sudo apt-get install -y"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        PKG_UPDATE="sudo yum update -y"
        PKG_INSTALL="sudo yum install -y"
    else
        echo -e "${RED}지원하지 않는 리눅스 배포판입니다.${NC}"
        exit 1
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    PKG_MANAGER="brew"
    PKG_UPDATE="brew update"
    PKG_INSTALL="brew install"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS="windows"
else
    echo -e "${RED}지원하지 않는 운영체제입니다: $OSTYPE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ OS: $OS${NC}"

# 2. Git 설치 확인 및 설치
echo -e "${YELLOW}[2/8] Git 확인...${NC}"
if ! command -v git &> /dev/null; then
    echo "Git이 없습니다. 설치합니다..."
    
    if [ "$OS" == "windows" ]; then
        echo -e "${YELLOW}Windows에서는 Git을 수동으로 설치해주세요:${NC}"
        echo "https://git-scm.com/download/windows"
        echo "설치 후 다시 실행해주세요."
        exit 1
    elif [ "$OS" == "linux" ]; then
        $PKG_UPDATE
        $PKG_INSTALL git
    elif [ "$OS" == "macos" ]; then
        $PKG_INSTALL git
    fi
else
    echo -e "${GREEN}✓ Git이 이미 설치되어 있습니다.${NC}"
fi

# 3. Node.js 설치 확인 및 설치
echo -e "${YELLOW}[3/8] Node.js 확인...${NC}"
if ! command -v node &> /dev/null; then
    echo "Node.js가 없습니다. 설치합니다..."
    
    if [ "$OS" == "windows" ]; then
        echo -e "${YELLOW}Windows에서는 Node.js를 수동으로 설치해주세요:${NC}"
        echo "https://nodejs.org/"
        echo "설치 후 다시 실행해주세요."
        exit 1
    elif [ "$OS" == "linux" ]; then
        # NodeSource 리포지토리 사용
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        $PKG_INSTALL nodejs
    elif [ "$OS" == "macos" ]; then
        $PKG_INSTALL node
    fi
else
    echo -e "${GREEN}✓ Node.js가 이미 설치되어 있습니다. ($(node -v))${NC}"
fi

# 4. 기존 설치 확인
echo -e "${YELLOW}[4/8] 기존 설치 확인...${NC}"
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}기존 설치가 발견되었습니다: $INSTALL_DIR${NC}"
    echo "백업하고 새로 설치합니다..."
    mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d%H%M%S)"
fi

# 5. Git Clone
echo -e "${YELLOW}[5/8] 코드 다운로드...${NC}"
git clone https://github.com/service0427/ProductParser.git "$INSTALL_DIR.tmp"
mv "$INSTALL_DIR.tmp/agent" "$INSTALL_DIR"
rm -rf "$INSTALL_DIR.tmp"

# 6. 설정 파일 생성
echo -e "${YELLOW}[6/8] 설정 파일 생성...${NC}"
cd "$INSTALL_DIR"

# config.json 생성
cat > config.json << EOF
{
  "agentId": "$AGENT_ID",
  "pcId": "$(hostname)",
  "port": $AGENT_PORT,
  "hubUrl": "$HUB_URL",
  "heartbeatInterval": 30000
}
EOF

# .env 파일 생성
cat > .env << EOF
AGENT_ID=$AGENT_ID
PC_ID=$(hostname)
PORT=$AGENT_PORT
HUB_URL=$HUB_URL
HEARTBEAT_INTERVAL=30000
NODE_ENV=production
EOF

echo -e "${GREEN}✓ 설정 파일 생성 완료${NC}"

# 7. npm 패키지 설치
echo -e "${YELLOW}[7/8] 의존성 설치...${NC}"
npm install --production

# Playwright 브라우저 설치
echo "Playwright 브라우저 설치..."
npx playwright install chromium

# 8. PM2 설치 및 실행 (선택사항)
echo -e "${YELLOW}[8/8] PM2 설정...${NC}"
if command -v pm2 &> /dev/null; then
    echo -e "${GREEN}PM2가 이미 설치되어 있습니다.${NC}"
else
    echo "PM2 설치 중..."
    npm install -g pm2
fi

# PM2 ecosystem 파일 생성
cat > ecosystem.config.js << EOF
module.exports = {
  apps: [{
    name: 'product-agent-$AGENT_PORT',
    script: './agent.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      AGENT_ID: '$AGENT_ID',
      PORT: $AGENT_PORT,
      HUB_URL: '$HUB_URL'
    }
  }]
}
EOF

# 완료 메시지
echo ""
echo -e "${GREEN}=== 설치 완료! ===${NC}"
echo ""
echo -e "${YELLOW}에이전트 실행 방법:${NC}"
echo ""
echo "1. 직접 실행:"
echo "   cd $INSTALL_DIR"
echo "   node agent.js"
echo ""
echo "2. PM2로 실행 (권장):"
echo "   cd $INSTALL_DIR"
echo "   pm2 start ecosystem.config.js"
echo "   pm2 save"
echo "   pm2 startup  # 시스템 재시작시 자동 실행"
echo ""
echo "3. 백그라운드 실행:"
echo "   cd $INSTALL_DIR"
echo "   nohup node agent.js > agent.log 2>&1 &"
echo ""
echo -e "${GREEN}테스트:${NC}"
echo "   curl $HUB_URL/agents"
echo ""

# 자동 실행 옵션
if [ "$AUTO_START" == "true" ]; then
    echo -e "${YELLOW}자동 시작 모드: PM2로 에이전트를 시작합니다...${NC}"
    pm2 start ecosystem.config.js
    pm2 save
    echo -e "${GREEN}✓ 에이전트가 시작되었습니다!${NC}"
    echo "상태 확인: pm2 status"
fi