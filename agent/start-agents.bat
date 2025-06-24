@echo off
REM ProductParser Agent 배치 실행 스크립트
REM 5개의 에이전트를 각각 다른 포트에서 실행

cd /d C:\ProductParser\agent

REM 로그 폴더 생성
if not exist logs mkdir logs

REM 허브 서버 주소 설정 (실제 주소로 변경 필요)
set HUB_URL=http://허브서버주소:3000
set PC_ID=PC-61.84.75.16
set PLATFORM=windows

REM Chrome 프로필 디렉토리 생성
if not exist C:\ProductParser\chrome-profiles mkdir C:\ProductParser\chrome-profiles

echo === ProductParser Agent 시작 중 ===
echo.

REM 포트 4001 에이전트
start "Agent-4001" cmd /k "set PORT=4001 && set AGENT_ID=%PC_ID%-4001 && set PC_ID=%PC_ID% && set HUB_URL=%HUB_URL% && set PLATFORM=%PLATFORM% && npm start"
timeout /t 2 /nobreak >nul

REM 포트 4002 에이전트
start "Agent-4002" cmd /k "set PORT=4002 && set AGENT_ID=%PC_ID%-4002 && set PC_ID=%PC_ID% && set HUB_URL=%HUB_URL% && set PLATFORM=%PLATFORM% && npm start"
timeout /t 2 /nobreak >nul

REM 포트 4003 에이전트
start "Agent-4003" cmd /k "set PORT=4003 && set AGENT_ID=%PC_ID%-4003 && set PC_ID=%PC_ID% && set HUB_URL=%HUB_URL% && set PLATFORM=%PLATFORM% && npm start"
timeout /t 2 /nobreak >nul

REM 포트 4004 에이전트
start "Agent-4004" cmd /k "set PORT=4004 && set AGENT_ID=%PC_ID%-4004 && set PC_ID=%PC_ID% && set HUB_URL=%HUB_URL% && set PLATFORM=%PLATFORM% && npm start"
timeout /t 2 /nobreak >nul

REM 포트 4005 에이전트
start "Agent-4005" cmd /k "set PORT=4005 && set AGENT_ID=%PC_ID%-4005 && set PC_ID=%PC_ID% && set HUB_URL=%HUB_URL% && set PLATFORM=%PLATFORM% && npm start"

echo.
echo === 모든 에이전트가 시작되었습니다 ===
echo.
echo 상태 확인: http://localhost:4001/health (부터 4005까지)
echo.
pause