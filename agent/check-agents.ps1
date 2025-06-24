# ProductParser Agent 상태 확인 스크립트

Write-Host "=== ProductParser Agent 상태 확인 ===" -ForegroundColor Cyan
Write-Host "시간: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""

# 확인할 포트 범위
$ports = 4001..4005
$pcId = "PC-61.84.75.16"

# 전체 상태 저장
$totalAgents = $ports.Count
$runningAgents = 0

# 각 포트 확인
foreach ($port in $ports) {
    $agentId = "$pcId-$port"
    Write-Host -NoNewline "Port $port ($agentId): "
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:$port/health" -Method GET -TimeoutSec 2
        
        if ($response.status -eq "ok") {
            Write-Host "RUNNING" -ForegroundColor Green
            Write-Host "  - 버전: $($response.version)" -ForegroundColor Gray
            Write-Host "  - 플랫폼: $($response.platform)" -ForegroundColor Gray
            Write-Host "  - 시작 시간: $($response.startTime)" -ForegroundColor Gray
            
            # 액션 정보가 있으면 표시
            if ($response.actions -and $response.actions.Count -gt 0) {
                Write-Host "  - 사용 가능한 액션: $($response.actions -join ', ')" -ForegroundColor Gray
            }
            
            $runningAgents++
        } else {
            Write-Host "UNKNOWN STATUS" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "OFFLINE" -ForegroundColor Red
        Write-Host "  - 오류: $($_.Exception.Message)" -ForegroundColor DarkRed
    }
    
    Write-Host ""
}

# 요약
Write-Host "=== 요약 ===" -ForegroundColor Cyan
Write-Host "전체 에이전트: $totalAgents" -ForegroundColor Gray
Write-Host -NoNewline "실행 중: $runningAgents" 
if ($runningAgents -eq $totalAgents) {
    Write-Host " (100%)" -ForegroundColor Green
} elseif ($runningAgents -gt 0) {
    $percentage = [math]::Round(($runningAgents / $totalAgents) * 100)
    Write-Host " ($percentage%)" -ForegroundColor Yellow
} else {
    Write-Host " (0%)" -ForegroundColor Red
}
Write-Host "중지됨: $($totalAgents - $runningAgents)" -ForegroundColor Gray

# Windows 서비스 상태 확인 (NSSM 사용 시)
Write-Host "`n=== Windows 서비스 상태 ===" -ForegroundColor Cyan
$servicesFound = $false
foreach ($port in $ports) {
    $serviceName = "ProductParserAgent$port"
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    
    if ($service) {
        $servicesFound = $true
        Write-Host -NoNewline "$serviceName : "
        
        switch ($service.Status) {
            'Running' { Write-Host $service.Status -ForegroundColor Green }
            'Stopped' { Write-Host $service.Status -ForegroundColor Red }
            default { Write-Host $service.Status -ForegroundColor Yellow }
        }
    }
}

if (-not $servicesFound) {
    Write-Host "Windows 서비스가 설치되지 않았습니다." -ForegroundColor Gray
    Write-Host "서비스 설치는 install-service.ps1 스크립트를 실행하세요." -ForegroundColor Gray
}

# 프로세스 정보
Write-Host "`n=== Node.js 프로세스 ===" -ForegroundColor Cyan
$nodeProcesses = Get-Process -Name node -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*agent.js*" }

if ($nodeProcesses) {
    Write-Host "실행 중인 Node.js 프로세스: $($nodeProcesses.Count)개" -ForegroundColor Green
    foreach ($process in $nodeProcesses) {
        Write-Host "  - PID: $($process.Id), 메모리: $([math]::Round($process.WorkingSet64 / 1MB, 2)) MB" -ForegroundColor Gray
    }
} else {
    Write-Host "실행 중인 에이전트 프로세스가 없습니다." -ForegroundColor Red
}

# 네트워크 포트 상태
Write-Host "`n=== 네트워크 포트 상태 ===" -ForegroundColor Cyan
foreach ($port in $ports) {
    $connection = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($connection) {
        Write-Host "Port $port : LISTENING" -ForegroundColor Green
    } else {
        Write-Host "Port $port : NOT LISTENING" -ForegroundColor Red
    }
}