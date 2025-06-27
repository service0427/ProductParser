#!/bin/bash

# 여러 에이전트를 한 번에 배포하는 스크립트
# 사용법: ./deploy-multiple-agents.sh

# 에이전트 서버 목록 (IP 또는 호스트명)
AGENT_HOSTS=(
    "112.161.209.80"
    # "192.168.1.101"
    # "192.168.1.102"
    # "agent-server-03.example.com"
    # 더 많은 서버 추가 가능
)

# SSH 사용자 (모든 서버에 동일하다고 가정, 다르면 수정 필요)
SSH_USER="user"

# 허브 URL
HUB_URL="http://mkt.techb.kr:8888"

# 시작 포트 (각 서버마다 증가)
START_PORT=4001

echo "=== 여러 에이전트 자동 배포 ==="
echo "허브: $HUB_URL"
echo "대상 서버: ${#AGENT_HOSTS[@]}개"
echo ""

# 각 서버에 배포
for i in "${!AGENT_HOSTS[@]}"; do
    HOST="${AGENT_HOSTS[$i]}"
    PORT=$((START_PORT + i))
    AGENT_ID="agent-$(echo $HOST | sed 's/\./-/g')-$PORT"
    
    echo "[$((i+1))/${#AGENT_HOSTS[@]}] $HOST 배포 중..."
    echo "  에이전트 ID: $AGENT_ID"
    echo "  포트: $PORT"
    
    # SSH로 원격 실행
    ssh "$SSH_USER@$HOST" "bash -s" << EOF
        export AGENT_PORT=$PORT
        export AGENT_ID=$AGENT_ID
        export HUB_URL=$HUB_URL
        export AUTO_START=true
        curl -sSL https://raw.githubusercontent.com/service0427/ProductParser/main/install-agent-complete.sh | bash
EOF
    
    if [ $? -eq 0 ]; then
        echo "  ✓ 성공"
    else
        echo "  ✗ 실패"
    fi
    echo ""
done

echo "=== 배포 완료 ==="
echo ""
echo "에이전트 상태 확인:"
echo "curl $HUB_URL/agents"