# Windows 11 에이전트 설치 가이드

## 사전 요구사항

1. **Node.js 설치**
   - https://nodejs.org/en/ 에서 LTS 버전 다운로드
   - 설치 시 "Automatically install the necessary tools" 체크

2. **Google Chrome 설치**
   - https://www.google.com/chrome/ 에서 다운로드
   - 기본 경로에 설치 권장

## 설치 단계

### 1. 에이전트 코드 복사

```powershell
# C:\ 드라이브에 폴더 생성
mkdir C:\ProductParser
mkdir C:\ProductParser\agent
cd C:\ProductParser\agent
```

### 2. 파일 복사
WSL에서 Windows로 파일 복사:
```bash
# WSL에서 실행
cp -r /home/tech/projects/ProductParser/20250624/ProductParser/agent/* /mnt/c/ProductParser/agent/
```

또는 Windows에서 직접 다운로드:
- GitHub에서 clone 또는 ZIP 다운로드

### 3. 의존성 설치

```powershell
# Windows PowerShell에서 실행
cd C:\ProductParser\agent
npm install
```

### 4. 환경 설정

`.env.windows` 파일 생성:
```env
PORT=4001
AGENT_ID=PC-61.84.75.16-4001
PC_ID=PC-61.84.75.16
HUB_URL=http://허브서버주소:3000
PLATFORM=windows
CHROME_EXECUTABLE_PATH=C:\Program Files\Google\Chrome\Application\chrome.exe
USER_DATA_DIR=C:\ProductParser\chrome-profiles
```

### 5. 첫 실행 테스트

```powershell
# 단일 에이전트 실행
npm start
```

### 6. 여러 포트에서 실행

다른 PowerShell 창에서:
```powershell
# 포트 4002
$env:PORT=4002
$env:AGENT_ID="PC-61.84.75.16-4002"
npm start

# 포트 4003
$env:PORT=4003
$env:AGENT_ID="PC-61.84.75.16-4003"
npm start
```

## 자동 시작 설정

### 방법 1: Windows 서비스 (권장)

`install-service.ps1` 스크립트 생성:
```powershell
# NSSM 다운로드 (https://nssm.cc/)
# 각 포트별로 서비스 생성
nssm install ProductParserAgent4001 "C:\Program Files\nodejs\node.exe" "C:\ProductParser\agent\agent.js"
nssm set ProductParserAgent4001 AppDirectory "C:\ProductParser\agent"
nssm set ProductParserAgent4001 AppEnvironmentExtra "PORT=4001" "AGENT_ID=PC-61.84.75.16-4001"
nssm start ProductParserAgent4001
```

### 방법 2: 작업 스케줄러

1. 작업 스케줄러 열기 (taskschd.msc)
2. 기본 작업 만들기
3. 트리거: 시스템 시작 시
4. 동작: 프로그램 시작
5. 프로그램: `C:\Program Files\nodejs\node.exe`
6. 인수: `C:\ProductParser\agent\agent.js`
7. 시작 위치: `C:\ProductParser\agent`

### 방법 3: 배치 파일

`start-agents.bat` 생성:
```batch
@echo off
cd /d C:\ProductParser\agent

start "Agent-4001" cmd /k "set PORT=4001 && set AGENT_ID=PC-61.84.75.16-4001 && npm start"
start "Agent-4002" cmd /k "set PORT=4002 && set AGENT_ID=PC-61.84.75.16-4002 && npm start"
start "Agent-4003" cmd /k "set PORT=4003 && set AGENT_ID=PC-61.84.75.16-4003 && npm start"
start "Agent-4004" cmd /k "set PORT=4004 && set AGENT_ID=PC-61.84.75.16-4004 && npm start"
start "Agent-4005" cmd /k "set PORT=4005 && set AGENT_ID=PC-61.84.75.16-4005 && npm start"
```

## 방화벽 설정

Windows Defender 방화벽에서 포트 허용:
```powershell
# 관리자 권한으로 실행
New-NetFirewallRule -DisplayName "ProductParser Agent 4001" -Direction Inbound -Protocol TCP -LocalPort 4001 -Action Allow
New-NetFirewallRule -DisplayName "ProductParser Agent 4002" -Direction Inbound -Protocol TCP -LocalPort 4002 -Action Allow
New-NetFirewallRule -DisplayName "ProductParser Agent 4003" -Direction Inbound -Protocol TCP -LocalPort 4003 -Action Allow
New-NetFirewallRule -DisplayName "ProductParser Agent 4004" -Direction Inbound -Protocol TCP -LocalPort 4004 -Action Allow
New-NetFirewallRule -DisplayName "ProductParser Agent 4005" -Direction Inbound -Protocol TCP -LocalPort 4005 -Action Allow
```

## 문제 해결

### Chrome 실행 안됨
- Chrome 설치 경로 확인
- 환경 변수의 CHROME_EXECUTABLE_PATH 수정

### 포트 충돌
```powershell
# 포트 사용 확인
netstat -ano | findstr :4001
```

### 로그 확인
- 로그 파일: `C:\ProductParser\agent\logs\agent-4001.log`

## 모니터링

### PowerShell 스크립트로 상태 확인
```powershell
# check-agents.ps1
$ports = 4001..4005
foreach ($port in $ports) {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:$port/health" -Method GET
        Write-Host "Port $port : OK - $($response.status)" -ForegroundColor Green
    } catch {
        Write-Host "Port $port : FAILED" -ForegroundColor Red
    }
}
```