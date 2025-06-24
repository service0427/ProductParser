#!/bin/bash
# WSL/Linux 개발 환경 설정 스크립트

echo "==========================================="
echo "  ProductParser WSL Development Setup"
echo "==========================================="

# 프로젝트 루트 디렉토리 확인
if [ ! -f "agent/package.json" ]; then
    echo "Error: Run this script from the ProductParser root directory"
    exit 1
fi

# Node.js 버전 확인
NODE_VERSION=$(node -v 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "Error: Node.js is not installed"
    echo "Please install Node.js 18+ first"
    exit 1
fi

echo "Node.js version: $NODE_VERSION"

# Google Chrome 설치 확인
if ! command -v google-chrome &> /dev/null; then
    echo "Google Chrome not found. Installing..."
    
    # Chrome 저장소 추가
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
    sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
    
    # Chrome 설치
    sudo apt-get update
    sudo apt-get install -y google-chrome-stable
fi

echo "Google Chrome version:"
google-chrome --version

# 필요한 시스템 패키지 설치
echo ""
echo "Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2

# 에이전트 의존성 설치
echo ""
echo "Installing agent dependencies..."
cd agent
npm install

# 개발 환경 설정 파일 생성
if [ ! -f ".env" ]; then
    echo "Creating .env file for Linux development..."
    cp .env.linux .env
fi

# 로그 디렉토리 생성
mkdir -p logs

# 프로필 디렉토리 생성
mkdir -p profiles

# 테스트 실행
echo ""
echo "Running mock test..."
npm test

echo ""
echo "==========================================="
echo "  Setup Complete!"
echo "==========================================="
echo ""
echo "To start development:"
echo "  1. cd agent"
echo "  2. npm run dev"
echo ""
echo "To run tests:"
echo "  npm test"
echo ""