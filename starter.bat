@echo off
setlocal

where python >nul 2>&1
if %errorlevel% neq 0 (
    curl -L -o python-3.11.9-amd64.exe https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe
    python-3.11.9-amd64.exe /quiet InstallAllUsers=1 PrependPath=1 Include_test=0
    timeout /t 10 >nul
)
python -m pip --version >nul 2>&1
if %errorlevel% neq 0 (
    python -m ensurepip
)

python -m pip install --upgrade pip

set PACKAGES=requests tqdm pywin32 mss

for %%i in (%PACKAGES%) do (
    python -m pip install %%i
)
echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
set params= %*
echo UAC.ShellExecute "cmd.exe", "/c ""%~s0"" %params:"=""%", "", "runas", 1 >> "%temp%\getadmin.vbs"
"%temp%\getadmin.vbs"
del "%temp%\getadmin.vbs"
python "%~dp0main.py"
