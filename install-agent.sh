#!/bin/bash
# ProductParser Agent 원클릭 설치 스크립트
# Git Bash 또는 Linux에서 실행 가능

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 기본 설정값
DEFAULT_INSTALL_PATH="C:/ProductParser"
DEFAULT_HUB_URL="http://localhost:8888"
DEFAULT_PC_IP="61.84.75.16"

# 설치 경로 입력 받기
echo -e "${CYAN}=== ProductParser Agent 설치 ===${NC}"
echo ""
read -p "설치 경로 [$DEFAULT_INSTALL_PATH]: " INSTALL_PATH
INSTALL_PATH=${INSTALL_PATH:-$DEFAULT_INSTALL_PATH}

# 허브 서버 URL 입력
read -p "허브 서버 URL [$DEFAULT_HUB_URL]: " HUB_URL
HUB_URL=${HUB_URL:-$DEFAULT_HUB_URL}

# PC IP 입력
read -p "PC IP 주소 [$DEFAULT_PC_IP]: " PC_IP
PC_IP=${PC_IP:-$DEFAULT_PC_IP}

# Windows 경로를 Unix 스타일로 변환
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    # Git Bash on Windows
    IS_WINDOWS=true
    UNIX_PATH=$(echo "$INSTALL_PATH" | sed 's|\\|/|g' | sed 's|C:|/c|g')
    WIN_PATH=$(echo "$INSTALL_PATH" | sed 's|/c/|C:/|g')
else
    # Linux/Mac
    IS_WINDOWS=false
    UNIX_PATH="$INSTALL_PATH"
    WIN_PATH="$INSTALL_PATH"
fi

echo ""
echo -e "${YELLOW}설치 정보:${NC}"
echo "  설치 경로: $INSTALL_PATH"
echo "  허브 서버: $HUB_URL"
echo "  PC IP: $PC_IP"
echo ""

# Git 확인
echo -e "${YELLOW}Git 확인 중...${NC}"
if ! command -v git &> /dev/null; then
    echo -e "${RED}Git이 설치되지 않았습니다!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Git 설치 확인${NC}"

# Node.js 확인
echo -e "${YELLOW}Node.js 확인 중...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js가 설치되지 않았습니다!${NC}"
    echo "https://nodejs.org 에서 설치하세요."
    exit 1
fi
echo -e "${GREEN}✓ Node.js $(node --version)${NC}"

# Chrome 확인 (Windows인 경우)
if [ "$IS_WINDOWS" = true ]; then
    echo -e "${YELLOW}Chrome 확인 중...${NC}"
    CHROME_PATH="/c/Program Files/Google/Chrome/Application/chrome.exe"
    if [ -f "$CHROME_PATH" ]; then
        echo -e "${GREEN}✓ Chrome 설치 확인${NC}"
    else
        echo -e "${YELLOW}⚠ Chrome이 기본 경로에 없습니다${NC}"
    fi
fi

# 기존 디렉토리 백업
if [ -d "$UNIX_PATH" ]; then
    BACKUP_PATH="${UNIX_PATH}.backup.$(date +%Y%m%d-%H%M%S)"
    echo -e "${YELLOW}기존 디렉토리 백업 중...${NC}"
    mv "$UNIX_PATH" "$BACKUP_PATH"
    echo -e "${GREEN}✓ 백업 완료: $BACKUP_PATH${NC}"
fi

# 디렉토리 생성
echo -e "${YELLOW}디렉토리 생성 중...${NC}"
mkdir -p "$UNIX_PATH"
cd "$UNIX_PATH"

# GitHub에서 코드 다운로드
echo -e "${YELLOW}GitHub에서 코드 다운로드 중...${NC}"
git clone -b dev https://github.com/service0427/ProductParser.git . || {
    echo -e "${RED}Git clone 실패!${NC}"
    exit 1
}
echo -e "${GREEN}✓ 코드 다운로드 완료${NC}"

# 에이전트 디렉토리로 이동
cd "$UNIX_PATH/agent"

# npm 패키지 설치
echo -e "${YELLOW}NPM 패키지 설치 중...${NC}"
npm install || {
    echo -e "${RED}NPM 설치 실패!${NC}"
    exit 1
}
echo -e "${GREEN}✓ NPM 패키지 설치 완료${NC}"

# 환경 설정 파일 생성
echo -e "${YELLOW}환경 설정 파일 생성 중...${NC}"

if [ "$IS_WINDOWS" = true ]; then
    # Windows용 .env 파일
    cat > .env << EOF
# Windows 환경 설정
PORT=4001
AGENT_ID=PC-$PC_IP-4001
PC_ID=PC-$PC_IP
HUB_URL=$HUB_URL
PLATFORM=windows
CHROME_EXECUTABLE_PATH=C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe
USER_DATA_DIR=$WIN_PATH\\chrome-profiles
LOG_LEVEL=info
LOG_DIR=$WIN_PATH\\agent\\logs
HEARTBEAT_INTERVAL=30
TASK_TIMEOUT=60000
SCREENSHOT_DIR=$WIN_PATH\\agent\\screenshots
DEBUG=false
EOF
else
    # Linux용 .env 파일
    cat > .env << EOF
# Linux 환경 설정
PORT=4001
AGENT_ID=PC-$PC_IP-4001
PC_ID=PC-$PC_IP
HUB_URL=$HUB_URL
PLATFORM=linux
CHROME_EXECUTABLE_PATH=/usr/bin/google-chrome
USER_DATA_DIR=$UNIX_PATH/chrome-profiles
LOG_LEVEL=info
LOG_DIR=$UNIX_PATH/agent/logs
HEARTBEAT_INTERVAL=30
TASK_TIMEOUT=60000
SCREENSHOT_DIR=$UNIX_PATH/agent/screenshots
DEBUG=false
EOF
fi

echo -e "${GREEN}✓ .env 파일 생성 완료${NC}"

# 필요한 디렉토리 생성
mkdir -p logs screenshots "$UNIX_PATH/chrome-profiles"

# 실행 스크립트 생성
if [ "$IS_WINDOWS" = true ]; then
    # Windows용 start-agents.sh (Git Bash에서 실행)
    cat > "$UNIX_PATH/start-agents.sh" << 'EOF'
#!/bin/bash
# Git Bash에서 실행하는 에이전트 시작 스크립트

cd "$(dirname "$0")/agent"

echo "=== ProductParser Agent 시작 ==="
echo ""

# 5개 포트에서 에이전트 실행
for port in {4001..4005}; do
    echo "포트 $port 에이전트 시작 중..."
    PORT=$port AGENT_ID=PC-$PC_IP-$port node agent.js &
    sleep 2
done

echo ""
echo "=== 모든 에이전트가 시작되었습니다 ==="
echo "종료하려면 Ctrl+C를 누르세요"
echo ""

# 프로세스가 종료되지 않도록 대기
wait
EOF

    # Windows용 배치 파일도 생성
    cat > "$UNIX_PATH/start-agents.bat" << EOF
@echo off
cd /d $WIN_PATH\\agent

echo === ProductParser Agent 시작 중 ===
echo.

start "Agent-4001" cmd /k "set PORT=4001 && set AGENT_ID=PC-$PC_IP-4001 && npm start"
timeout /t 2 /nobreak >nul

start "Agent-4002" cmd /k "set PORT=4002 && set AGENT_ID=PC-$PC_IP-4002 && npm start"
timeout /t 2 /nobreak >nul

start "Agent-4003" cmd /k "set PORT=4003 && set AGENT_ID=PC-$PC_IP-4003 && npm start"
timeout /t 2 /nobreak >nul

start "Agent-4004" cmd /k "set PORT=4004 && set AGENT_ID=PC-$PC_IP-4004 && npm start"
timeout /t 2 /nobreak >nul

start "Agent-4005" cmd /k "set PORT=4005 && set AGENT_ID=PC-$PC_IP-4005 && npm start"

echo.
echo === 모든 에이전트가 시작되었습니다 ===
pause
EOF
else
    # Linux용 start-agents.sh
    cat > "$UNIX_PATH/start-agents.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")/agent"

echo "=== ProductParser Agent 시작 ==="
echo ""

for port in {4001..4005}; do
    echo "포트 $port 에이전트 시작 중..."
    PORT=$port AGENT_ID=PC-$PC_IP-$port nohup node agent.js > logs/agent-$port.log 2>&1 &
    echo $! > logs/agent-$port.pid
    sleep 2
done

echo ""
echo "=== 모든 에이전트가 백그라운드에서 시작되었습니다 ==="
echo "로그 확인: tail -f logs/agent-*.log"
EOF
fi

chmod +x "$UNIX_PATH/start-agents.sh"

# 업데이트 스크립트 생성
cat > "$UNIX_PATH/update.sh" << 'EOF'
#!/bin/bash
# ProductParser 업데이트 스크립트

cd "$(dirname "$0")"

echo "=== ProductParser 업데이트 ==="
echo ""

# Git pull
echo "코드 업데이트 중..."
git pull origin dev || {
    echo "Git pull 실패!"
    exit 1
}

# npm 패키지 업데이트
cd agent
echo "패키지 업데이트 중..."
npm install

echo ""
echo "✓ 업데이트 완료!"
echo "에이전트를 재시작하세요."
EOF

chmod +x "$UNIX_PATH/update.sh"

# 상태 확인 스크립트
cat > "$UNIX_PATH/check-agents.sh" << EOF
#!/bin/bash
# 에이전트 상태 확인 스크립트

echo "=== ProductParser Agent 상태 확인 ==="
echo "시간: \$(date '+%Y-%m-%d %H:%M:%S')"
echo ""

for port in {4001..4005}; do
    echo -n "Port \$port: "
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:\$port/health | grep -q "200"; then
        echo -e "\033[0;32mRUNNING\033[0m"
    else
        echo -e "\033[0;31mOFFLINE\033[0m"
    fi
done
EOF

chmod +x "$UNIX_PATH/check-agents.sh"

# 설치 완료
echo ""
echo -e "${GREEN}=== 설치 완료! ===${NC}"
echo ""
echo -e "${CYAN}설치 경로:${NC} $INSTALL_PATH"
echo -e "${CYAN}에이전트 ID:${NC} PC-$PC_IP-[4001-4005]"
echo -e "${CYAN}허브 서버:${NC} $HUB_URL"
echo ""
echo -e "${YELLOW}실행 방법:${NC}"
if [ "$IS_WINDOWS" = true ]; then
    echo -e "  Git Bash: ${CYAN}$UNIX_PATH/start-agents.sh${NC}"
    echo -e "  CMD/PowerShell: ${CYAN}$WIN_PATH\\start-agents.bat${NC}"
else
    echo -e "  실행: ${CYAN}$UNIX_PATH/start-agents.sh${NC}"
fi
echo ""
echo -e "${YELLOW}기타 명령:${NC}"
echo -e "  상태 확인: ${CYAN}$UNIX_PATH/check-agents.sh${NC}"
echo -e "  업데이트: ${CYAN}$UNIX_PATH/update.sh${NC}"
echo ""

# 실행 여부 확인
read -p "지금 에이전트를 시작하시겠습니까? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ "$IS_WINDOWS" = true ]; then
        # Windows에서는 새 창에서 실행
        echo "새 창에서 에이전트를 시작합니다..."
        cmd.exe /c "start $WIN_PATH\\start-agents.bat"
    else
        # Linux에서는 백그라운드 실행
        "$UNIX_PATH/start-agents.sh"
    fi
fi