# Windows 시작 시 자동 실행 설정 스크립트
# 작업 스케줄러를 사용하여 부팅 시 에이전트 자동 시작

param(
    [string]$InstallPath = "C:\ProductParser",
    [switch]$Remove
)

# 관리자 권한 확인
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "이 스크립트는 관리자 권한이 필요합니다!" -ForegroundColor Red
    Write-Host "PowerShell을 관리자 권한으로 다시 실행하세요." -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Windows 자동 시작 설정 ===" -ForegroundColor Cyan
Write-Host ""

# 작업 이름
$taskName = "ProductParserAgents"

if ($Remove) {
    # 작업 제거
    Write-Host "기존 작업 제거 중..." -ForegroundColor Yellow
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        Write-Host "✓ 작업이 제거되었습니다." -ForegroundColor Green
    } catch {
        Write-Host "작업이 존재하지 않습니다." -ForegroundColor Gray
    }
    exit 0
}

# 실행 파일 확인
$batchFile = "$InstallPath\start-agents.bat"
if (-not (Test-Path $batchFile)) {
    Write-Host "실행 파일을 찾을 수 없습니다: $batchFile" -ForegroundColor Red
    Write-Host "먼저 install-from-git.ps1을 실행하세요." -ForegroundColor Yellow
    exit 1
}

# 기존 작업 제거
try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
} catch {}

# VBS 래퍼 생성 (콘솔 창 숨김)
$vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run """$batchFile""", 0
Set WshShell = Nothing
"@

$vbsPath = "$InstallPath\start-agents-hidden.vbs"
$vbsContent | Out-File -FilePath $vbsPath -Encoding ASCII

Write-Host "작업 스케줄러 등록 중..." -ForegroundColor Yellow

# 작업 생성
$action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument """$vbsPath"""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "ProductParser 에이전트 자동 시작"

# 작업 등록
Register-ScheduledTask -TaskName $taskName -InputObject $task | Out-Null

Write-Host "✓ 작업 스케줄러 등록 완료" -ForegroundColor Green

# 지연 시작 설정 (시스템 부팅 후 30초)
$trigger = Get-ScheduledTask -TaskName $taskName | Get-ScheduledTaskTrigger
$trigger.Delay = "PT30S"
Set-ScheduledTask -TaskName $taskName -Trigger $trigger | Out-Null

Write-Host "✓ 부팅 후 30초 지연 설정" -ForegroundColor Green

# 작업 정보 표시
Write-Host "`n=== 등록된 작업 정보 ===" -ForegroundColor Cyan
$registeredTask = Get-ScheduledTask -TaskName $taskName
Write-Host "작업 이름: $($registeredTask.TaskName)" -ForegroundColor Gray
Write-Host "상태: $($registeredTask.State)" -ForegroundColor Gray
Write-Host "다음 실행: 시스템 시작 시" -ForegroundColor Gray

Write-Host "`n추가 옵션:" -ForegroundColor Yellow
Write-Host "  - 시작 폴더에 바로가기 추가" -ForegroundColor Gray

# 시작 폴더 바로가기 생성 옵션
$response = Read-Host "`n시작 폴더에 바로가기를 추가하시겠습니까? (Y/N)"
if ($response -eq 'Y' -or $response -eq 'y') {
    $startupFolder = [Environment]::GetFolderPath("Startup")
    $shortcutPath = "$startupFolder\ProductParser Agents.lnk"
    
    $WshShell = New-Object -ComObject WScript.Shell
    $shortcut = $WshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $batchFile
    $shortcut.WorkingDirectory = $InstallPath
    $shortcut.Description = "ProductParser 에이전트 시작"
    $shortcut.Save()
    
    Write-Host "✓ 시작 폴더에 바로가기 생성: $shortcutPath" -ForegroundColor Green
}

Write-Host "`n=== 설정 완료 ===" -ForegroundColor Green
Write-Host ""
Write-Host "다음 시스템 시작 시 에이전트가 자동으로 실행됩니다." -ForegroundColor Gray
Write-Host ""
Write-Host "수동 제어:" -ForegroundColor Yellow
Write-Host "  작업 실행: schtasks /run /tn `"$taskName`"" -ForegroundColor Gray
Write-Host "  작업 중지: schtasks /end /tn `"$taskName`"" -ForegroundColor Gray
Write-Host "  작업 제거: .\setup-windows-startup.ps1 -Remove" -ForegroundColor Gray
Write-Host ""
Write-Host "작업 스케줄러에서 직접 관리: taskschd.msc" -ForegroundColor Cyan