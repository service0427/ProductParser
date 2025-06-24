# Windows PowerShell 스크립트 - 에이전트 시작
param(
    [int]$Port = 3001,
    [string]$PcId = "PC01",
    [string]$HubUrl = "http://localhost:8080"
)

$AgentId = "$PcId-$Port"

Write-Host "==========================================="
Write-Host "  Starting ProductParser Agent"
Write-Host "==========================================="
Write-Host "  Agent ID: $AgentId"
Write-Host "  PC ID: $PcId"
Write-Host "  Port: $Port"
Write-Host "  Hub URL: $HubUrl"
Write-Host "==========================================="

# 환경 변수 설정
$env:NODE_ENV = "production"
$env:AGENT_PORT = $Port

# 에이전트 디렉토리로 이동
Set-Location -Path ".\agent"

# config.json 업데이트
$config = @{
    agentId = $AgentId
    pcId = $PcId
    port = $Port
    hubUrl = $HubUrl
    heartbeatInterval = 30000
} | ConvertTo-Json

$config | Out-File -FilePath ".\config.json" -Encoding UTF8

# 프로필 디렉토리 확인
$profilePath = "C:\AgentProfiles\port-$Port"
if (!(Test-Path $profilePath)) {
    Write-Host "Chrome profile not found. Creating profile for port $Port..."
    
    # 프로필 생성 스크립트 실행
    node -e "
    const profileManager = require('./core/profileManager');
    profileManager.createProfile($Port).then(() => {
        console.log('Profile created successfully');
        process.exit(0);
    }).catch(err => {
        console.error('Failed to create profile:', err);
        process.exit(1);
    });
    "
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create Chrome profile. Exiting..." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Starting agent server..."

# 에이전트 시작
node agent.js