#!/bin/bash
# ProductParser Hub Server Ubuntu 설치 스크립트

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 기본 설정
INSTALL_PATH="/opt/productparser"
HUB_PORT=8888
POSTGRES_HOST="mkt.techb.kr"
POSTGRES_USER="techb_pp"
POSTGRES_PASSWORD="Tech1324!"
POSTGRES_DB="productparser_db"

echo -e "${CYAN}=== ProductParser Hub Server Ubuntu 설치 ===${NC}"
echo ""

# root 권한 확인
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}이 스크립트는 sudo 권한이 필요합니다.${NC}"
    echo "sudo $0 를 실행하세요."
    exit 1
fi

# Node.js 확인
echo -e "${YELLOW}Node.js 확인 중...${NC}"
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Node.js가 없습니다. 설치 중...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    apt-get install -y nodejs
fi
echo -e "${GREEN}✓ Node.js $(node --version)${NC}"

# Git 확인
echo -e "${YELLOW}Git 확인 중...${NC}"
if ! command -v git &> /dev/null; then
    apt-get update
    apt-get install -y git
fi
echo -e "${GREEN}✓ Git $(git --version)${NC}"

# PM2 설치
echo -e "${YELLOW}PM2 확인 중...${NC}"
if ! command -v pm2 &> /dev/null; then
    npm install -g pm2
fi
echo -e "${GREEN}✓ PM2 설치됨${NC}"

# 디렉토리 생성
echo -e "${YELLOW}설치 디렉토리 준비 중...${NC}"
if [ -d "$INSTALL_PATH" ]; then
    BACKUP_PATH="$INSTALL_PATH.backup.$(date +%Y%m%d-%H%M%S)"
    mv $INSTALL_PATH $BACKUP_PATH
    echo -e "${YELLOW}기존 디렉토리 백업: $BACKUP_PATH${NC}"
fi

mkdir -p $INSTALL_PATH
cd $INSTALL_PATH

# GitHub에서 코드 가져오기
echo -e "${YELLOW}GitHub에서 코드 다운로드 중...${NC}"
git clone -b dev https://github.com/service0427/ProductParser.git .

# ParserHub 디렉토리로 이동
cd $INSTALL_PATH/ParserHub

# NPM 패키지 설치
echo -e "${YELLOW}NPM 패키지 설치 중...${NC}"
npm install

# 환경 설정 파일 생성
echo -e "${YELLOW}환경 설정 파일 생성 중...${NC}"
cat > .env << EOF
# ParserHub 환경 설정
NODE_ENV=production
PORT=$HUB_PORT

# PostgreSQL 설정
DB_HOST=$POSTGRES_HOST
DB_USER=$POSTGRES_USER
DB_PASSWORD=$POSTGRES_PASSWORD
DB_NAME=$POSTGRES_DB
DB_PORT=5432

# 로그 설정
LOG_LEVEL=info
LOG_DIR=./logs

# 보안 설정
JWT_SECRET=$(uuidgen)
CORS_ORIGIN=*

# 성능 설정
MAX_CONCURRENT_PARSE=10
AGENT_TIMEOUT=60000
HEARTBEAT_INTERVAL=30000
EOF

echo -e "${GREEN}✓ .env 파일 생성 완료${NC}"

# 로그 디렉토리 생성
mkdir -p logs

# TypeScript 빌드
echo -e "${YELLOW}TypeScript 빌드 중...${NC}"
npm run build

# PM2 설정
echo -e "${YELLOW}PM2 서비스 설정 중...${NC}"
pm2 start ecosystem.config.js
pm2 save
pm2 startup systemd -u $SUDO_USER --hp /home/$SUDO_USER

# 시스템 서비스 생성
cat > /etc/systemd/system/productparser-hub.service << EOF
[Unit]
Description=ProductParser Hub Server
After=network.target

[Service]
Type=forking
User=$SUDO_USER
WorkingDirectory=$INSTALL_PATH/ParserHub
ExecStart=/usr/bin/pm2 start ecosystem.config.js
ExecReload=/usr/bin/pm2 reload all
ExecStop=/usr/bin/pm2 stop all
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable productparser-hub

# nginx 설정 (선택사항)
if command -v nginx &> /dev/null; then
    echo -e "${YELLOW}Nginx 리버스 프록시 설정 중...${NC}"
    cat > /etc/nginx/sites-available/productparser << EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:$HUB_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available/productparser /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    echo -e "${GREEN}✓ Nginx 설정 완료${NC}"
fi

# 방화벽 설정
if command -v ufw &> /dev/null; then
    echo -e "${YELLOW}방화벽 설정 중...${NC}"
    ufw allow $HUB_PORT/tcp
    ufw allow 80/tcp
    echo -e "${GREEN}✓ 방화벽 규칙 추가됨${NC}"
fi

# 업데이트 스크립트 생성
cat > $INSTALL_PATH/update-hub.sh << 'EOF'
#!/bin/bash
cd /opt/productparser
git pull origin dev
cd ParserHub
npm install
npm run build
pm2 reload all
echo "허브 서버 업데이트 완료!"
EOF

chmod +x $INSTALL_PATH/update-hub.sh

# 상태 확인 스크립트
cat > $INSTALL_PATH/hub-status.sh << 'EOF'
#!/bin/bash
echo "=== ProductParser Hub 상태 ==="
pm2 status
echo ""
echo "=== 최근 로그 ==="
pm2 logs --lines 20 --nostream
EOF

chmod +x $INSTALL_PATH/hub-status.sh

echo ""
echo -e "${GREEN}=== 설치 완료 ===${NC}"
echo ""
echo -e "허브 서버 경로: ${CYAN}$INSTALL_PATH/ParserHub${NC}"
echo -e "포트: ${CYAN}$HUB_PORT${NC}"
echo -e "대시보드: ${CYAN}http://$(hostname -I | awk '{print $1}'):$HUB_PORT${NC}"
echo ""
echo -e "${YELLOW}명령어:${NC}"
echo -e "  상태 확인: ${CYAN}$INSTALL_PATH/hub-status.sh${NC}"
echo -e "  업데이트: ${CYAN}$INSTALL_PATH/update-hub.sh${NC}"
echo -e "  로그 확인: ${CYAN}pm2 logs${NC}"
echo -e "  재시작: ${CYAN}pm2 restart all${NC}"
echo ""