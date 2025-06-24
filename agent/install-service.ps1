# ProductParser Agent Windows 서비스 설치 스크립트
# 관리자 권한으로 실행 필요

# NSSM 경로 설정 (다운로드 필요: https://nssm.cc/)
$nssmPath = "C:\tools\nssm\nssm.exe"

# 기본 설정
$basePath = "C:\ProductParser\agent"
$nodePath = "C:\Program Files\nodejs\node.exe"
$hubUrl = "http://허브서버주소:3000"  # 실제 허브 서버 주소로 변경 필요
$pcId = "PC-61.84.75.16"

# NSSM 존재 확인
if (-not (Test-Path $nssmPath)) {
    Write-Host "NSSM이 설치되지 않았습니다." -ForegroundColor Red
    Write-Host "다음 경로에서 다운로드하세요: https://nssm.cc/" -ForegroundColor Yellow
    Write-Host "다운로드 후 $nssmPath 경로에 압축을 해제하세요." -ForegroundColor Yellow
    exit
}

# Node.js 확인
if (-not (Test-Path $nodePath)) {
    Write-Host "Node.js가 설치되지 않았습니다." -ForegroundColor Red
    Write-Host "https://nodejs.org/en/ 에서 설치하세요." -ForegroundColor Yellow
    exit
}

# 에이전트 경로 확인
if (-not (Test-Path $basePath)) {
    Write-Host "에이전트 경로가 존재하지 않습니다: $basePath" -ForegroundColor Red
    exit
}

# 5개 포트에 대한 서비스 설치
$ports = 4001..4005

foreach ($port in $ports) {
    $serviceName = "ProductParserAgent$port"
    $agentId = "$pcId-$port"
    
    Write-Host "`n=== $serviceName 서비스 설치 중 ===" -ForegroundColor Cyan
    
    # 기존 서비스 제거
    & $nssmPath stop $serviceName 2>$null
    & $nssmPath remove $serviceName confirm 2>$null
    
    # 서비스 설치
    & $nssmPath install $serviceName $nodePath "$basePath\agent.js"
    
    # 서비스 설정
    & $nssmPath set $serviceName AppDirectory $basePath
    & $nssmPath set $serviceName AppEnvironmentExtra "PORT=$port" "AGENT_ID=$agentId" "PC_ID=$pcId" "HUB_URL=$hubUrl" "PLATFORM=windows"
    & $nssmPath set $serviceName DisplayName "ProductParser Agent (Port $port)"
    & $nssmPath set $serviceName Description "ProductParser distributed scraping agent on port $port"
    & $nssmPath set $serviceName Start SERVICE_AUTO_START
    & $nssmPath set $serviceName AppStdout "$basePath\logs\service-$port.log"
    & $nssmPath set $serviceName AppStderr "$basePath\logs\service-$port-error.log"
    & $nssmPath set $serviceName AppRotateFiles 1
    & $nssmPath set $serviceName AppRotateBytes 10485760  # 10MB
    
    # 서비스 시작
    & $nssmPath start $serviceName
    
    # 상태 확인
    $status = & $nssmPath status $serviceName
    Write-Host "서비스 상태: $status" -ForegroundColor Green
}

Write-Host "`n=== 모든 서비스 설치 완료 ===" -ForegroundColor Green
Write-Host "`n서비스 관리 명령어:" -ForegroundColor Yellow
Write-Host "  상태 확인: nssm status ProductParserAgent4001" -ForegroundColor Gray
Write-Host "  시작: nssm start ProductParserAgent4001" -ForegroundColor Gray
Write-Host "  중지: nssm stop ProductParserAgent4001" -ForegroundColor Gray
Write-Host "  제거: nssm remove ProductParserAgent4001 confirm" -ForegroundColor Gray

# 서비스 상태 확인
Write-Host "`n=== 설치된 서비스 상태 ===" -ForegroundColor Cyan
foreach ($port in $ports) {
    $serviceName = "ProductParserAgent$port"
    $status = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($status) {
        Write-Host "$serviceName : $($status.Status)" -ForegroundColor $(if($status.Status -eq 'Running'){'Green'}else{'Red'})
    } else {
        Write-Host "$serviceName : Not Found" -ForegroundColor Red
    }
}