# ProductParser Hub 서버 설치/업데이트 스크립트
# GitHub에서 최신 버전을 가져와 허브 서버 설정

param(
    [string]$InstallPath = "C:\ProductParser",
    [string]$PostgresHost = "mkt.techb.kr",
    [string]$PostgresUser = "techb_pp",
    [string]$PostgresPassword = "Tech1324!",
    [string]$PostgresDB = "productparser_db",
    [switch]$UpdateOnly
)

$ErrorActionPreference = "Stop"

Write-Host "=== ProductParser Hub 서버 설치/업데이트 ===" -ForegroundColor Cyan
Write-Host ""

# Git 확인
try {
    git --version | Out-Null
} catch {
    Write-Host "Git이 설치되지 않았습니다!" -ForegroundColor Red
    exit 1
}

# Node.js 확인
try {
    node --version | Out-Null
} catch {
    Write-Host "Node.js가 설치되지 않았습니다!" -ForegroundColor Red
    exit 1
}

# 설치/업데이트 분기
if ($UpdateOnly -and (Test-Path "$InstallPath\ParserHub")) {
    Write-Host "허브 서버 업데이트 모드" -ForegroundColor Yellow
    Set-Location "$InstallPath\ParserHub"
    
    Write-Host "Git pull 실행 중..." -ForegroundColor Yellow
    git pull origin dev
    
} else {
    Write-Host "허브 서버 새로 설치" -ForegroundColor Yellow
    
    # 디렉토리 생성
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }
    
    Set-Location $InstallPath
    
    # 기존 디렉토리가 있으면 백업
    if (Test-Path "ParserHub") {
        $backup = "ParserHub.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Move-Item ParserHub $backup
        Write-Host "기존 디렉토리 백업: $backup" -ForegroundColor Gray
    }
    
    # GitHub에서 클론
    Write-Host "GitHub에서 코드 다운로드 중..." -ForegroundColor Yellow
    git clone https://github.com/service0427/ProductParser.git temp
    Move-Item temp\ParserHub . -Force
    Remove-Item temp -Recurse -Force
    
    Set-Location ParserHub
}

# NPM 패키지 설치
Write-Host "`nNPM 패키지 설치 중..." -ForegroundColor Yellow
npm install

# TypeScript 빌드
Write-Host "`nTypeScript 빌드 중..." -ForegroundColor Yellow
npm run build

# 환경 설정 파일 생성
Write-Host "`n환경 설정 파일 생성 중..." -ForegroundColor Yellow

$envContent = @"
# ParserHub 환경 설정
NODE_ENV=production
PORT=8888

# PostgreSQL 설정
DB_HOST=$PostgresHost
DB_USER=$PostgresUser
DB_PASSWORD=$PostgresPassword
DB_NAME=$PostgresDB
DB_PORT=5432

# 로그 설정
LOG_LEVEL=info
LOG_DIR=./logs

# 보안 설정
JWT_SECRET=$(New-Guid).ToString()
CORS_ORIGIN=*

# 성능 설정
MAX_CONCURRENT_PARSE=10
AGENT_TIMEOUT=60000
HEARTBEAT_INTERVAL=30000
"@

$envContent | Out-File -FilePath ".env" -Encoding UTF8
Write-Host "✓ .env 파일 생성 완료" -ForegroundColor Green

# 데이터베이스 설정 파일 업데이트
Write-Host "`n데이터베이스 설정 업데이트 중..." -ForegroundColor Yellow

$dbConfigPath = "src\config\database.ts"
if (Test-Path $dbConfigPath) {
    $dbConfig = Get-Content $dbConfigPath -Raw
    $dbConfig = $dbConfig -replace 'host:.*', "host: '$PostgresHost',"
    $dbConfig = $dbConfig -replace 'user:.*', "user: '$PostgresUser',"
    $dbConfig = $dbConfig -replace 'password:.*', "password: '$PostgresPassword',"
    $dbConfig = $dbConfig -replace 'database:.*', "database: '$PostgresDB',"
    $dbConfig | Out-File -FilePath $dbConfigPath -Encoding UTF8
    
    # 다시 빌드
    npm run build
    Write-Host "✓ 데이터베이스 설정 완료" -ForegroundColor Green
}

# PM2 설치 확인
Write-Host "`nPM2 확인 중..." -ForegroundColor Yellow
try {
    pm2 --version | Out-Null
    Write-Host "✓ PM2 설치 확인" -ForegroundColor Green
} catch {
    Write-Host "PM2 설치 중..." -ForegroundColor Yellow
    npm install -g pm2
    Write-Host "✓ PM2 설치 완료" -ForegroundColor Green
}

# 시작 스크립트 생성
$startHubScript = @"
@echo off
cd /d $InstallPath\ParserHub
echo === ParserHub 서버 시작 중 ===
pm2 start ecosystem.config.js
pm2 logs
"@

$startHubScript | Out-File -FilePath "$InstallPath\start-hub.bat" -Encoding ASCII

# 중지 스크립트 생성
$stopHubScript = @"
@echo off
echo === ParserHub 서버 중지 중 ===
pm2 stop all
pm2 delete all
"@

$stopHubScript | Out-File -FilePath "$InstallPath\stop-hub.bat" -Encoding ASCII

# 상태 확인 스크립트
$statusScript = @"
@echo off
echo === ParserHub 상태 ===
pm2 status
echo.
echo === 최근 로그 ===
pm2 logs --lines 20 --nostream
"@

$statusScript | Out-File -FilePath "$InstallPath\hub-status.bat" -Encoding ASCII

Write-Host "`n=== 설치/업데이트 완료 ===" -ForegroundColor Green
Write-Host ""
Write-Host "허브 서버 경로: $InstallPath\ParserHub" -ForegroundColor Gray
Write-Host "데이터베이스: $PostgresDB@$PostgresHost" -ForegroundColor Gray
Write-Host ""
Write-Host "명령어:" -ForegroundColor Yellow
Write-Host "  시작: $InstallPath\start-hub.bat" -ForegroundColor Gray
Write-Host "  중지: $InstallPath\stop-hub.bat" -ForegroundColor Gray
Write-Host "  상태: $InstallPath\hub-status.bat" -ForegroundColor Gray
Write-Host ""
Write-Host "대시보드: http://localhost:8888" -ForegroundColor Cyan

# 실행 여부 확인
if (-not $UpdateOnly) {
    $response = Read-Host "`n허브 서버를 지금 시작하시겠습니까? (Y/N)"
    if ($response -eq 'Y' -or $response -eq 'y') {
        Start-Process "$InstallPath\start-hub.bat"
    }
}