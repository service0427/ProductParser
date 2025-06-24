# ProductParser Git Bash 설치 가이드

## 원클릭 설치 (Git Bash에서 실행)

### 방법 1: 원라이너 설치
```bash
curl -sSL https://raw.githubusercontent.com/service0427/ProductParser/dev/install-oneliner.sh | bash
```

### 방법 2: 다운로드 후 실행
```bash
# 설치 스크립트 다운로드
curl -O https://raw.githubusercontent.com/service0427/ProductParser/dev/install-agent.sh

# 실행 권한 부여
chmod +x install-agent.sh

# 설치 실행
./install-agent.sh
```

## 설치 과정

스크립트 실행 시 다음 정보를 입력합니다:
- 설치 경로 (기본값: C:/ProductParser)
- 허브 서버 URL (기본값: http://localhost:8888)
- PC IP 주소 (기본값: 61.84.75.16)

## 설치 후 디렉토리 구조

```
C:/ProductParser/
├── agent/                 # 에이전트 코드
│   ├── logs/             # 로그 파일
│   ├── screenshots/      # 스크린샷
│   └── .env             # 환경 설정
├── chrome-profiles/      # Chrome 프로필
├── start-agents.sh      # Git Bash 실행 스크립트
├── start-agents.bat     # Windows 배치 파일
├── check-agents.sh      # 상태 확인
└── update.sh           # 업데이트 스크립트
```

## 실행 방법

### Git Bash에서 실행
```bash
# 에이전트 시작
/c/ProductParser/start-agents.sh

# 상태 확인
/c/ProductParser/check-agents.sh

# 업데이트
/c/ProductParser/update.sh
```

### Windows CMD/PowerShell에서 실행
```cmd
# 에이전트 시작
C:\ProductParser\start-agents.bat
```

## 에이전트 관리

### 개별 에이전트 실행
```bash
cd /c/ProductParser/agent
PORT=4001 AGENT_ID=PC-61.84.75.16-4001 node agent.js
```

### 프로세스 확인
```bash
# Git Bash
ps aux | grep node

# Windows
tasklist | findstr node
```

### 프로세스 종료
```bash
# Git Bash
pkill -f "node agent.js"

# Windows
taskkill /F /IM node.exe
```

## 환경 설정

`.env` 파일 수정:
```bash
nano /c/ProductParser/agent/.env
```

주요 설정:
- `HUB_URL`: 허브 서버 주소
- `PORT`: 에이전트 포트 (4001-4005)
- `CHROME_EXECUTABLE_PATH`: Chrome 실행 파일 경로

## 문제 해결

### Node.js가 없다는 오류
```bash
# Node.js 설치 확인
node --version

# 없으면 https://nodejs.org 에서 설치
```

### Chrome 경로 문제
`.env` 파일에서 Chrome 경로 수정:
```
CHROME_EXECUTABLE_PATH=C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe
```

### 포트 사용 중
```bash
# 포트 확인
netstat -an | grep 4001

# 프로세스 종료
taskkill /F /PID [프로세스ID]
```

## 자동 시작 설정

### Windows 작업 스케줄러 사용
1. 작업 스케줄러 열기 (taskschd.msc)
2. 기본 작업 만들기
3. 트리거: 시스템 시작 시
4. 동작: 프로그램 시작
5. 프로그램: `C:\ProductParser\start-agents.bat`

### 시작 폴더에 추가
```bash
# Git Bash에서
cp /c/ProductParser/start-agents.bat "/c/Users/$USER/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup/"
```

## 보안 참고사항

1. 방화벽에서 포트 4001-4005 허용
2. 허브 서버는 내부 네트워크만 접근 가능하도록 설정
3. 정기적으로 `update.sh` 실행하여 최신 버전 유지