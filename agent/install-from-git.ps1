# ProductParser Agent Git 자동 설치 스크립트
# Windows PowerShell에서 관리자 권한으로 실행

param(
    [string]$InstallPath = "C:\ProductParser",
    [string]$HubUrl = "http://localhost:8888",
    [string]$PCName = $env:COMPUTERNAME,
    [string]$PCIP = "112.161.209.80"
)

$ErrorActionPreference = "Stop"

Write-Host "=== ProductParser Agent 자동 설치 시작 ===" -ForegroundColor Cyan
Write-Host "설치 경로: $InstallPath" -ForegroundColor Gray
Write-Host "PC 정보: $PCName ($PCIP)" -ForegroundColor Gray
Write-Host ""

# 1. Git 확인
Write-Host "Git 확인 중..." -ForegroundColor Yellow
try {
    $gitVersion = git --version
    Write-Host "✓ Git 설치 확인: $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Git이 설치되지 않았습니다!" -ForegroundColor Red
    exit 1
}

# 2. Node.js 확인
Write-Host "`nNode.js 확인 중..." -ForegroundColor Yellow
try {
    $nodeVersion = node --version
    Write-Host "✓ Node.js 설치 확인: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Node.js가 설치되지 않았습니다!" -ForegroundColor Red
    Write-Host "https://nodejs.org 에서 LTS 버전을 설치하세요." -ForegroundColor Yellow
    exit 1
}

# 3. Chrome 확인
Write-Host "`nChrome 확인 중..." -ForegroundColor Yellow
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (Test-Path $chromePath) {
    Write-Host "✓ Chrome 설치 확인" -ForegroundColor Green
} else {
    Write-Host "✗ Chrome이 기본 경로에 없습니다!" -ForegroundColor Red
    Write-Host "경로: $chromePath" -ForegroundColor Yellow
}

# 4. 설치 디렉토리 생성
Write-Host "`n설치 디렉토리 준비 중..." -ForegroundColor Yellow
if (Test-Path $InstallPath) {
    Write-Host "기존 디렉토리 발견. 백업 중..." -ForegroundColor Yellow
    $backupPath = "$InstallPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Move-Item $InstallPath $backupPath -Force
    Write-Host "백업 완료: $backupPath" -ForegroundColor Gray
}

New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
Set-Location $InstallPath

# 5. GitHub에서 코드 가져오기
Write-Host "`nGitHub에서 코드 다운로드 중..." -ForegroundColor Yellow
try {
    git clone -b dev https://github.com/service0427/ProductParser.git .
    Write-Host "✓ 코드 다운로드 완료" -ForegroundColor Green
} catch {
    Write-Host "✗ Git clone 실패: $_" -ForegroundColor Red
    exit 1
}

# 6. 에이전트 디렉토리로 이동
Set-Location "$InstallPath\agent"

# 7. npm 패키지 설치
Write-Host "`nNPM 패키지 설치 중..." -ForegroundColor Yellow
npm install
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ NPM 패키지 설치 완료" -ForegroundColor Green
} else {
    Write-Host "✗ NPM 설치 실패" -ForegroundColor Red
    exit 1
}

# 8. 환경 설정 파일 생성
Write-Host "`n환경 설정 파일 생성 중..." -ForegroundColor Yellow

# 기본 .env 파일 생성 함수
function Create-EnvFile {
    param($Port)
    
    $envContent = @"
# Windows 환경 설정
PORT=$Port
AGENT_ID=PC-$PCIP-$Port
PC_ID=PC-$PCIP
HUB_URL=$HubUrl
PLATFORM=windows
CHROME_EXECUTABLE_PATH=$chromePath
USER_DATA_DIR=$InstallPath\chrome-profiles
LOG_LEVEL=info
LOG_DIR=$InstallPath\agent\logs
HEARTBEAT_INTERVAL=30
TASK_TIMEOUT=60000
SCREENSHOT_DIR=$InstallPath\agent\screenshots
DEBUG=false
"@
    
    return $envContent
}

# .env 파일 생성 (기본 포트 4001)
Create-EnvFile -Port 4001 | Out-File -FilePath ".env" -Encoding UTF8
Write-Host "✓ .env 파일 생성 완료" -ForegroundColor Green

# 9. 필요한 디렉토리 생성
Write-Host "`n필요한 디렉토리 생성 중..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "logs" -Force | Out-Null
New-Item -ItemType Directory -Path "screenshots" -Force | Out-Null
New-Item -ItemType Directory -Path "$InstallPath\chrome-profiles" -Force | Out-Null
Write-Host "✓ 디렉토리 생성 완료" -ForegroundColor Green

# 10. 자동 시작 배치 파일 생성
Write-Host "`n자동 시작 스크립트 생성 중..." -ForegroundColor Yellow

$startScript = @"
@echo off
cd /d $InstallPath\agent

echo === ProductParser Agent 시작 중 ===
echo.

REM 5개 포트에서 에이전트 실행
start "Agent-4001" cmd /k "set PORT=4001 && set AGENT_ID=PC-$PCIP-4001 && npm start"
timeout /t 2 /nobreak >nul

start "Agent-4002" cmd /k "set PORT=4002 && set AGENT_ID=PC-$PCIP-4002 && npm start"
timeout /t 2 /nobreak >nul

start "Agent-4003" cmd /k "set PORT=4003 && set AGENT_ID=PC-$PCIP-4003 && npm start"
timeout /t 2 /nobreak >nul

start "Agent-4004" cmd /k "set PORT=4004 && set AGENT_ID=PC-$PCIP-4004 && npm start"
timeout /t 2 /nobreak >nul

start "Agent-4005" cmd /k "set PORT=4005 && set AGENT_ID=PC-$PCIP-4005 && npm start"

echo.
echo === 모든 에이전트가 시작되었습니다 ===
echo.
pause
"@

$startScript | Out-File -FilePath "$InstallPath\start-agents.bat" -Encoding ASCII
Write-Host "✓ start-agents.bat 생성 완료" -ForegroundColor Green

# 11. 업데이트 스크립트 생성
Write-Host "`n업데이트 스크립트 생성 중..." -ForegroundColor Yellow

$updateScript = @"
# ProductParser 업데이트 스크립트
param([switch]`$Hub)

Write-Host "=== ProductParser 업데이트 ===" -ForegroundColor Cyan

# 에이전트 업데이트
Set-Location "$InstallPath"
Write-Host "`n에이전트 업데이트 중..." -ForegroundColor Yellow
git pull origin dev

Set-Location "$InstallPath\agent"
npm install

Write-Host "✓ 에이전트 업데이트 완료" -ForegroundColor Green

# 허브 업데이트 (선택사항)
if (`$Hub) {
    if (Test-Path "$InstallPath\ParserHub") {
        Write-Host "`n허브 서버 업데이트 중..." -ForegroundColor Yellow
        Set-Location "$InstallPath\ParserHub"
        npm install
        npm run build
        Write-Host "✓ 허브 업데이트 완료" -ForegroundColor Green
    }
}

Write-Host "`n업데이트 완료!" -ForegroundColor Green
Write-Host "에이전트를 재시작하세요." -ForegroundColor Yellow
"@

$updateScript | Out-File -FilePath "$InstallPath\update.ps1" -Encoding UTF8
Write-Host "✓ update.ps1 생성 완료" -ForegroundColor Green

# 12. 방화벽 규칙 추가
Write-Host "`n방화벽 규칙 추가 중..." -ForegroundColor Yellow
$ports = 4001..4005
foreach ($port in $ports) {
    try {
        New-NetFirewallRule -DisplayName "ProductParser Agent $port" `
            -Direction Inbound -Protocol TCP -LocalPort $port `
            -Action Allow -ErrorAction SilentlyContinue | Out-Null
        Write-Host "✓ 포트 $port 방화벽 규칙 추가" -ForegroundColor Green
    } catch {
        Write-Host "- 포트 $port 방화벽 규칙 이미 존재" -ForegroundColor Gray
    }
}

# 13. 설치 완료
Write-Host "`n=== 설치 완료 ===" -ForegroundColor Green
Write-Host ""
Write-Host "설치 경로: $InstallPath" -ForegroundColor Gray
Write-Host "에이전트 ID: PC-$PCIP-[4001-4005]" -ForegroundColor Gray
Write-Host "허브 URL: $HubUrl" -ForegroundColor Gray
Write-Host ""
Write-Host "실행 방법:" -ForegroundColor Yellow
Write-Host "  1. 전체 실행: $InstallPath\start-agents.bat" -ForegroundColor Gray
Write-Host "  2. 개별 실행: cd $InstallPath\agent && npm start" -ForegroundColor Gray
Write-Host ""
Write-Host "업데이트:" -ForegroundColor Yellow
Write-Host "  PowerShell: $InstallPath\update.ps1" -ForegroundColor Gray
Write-Host ""

# 실행 여부 확인
$response = Read-Host "지금 에이전트를 시작하시겠습니까? (Y/N)"
if ($response -eq 'Y' -or $response -eq 'y') {
    Start-Process "$InstallPath\start-agents.bat"
}