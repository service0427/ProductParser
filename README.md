# ProductParser - 분산 웹 스크래핑 시스템

Playwright와 실제 Chrome 브라우저를 사용하는 대규모 분산 스크래핑 시스템입니다.

## 시스템 구성

- **에이전트**: Windows 11에서 실행되는 Playwright 기반 스크래핑 에이전트
- **허브**: 에이전트 관리 및 작업 분배를 담당하는 중앙 서버
- **규모**: 100대 PC × 5포트 = 총 500개 에이전트 지원

## 주요 특징

- ✅ 실제 Chrome 브라우저 사용 (자동화 탐지 우회)
- ✅ 포트별 독립 Chrome 프로필
- ✅ 크로스 플랫폼 지원 (Windows 실행, WSL 개발)
- ✅ 동적 액션 배포 시스템
- ✅ 실시간 모니터링

## 빠른 시작

### 1. WSL 개발 환경 설정

```bash
cd ProductParser
./scripts/setup-wsl.sh
```

### 2. 에이전트 테스트 (WSL)

```bash
cd agent
npm test
```

### 3. Windows에서 에이전트 실행

```powershell
# 단일 에이전트
.\scripts\start-agent.ps1 -Port 3001

# 여러 에이전트 (5개)
.\scripts\start-multiple-agents.ps1 -Count 5
```

## 프로젝트 구조

```
ProductParser/
├── agent/                    # 에이전트 (Windows)
│   ├── agent.js             # 메인 서버
│   ├── core/                # 핵심 모듈
│   │   ├── profileManager.js    # Chrome 프로필 관리
│   │   ├── heartbeat.js        # 허브 통신
│   │   └── actionRunner.js     # 액션 실행
│   ├── actions/             # 스크래핑 액션
│   │   └── naver-finance.js    # 네이버 금융
│   ├── platform/            # OS별 설정
│   └── test/                # 테스트 도구
├── hub/                     # 허브 서버 (개발 예정)
└── scripts/                 # 유틸리티 스크립트
```

## 네이버 금융 액션

첫 번째 구현된 액션으로 다음 데이터를 수집합니다:

- 코스피/코스닥 지수
- 환율 (USD, EUR, JPY)
- 원자재 (금, WTI)

### 사용 예시

```javascript
POST /execute
{
  "action": "naver-finance",
  "params": {
    "screenshot": true,    // 스크린샷 포함
    "detailed": true       // 상세 데이터 수집
  }
}
```

## API 엔드포인트

| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | /health | 에이전트 상태 확인 |
| GET | /info | 에이전트 정보 |
| POST | /execute | 액션 실행 |
| POST | /update-action | 액션 업데이트 |
| GET | /running | 실행 중인 액션 |
| GET | /profile | Chrome 프로필 정보 |

## 환경 설정

### Windows (.env.windows)
```
CHROME_EXECUTABLE=C:\Program Files\Google\Chrome\Application\chrome.exe
CHROME_PROFILE_BASE=C:\AgentProfiles
```

### WSL/Linux (.env.linux)
```
CHROME_EXECUTABLE=/usr/bin/google-chrome
CHROME_PROFILE_BASE=./profiles
```

## 개발 가이드

1. **새 액션 추가**
   - `actions/` 폴더에 새 파일 생성
   - `execute(page, params)` 함수 구현
   - 에러 처리 및 로깅 포함

2. **플랫폼별 코드**
   - `platform/` 폴더 활용
   - `process.platform` 확인
   - 경로는 항상 동적으로 처리

3. **테스트**
   - WSL: 모의 테스트 (`npm test`)
   - Windows: 실제 Chrome 테스트

## 향후 계획

- [ ] 허브 서버 구현
- [ ] 캡챠 해결 모듈 통합
- [ ] 프록시 관리 시스템
- [ ] 더 많은 사이트 액션 추가
- [ ] 성능 모니터링 대시보드

## 라이선스

내부 사용 전용