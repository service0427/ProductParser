# ProductParser Windows 설치 가이드

## 빠른 설치 (Git 사용)

### 1. 에이전트 설치

PowerShell을 **관리자 권한**으로 실행 후:

```powershell
# 기본 설치 (C:\ProductParser)
irm https://raw.githubusercontent.com/service0427/ProductParser/dev/agent/install-from-git.ps1 | iex

# 또는 다운로드 후 실행
curl -o install.ps1 https://raw.githubusercontent.com/service0427/ProductParser/dev/agent/install-from-git.ps1
.\install.ps1 -HubUrl "http://허브서버:8888" -PCIP "112.161.209.80"
```

### 2. 허브 서버 설치 (선택사항)

```powershell
# 허브 서버 설치
.\hub-update.ps1 -PostgresHost "mkt.techb.kr" -PostgresUser "techb_pp" -PostgresPassword "Tech1324!"

# 업데이트만
.\hub-update.ps1 -UpdateOnly
```

### 3. 자동 시작 설정

```powershell
# Windows 부팅 시 자동 시작
.\setup-windows-startup.ps1

# 자동 시작 제거
.\setup-windows-startup.ps1 -Remove
```

## 수동 설치

### 필수 소프트웨어
- Git (설치됨)
- Chrome (설치됨)
- Node.js ([다운로드](https://nodejs.org))

### 설치 단계

1. **코드 다운로드**
   ```powershell
   git clone -b dev https://github.com/service0427/ProductParser.git C:\ProductParser
   cd C:\ProductParser\agent
   ```

2. **패키지 설치**
   ```powershell
   npm install
   ```

3. **환경 설정**
   `.env` 파일 생성:
   ```env
   PORT=4001
   AGENT_ID=PC-61.84.75.16-4001
   PC_ID=PC-61.84.75.16
   HUB_URL=http://허브서버:8888
   PLATFORM=windows
   ```

4. **실행**
   ```powershell
   # 단일 에이전트
   npm start
   
   # 여러 에이전트
   .\start-agents.bat
   ```

## 주요 스크립트

### install-from-git.ps1
- 자동으로 Git에서 코드 다운로드
- Node.js 패키지 설치
- 환경 설정 파일 생성
- 방화벽 규칙 추가

### hub-update.ps1
- 허브 서버 설치/업데이트
- PostgreSQL 연결 설정
- PM2로 클러스터 모드 실행

### setup-windows-startup.ps1
- Windows 작업 스케줄러 등록
- 부팅 시 자동 시작
- 시작 폴더 바로가기 옵션

### start-agents.bat
- 5개 에이전트 동시 실행
- 각 포트별 환경 변수 설정

### check-agents.ps1
- 에이전트 상태 확인
- 서비스 상태 표시
- 네트워크 포트 확인

## 업데이트

```powershell
# 에이전트 업데이트
cd C:\ProductParser
.\update.ps1

# 허브도 함께 업데이트
.\update.ps1 -Hub
```

## 문제 해결

### 포트 사용 중
```powershell
# 포트 확인
netstat -ano | findstr :4001

# 프로세스 종료
taskkill /F /PID [프로세스ID]
```

### 방화벽 차단
```powershell
# 방화벽 규칙 추가 (관리자 권한)
New-NetFirewallRule -DisplayName "ProductParser" -Direction Inbound -Protocol TCP -LocalPort 4001-4005 -Action Allow
```

### Chrome 경로 문제
`.env` 파일에서 Chrome 경로 수정:
```env
CHROME_EXECUTABLE_PATH=C:\Program Files (x86)\Google\Chrome\Application\chrome.exe
```

## 디렉토리 구조

```
C:\ProductParser\
├── agent\                  # 에이전트 코드
│   ├── logs\              # 로그 파일
│   ├── screenshots\       # 스크린샷
│   └── .env              # 환경 설정
├── ParserHub\            # 허브 서버 (선택)
├── chrome-profiles\      # Chrome 프로필
├── start-agents.bat      # 에이전트 실행
├── start-hub.bat         # 허브 실행
└── update.ps1           # 업데이트 스크립트
```

## 보안 참고사항

1. 방화벽에서 필요한 포트만 열기 (4001-4005)
2. 허브 서버 URL은 내부 네트워크만 접근 가능하도록 설정
3. PostgreSQL 연결은 SSL 사용 권장
4. 정기적으로 코드 업데이트 실행