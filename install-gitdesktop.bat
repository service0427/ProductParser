@echo off
REM ProductParser Git Desktop 설치 스크립트
REM Git Desktop이 설치된 Windows 환경용

echo === ProductParser Agent 설치 (Git Desktop) ===
echo.

REM 기본 설정
set DEFAULT_INSTALL_PATH=C:\ProductParser
set DEFAULT_HUB_URL=http://localhost:8888
set DEFAULT_PC_IP=112.161.209.80

REM 설치 경로 입력
set /p INSTALL_PATH="설치 경로 [%DEFAULT_INSTALL_PATH%]: "
if "%INSTALL_PATH%"=="" set INSTALL_PATH=%DEFAULT_INSTALL_PATH%

REM 허브 서버 URL 입력
set /p HUB_URL="허브 서버 URL [%DEFAULT_HUB_URL%]: "
if "%HUB_URL%"=="" set HUB_URL=%DEFAULT_HUB_URL%

REM PC IP 입력
set /p PC_IP="PC IP 주소 [%DEFAULT_PC_IP%]: "
if "%PC_IP%"=="" set PC_IP=%DEFAULT_PC_IP%

echo.
echo 설치 정보:
echo   설치 경로: %INSTALL_PATH%
echo   허브 서버: %HUB_URL%
echo   PC IP: %PC_IP%
echo.

REM Node.js 확인
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [오류] Node.js가 설치되지 않았습니다!
    echo https://nodejs.org 에서 설치하세요.
    pause
    exit /b 1
)
echo [OK] Node.js 설치 확인

REM Chrome 확인
if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" (
    echo [OK] Chrome 설치 확인
) else (
    echo [경고] Chrome이 기본 경로에 없습니다
)

REM 기존 디렉토리 백업
if exist "%INSTALL_PATH%" (
    echo.
    echo 기존 디렉토리 백업 중...
    move "%INSTALL_PATH%" "%INSTALL_PATH%.backup.%date:~0,4%%date:~5,2%%date:~8,2%-%time:~0,2%%time:~3,2%%time:~6,2%"
)

REM 디렉토리 생성
echo.
echo 디렉토리 생성 중...
mkdir "%INSTALL_PATH%"
cd /d "%INSTALL_PATH%"

REM Git clone
echo.
echo GitHub에서 코드 다운로드 중...
git clone -b dev https://github.com/service0427/ProductParser.git .
if %errorlevel% neq 0 (
    echo [오류] Git clone 실패!
    pause
    exit /b 1
)

REM 에이전트 디렉토리로 이동
cd /d "%INSTALL_PATH%\agent"

REM NPM 패키지 설치
echo.
echo NPM 패키지 설치 중...
call npm install
if %errorlevel% neq 0 (
    echo [오류] NPM 설치 실패!
    pause
    exit /b 1
)

REM .env 파일 생성
echo.
echo 환경 설정 파일 생성 중...
(
echo # Windows 환경 설정
echo PORT=4001
echo AGENT_ID=PC-%PC_IP%-4001
echo PC_ID=PC-%PC_IP%
echo HUB_URL=%HUB_URL%
echo PLATFORM=windows
echo CHROME_EXECUTABLE_PATH=C:\Program Files\Google\Chrome\Application\chrome.exe
echo USER_DATA_DIR=%INSTALL_PATH%\chrome-profiles
echo LOG_LEVEL=info
echo LOG_DIR=%INSTALL_PATH%\agent\logs
echo HEARTBEAT_INTERVAL=30
echo TASK_TIMEOUT=60000
echo SCREENSHOT_DIR=%INSTALL_PATH%\agent\screenshots
echo DEBUG=false
) > .env

REM 필요한 디렉토리 생성
mkdir logs 2>nul
mkdir screenshots 2>nul
mkdir "%INSTALL_PATH%\chrome-profiles" 2>nul

REM 실행 스크립트 업데이트
echo.
echo 실행 스크립트 생성 중...
cd /d "%INSTALL_PATH%"

REM start-agents.bat 업데이트
(
echo @echo off
echo cd /d %INSTALL_PATH%\agent
echo.
echo echo === ProductParser Agent 시작 중 ===
echo echo.
echo.
echo set HUB_URL=%HUB_URL%
echo set PC_ID=PC-%PC_IP%
echo set PLATFORM=windows
echo.
echo start "Agent-4001" cmd /k "set PORT=4001 && set AGENT_ID=PC-%PC_IP%-4001 && npm start"
echo timeout /t 2 /nobreak ^>nul
echo.
echo start "Agent-4002" cmd /k "set PORT=4002 && set AGENT_ID=PC-%PC_IP%-4002 && npm start"
echo timeout /t 2 /nobreak ^>nul
echo.
echo start "Agent-4003" cmd /k "set PORT=4003 && set AGENT_ID=PC-%PC_IP%-4003 && npm start"
echo timeout /t 2 /nobreak ^>nul
echo.
echo start "Agent-4004" cmd /k "set PORT=4004 && set AGENT_ID=PC-%PC_IP%-4004 && npm start"
echo timeout /t 2 /nobreak ^>nul
echo.
echo start "Agent-4005" cmd /k "set PORT=4005 && set AGENT_ID=PC-%PC_IP%-4005 && npm start"
echo.
echo echo.
echo echo === 모든 에이전트가 시작되었습니다 ===
echo pause
) > start-agents.bat

REM update.bat 생성
(
echo @echo off
echo cd /d "%INSTALL_PATH%"
echo echo === ProductParser 업데이트 ===
echo echo.
echo git pull origin dev
echo cd agent
echo call npm install
echo echo.
echo echo 업데이트 완료!
echo pause
) > update.bat

REM check-agents.bat 생성
(
echo @echo off
echo echo === ProductParser Agent 상태 확인 ===
echo echo.
echo for /l %%%%i in (4001,1,4005^) do (
echo     echo|set /p="Port %%%%i: "
echo     curl -s -o nul -w "%%%%{http_code}" http://localhost:%%%%i/health 2^>nul | findstr "200" ^>nul
echo     if errorlevel 1 (
echo         echo OFFLINE
echo     ^) else (
echo         echo RUNNING
echo     ^)
echo ^)
echo echo.
echo pause
) > check-agents.bat

echo.
echo === 설치 완료! ===
echo.
echo 설치 경로: %INSTALL_PATH%
echo 에이전트 ID: PC-%PC_IP%-[4001-4005]
echo 허브 서버: %HUB_URL%
echo.
echo 실행 방법:
echo   %INSTALL_PATH%\start-agents.bat
echo.
echo 기타 명령:
echo   상태 확인: %INSTALL_PATH%\check-agents.bat
echo   업데이트: %INSTALL_PATH%\update.bat
echo.

choice /C YN /M "지금 에이전트를 시작하시겠습니까?"
if %errorlevel%==1 (
    start "" "%INSTALL_PATH%\start-agents.bat"
)

pause