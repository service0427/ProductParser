#!/bin/bash

# Playwright 최종 수정 패치
# 사용법: curl -sSL https://raw.githubusercontent.com/service0427/ProductParser/main/patch-playwright-final.sh | bash

set -e

echo "=== ProductParser Playwright 최종 패치 ==="
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

# 백업 생성
echo "📦 백업 생성 중..."
cp "$AGENT_DIR/core/profileManager.js" "$AGENT_DIR/core/profileManager.js.backup.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
cp "$AGENT_DIR/core/actionRunner.js" "$AGENT_DIR/core/actionRunner.js.backup.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

# 수정된 파일 다운로드
echo "📥 수정된 파일 다운로드 중..."

# profileManager.js
curl -sSL -o "$AGENT_DIR/core/profileManager.js" \
  "https://raw.githubusercontent.com/service0427/ProductParser/main/agent/core/profileManager.js"

# actionRunner.js  
curl -sSL -o "$AGENT_DIR/core/actionRunner.js" \
  "https://raw.githubusercontent.com/service0427/ProductParser/main/agent/core/actionRunner.js"

echo "✅ 파일 다운로드 완료"

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
echo "테스트 방법:"
echo "1. 로컬 테스트:"
echo "   curl -X POST http://localhost:4001/execute \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{\"action\": \"naver-shopping-search\", \"params\": {\"keyword\": \"노트북\"}}'"
echo ""
echo "2. 허브 통한 테스트:"
echo "   curl -X POST http://mkt.techb.kr:8888/parse \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{\"keyword\": \"노트북\", \"mode\": \"fast\", \"agentCount\": 1}'"