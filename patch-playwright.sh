#!/bin/bash

# Playwright 실행 문제 수정 패치
# 사용법: curl -sSL https://raw.githubusercontent.com/service0427/ProductParser/main/patch-playwright.sh | bash

set -e

echo "=== ProductParser Playwright 패치 ==="
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

# profileManager.js 백업
if [ -f "$AGENT_DIR/core/profileManager.js" ]; then
    cp "$AGENT_DIR/core/profileManager.js" "$AGENT_DIR/core/profileManager.js.backup.$(date +%Y%m%d%H%M%S)"
    echo "✅ 백업 생성 완료"
fi

# actionRunner.js 백업
if [ -f "$AGENT_DIR/core/actionRunner.js" ]; then
    cp "$AGENT_DIR/core/actionRunner.js" "$AGENT_DIR/core/actionRunner.js.backup.$(date +%Y%m%d%H%M%S)"
fi

# profileManager.js 수정 - user-data-dir 제거
echo "📝 profileManager.js 수정 중..."
sed -i.tmp 's/--user-data-dir=${profilePath}//' "$AGENT_DIR/core/profileManager.js" 2>/dev/null || \
sed -i '' 's/--user-data-dir=${profilePath}//' "$AGENT_DIR/core/profileManager.js" 2>/dev/null || \
sed -i 's/--user-data-dir=${profilePath}//' "$AGENT_DIR/core/profileManager.js"

# launchPersistentContext로 변경
sed -i.tmp 's/chromium\.launch/chromium.launchPersistentContext/' "$AGENT_DIR/core/profileManager.js" 2>/dev/null || \
sed -i '' 's/chromium\.launch/chromium.launchPersistentContext/' "$AGENT_DIR/core/profileManager.js" 2>/dev/null || \
sed -i 's/chromium\.launch/chromium.launchPersistentContext/' "$AGENT_DIR/core/profileManager.js"

# browser 변수를 context로 변경
sed -i.tmp 's/const browser = /const context = /' "$AGENT_DIR/core/profileManager.js" 2>/dev/null || \
sed -i '' 's/const browser = /const context = /' "$AGENT_DIR/core/profileManager.js" 2>/dev/null || \
sed -i 's/const browser = /const context = /' "$AGENT_DIR/core/profileManager.js"

sed -i.tmp 's/browser\.newPage/context.newPage/' "$AGENT_DIR/core/profileManager.js" 2>/dev/null || \
sed -i '' 's/browser\.newPage/context.newPage/' "$AGENT_DIR/core/profileManager.js" 2>/dev/null || \
sed -i 's/browser\.newPage/context.newPage/' "$AGENT_DIR/core/profileManager.js"

sed -i.tmp 's/browser\.close/context.close/' "$AGENT_DIR/core/profileManager.js" 2>/dev/null || \
sed -i '' 's/browser\.close/context.close/' "$AGENT_DIR/core/profileManager.js" 2>/dev/null || \
sed -i 's/browser\.close/context.close/' "$AGENT_DIR/core/profileManager.js"

# launchPersistentContext 호출 수정
sed -i.tmp 's/await chromium\.launchPersistentContext(launchOptions)/await chromium.launchPersistentContext(profilePath, launchOptions)/' "$AGENT_DIR/core/profileManager.js" 2>/dev/null || \
sed -i '' 's/await chromium\.launchPersistentContext(launchOptions)/await chromium.launchPersistentContext(profilePath, launchOptions)/' "$AGENT_DIR/core/profileManager.js" 2>/dev/null || \
sed -i 's/await chromium\.launchPersistentContext(launchOptions)/await chromium.launchPersistentContext(profilePath, launchOptions)/' "$AGENT_DIR/core/profileManager.js"

# actionRunner.js도 수정
echo "📝 actionRunner.js 수정 중..."
sed -i.tmp 's/this\.browser = /this.context = /' "$AGENT_DIR/core/actionRunner.js" 2>/dev/null || \
sed -i '' 's/this\.browser = /this.context = /' "$AGENT_DIR/core/actionRunner.js" 2>/dev/null || \
sed -i 's/this\.browser = /this.context = /' "$AGENT_DIR/core/actionRunner.js"

sed -i.tmp 's/this\.browser\./this.context./' "$AGENT_DIR/core/actionRunner.js" 2>/dev/null || \
sed -i '' 's/this\.browser\./this.context./' "$AGENT_DIR/core/actionRunner.js" 2>/dev/null || \
sed -i 's/this\.browser\./this.context./' "$AGENT_DIR/core/actionRunner.js"

sed -i.tmp 's/browser\.newPage/context.newPage/' "$AGENT_DIR/core/actionRunner.js" 2>/dev/null || \
sed -i '' 's/browser\.newPage/context.newPage/' "$AGENT_DIR/core/actionRunner.js" 2>/dev/null || \
sed -i 's/browser\.newPage/context.newPage/' "$AGENT_DIR/core/actionRunner.js"

# 임시 파일 삭제
rm -f "$AGENT_DIR/core/"*.tmp

echo "✅ 패치 완료"

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
echo "  curl -X POST http://localhost:4001/execute \\"
echo "    -H \"Content-Type: application/json\" \\"
echo "    -d '{\"action\": \"naver-shopping-search\", \"params\": {\"keyword\": \"노트북\"}}'"