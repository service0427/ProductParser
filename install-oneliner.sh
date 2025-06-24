#!/bin/bash
# ProductParser 원라이너 설치 스크립트
# curl -sSL https://raw.githubusercontent.com/service0427/ProductParser/dev/install-oneliner.sh | bash

echo "ProductParser Agent 설치를 시작합니다..."

# 임시 디렉토리 생성
TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR

# 설치 스크립트 다운로드
curl -sSL https://raw.githubusercontent.com/service0427/ProductParser/dev/install-agent.sh -o install-agent.sh

# 실행 권한 부여
chmod +x install-agent.sh

# 설치 스크립트 실행
./install-agent.sh

# 임시 디렉토리 삭제
cd ..
rm -rf $TEMP_DIR