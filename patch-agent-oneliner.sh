#!/bin/bash

# ProductParser 에이전트 패치 스크립트
# 사용법: curl -sSL https://raw.githubusercontent.com/[YOUR_REPO]/patch-agent-oneliner.sh | bash

set -e

echo "=== ProductParser 에이전트 패치 시작 ==="
echo "패치 날짜: $(date)"
echo ""

# 에이전트 디렉토리 찾기
AGENT_DIR=""
if [ -d "/opt/product-agent" ]; then
    AGENT_DIR="/opt/product-agent"
elif [ -d "$HOME/product-agent" ]; then
    AGENT_DIR="$HOME/product-agent"
elif [ -d "$HOME/agent" ]; then
    AGENT_DIR="$HOME/agent"
elif [ -d "./agent" ]; then
    AGENT_DIR="./agent"
else
    echo "❌ 에이전트 디렉토리를 찾을 수 없습니다."
    echo "지원되는 경로: /opt/product-agent, ~/product-agent, ~/agent, ./agent"
    exit 1
fi

echo "✅ 에이전트 디렉토리 발견: $AGENT_DIR"

# 액션 디렉토리 확인
if [ ! -d "$AGENT_DIR/actions" ]; then
    echo "❌ actions 디렉토리가 없습니다: $AGENT_DIR/actions"
    exit 1
fi

# 1. 새 액션 파일 다운로드
echo ""
echo "[1/4] 새 액션 파일 다운로드..."
TEMP_FILE=$(mktemp)
curl -sSL -o "$TEMP_FILE" "https://raw.githubusercontent.com/[YOUR_REPO]/agent/actions/naver-shopping-search.js"

if [ -s "$TEMP_FILE" ]; then
    mv "$TEMP_FILE" "$AGENT_DIR/actions/naver-shopping-search.js"
    chmod 644 "$AGENT_DIR/actions/naver-shopping-search.js"
    echo "✅ naver-shopping-search.js 설치 완료"
else
    echo "❌ 액션 파일 다운로드 실패"
    rm -f "$TEMP_FILE"
    exit 1
fi

# 2. 설정 파일 업데이트
echo ""
echo "[2/4] 설정 파일 확인..."

# config.json 확인 및 업데이트
if [ -f "$AGENT_DIR/config.json" ]; then
    echo "📝 config.json 파일 발견"
    
    # 백업 생성
    cp "$AGENT_DIR/config.json" "$AGENT_DIR/config.json.backup.$(date +%Y%m%d%H%M%S)"
    
    # jq가 있으면 사용, 없으면 sed 사용
    if command -v jq &> /dev/null; then
        jq '.hubUrl = "http://mkt.techb.kr:8888"' "$AGENT_DIR/config.json" > "$AGENT_DIR/config.json.tmp" && \
        mv "$AGENT_DIR/config.json.tmp" "$AGENT_DIR/config.json"
        echo "✅ config.json의 hubUrl 업데이트 완료"
    else
        echo "⚠️  jq가 설치되어 있지 않습니다. 수동으로 hubUrl을 업데이트하세요:"
        echo "   hubUrl: \"http://mkt.techb.kr:8888\""
    fi
fi

# .env 파일 확인
if [ -f "$AGENT_DIR/.env" ]; then
    echo "📝 .env 파일 발견"
    
    # 백업 생성
    cp "$AGENT_DIR/.env" "$AGENT_DIR/.env.backup.$(date +%Y%m%d%H%M%S)"
    
    # HUB_URL 업데이트
    if grep -q "^HUB_URL=" "$AGENT_DIR/.env"; then
        sed -i 's|^HUB_URL=.*|HUB_URL=http://mkt.techb.kr:8888|' "$AGENT_DIR/.env"
    else
        echo "HUB_URL=http://mkt.techb.kr:8888" >> "$AGENT_DIR/.env"
    fi
    echo "✅ .env의 HUB_URL 업데이트 완료"
fi

# 3. 의존성 확인
echo ""
echo "[3/4] 의존성 확인..."
cd "$AGENT_DIR"

if [ -f "package.json" ]; then
    if command -v npm &> /dev/null; then
        echo "📦 npm 패키지 업데이트 중..."
        npm install --production
    else
        echo "⚠️  npm이 설치되어 있지 않아 패키지를 업데이트할 수 없습니다."
    fi
fi

# 4. PM2 프로세스 재시작
echo ""
echo "[4/4] 에이전트 재시작..."

if command -v pm2 &> /dev/null; then
    # PM2로 실행 중인 프로세스 찾기
    PM2_PROCESSES=$(pm2 list --json | jq -r '.[] | select(.pm2_env.cwd == "'$AGENT_DIR'") | .name' 2>/dev/null || echo "")
    
    if [ -n "$PM2_PROCESSES" ]; then
        for process in $PM2_PROCESSES; do
            echo "🔄 PM2 프로세스 재시작: $process"
            pm2 restart "$process"
        done
    else
        echo "⚠️  PM2로 실행 중인 에이전트를 찾을 수 없습니다."
        echo "   수동으로 재시작하세요: pm2 restart [프로세스명]"
    fi
else
    echo "⚠️  PM2가 설치되어 있지 않습니다."
    echo "   에이전트를 수동으로 재시작하세요."
fi

# 완료 메시지
echo ""
echo "=== 패치 완료 ==="
echo ""
echo "📌 중요 설정:"
echo "   HUB_URL: http://mkt.techb.kr:8888"
echo "   새 액션: naver-shopping-search"
echo ""
echo "🧪 테스트 방법:"
echo "   1. 에이전트 상태 확인:"
echo "      curl http://mkt.techb.kr:8888/agents"
echo ""
echo "   2. 파싱 테스트:"
echo "      curl -X POST http://mkt.techb.kr:8888/parse \\"
echo "        -H \"Content-Type: application/json\" \\"
echo "        -d '{\"keyword\": \"노트북\", \"mode\": \"fast\", \"agentCount\": 1}'"
echo ""
echo "❓ 문제가 있으면 백업 파일을 확인하세요:"
echo "   - config.json.backup.*"
echo "   - .env.backup.*"