# Windows PowerShell 스크립트 - 여러 에이전트 시작
param(
    [string]$PcId = "PC01",
    [int]$StartPort = 3001,
    [int]$Count = 5,
    [string]$HubUrl = "http://localhost:8080"
)

Write-Host "==========================================="
Write-Host "  Starting Multiple ProductParser Agents"
Write-Host "==========================================="
Write-Host "  PC ID: $PcId"
Write-Host "  Port Range: $StartPort - $($StartPort + $Count - 1)"
Write-Host "  Count: $Count agents"
Write-Host "  Hub URL: $HubUrl"
Write-Host "==========================================="

# 각 포트에 대해 에이전트 시작
for ($i = 0; $i -lt $Count; $i++) {
    $port = $StartPort + $i
    $agentId = "$PcId-$port"
    
    Write-Host "`nStarting agent $agentId..."
    
    # 새 PowerShell 창에서 에이전트 실행
    Start-Process powershell -ArgumentList @(
        "-NoExit",
        "-ExecutionPolicy", "Bypass",
        "-File", ".\start-agent.ps1",
        "-Port", $port,
        "-PcId", $PcId,
        "-HubUrl", $HubUrl
    ) -WorkingDirectory $PSScriptRoot
    
    # 다음 에이전트 시작 전 잠시 대기
    Start-Sleep -Seconds 2
}

Write-Host "`nAll agents started!"
Write-Host "Check individual PowerShell windows for agent status."