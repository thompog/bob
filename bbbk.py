import os
import getpass
from urllib import request, error
from os.path import exists as exist
import sys
import winreg
from pathlib import Path
import shutil

from os.path import exists as exist
import tkinter as tk

# made by Thompog
# github: https://github.com/thompog
# youtube: https://www.youtube.com/@Xstorm_setstor
#
#ExLoader installs via zip so need for unzip and exec is needed

try:
    user = getpass.getuser()
except Exception:
    user = os.environ.get("USERNAME", "Default")

program_name = "bbbk"
downloads = f"C:\\Users\\{user}\\{program_name}\\downloads"
main_path_full = f"C:\\Users\\{user}\\{program_name}\\main"
main_exe = f"C:\\Users\\{user}\\{program_name}\\main\\{program_name}.py"
logging = f"C:\\Users\\{user}\\{program_name}\\logging"
loggers = f"C:\\Users\\{user}\\{program_name}\\logging\\log.txt"
parts = f"C:\\Users\\{user}\\{program_name}\\parts"
main_starter = f"C:\\Users\\{user}\\{program_name}\\parts\\starter.bat"

if not exist(f"C:\\Users\\{user}\\{program_name}"):
    os.mkdir(f"C:\\Users\\{user}\\{program_name}")

def get_windows_desktop():
    registry_key = winreg.OpenKey(
        winreg.HKEY_CURRENT_USER, 
        r"Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
    )
    
    raw_path, _ = winreg.QueryValueEx(registry_key, "Desktop")
    winreg.CloseKey(registry_key)
    expanded_path = os.path.expandvars(raw_path)

    return Path(expanded_path)

def log(text: str, is_part: bool, *Dong: str):
    if not exist(logging):
        os.mkdir(logging)

    if not exist(loggers):
        with open(loggers, "w") as file:
            file.write("start_of_file")

    if not is_part:
        with open(loggers, "a") as file:
            file.write(f"{text}:")

    with open(loggers, "a") as file:
        for line in Dong:
            file.write(line)

def check_version_python():
    ferst = 9
    for _ in range(9):
        url = f"https://www.python.org/downloads/release/python-{ferst}00"
        try:
            with request.urlopen(url, timeout=5) as response:
                if response.status == 200:
                    break
        except error.HTTPError as e:
            if e.code == 404:
                ferst -= 1
                continue
        except Exception:
            continue

    mid = 20
    for _ in range(20):
        url = f"https://www.python.org/downloads/release/python-{ferst}{mid}0"
        try:
            with request.urlopen(url, timeout=5) as response:
                if response.status == 200:
                    break
        except error.HTTPError as e:
            if e.code == 404:
                mid -= 1
                continue
        except Exception:
            continue

    new = 20
    for _ in range(20):
        url = f"https://www.python.org/downloads/release/python-{ferst}{mid}{new}"
        try:
            with request.urlopen(url, timeout=5) as response:
                if response.status == 200:
                    break
        except error.HTTPError as e:
            if e.code == 404:
                new -= 1
                continue
        except Exception:
            continue

    url = f"https://www.python.org/ftp/python/{ferst}.{mid}.{new}/python-{ferst}.{mid}.{new}-amd64.exe"
    return url, f"python-{ferst}.{mid}.{new}-amd64.exe", f"{ferst}.{mid}.{new}"

def install_newest_python(start_after_install: bool):
    log("downloading of python", False, "Checking python newest version")
    new_url, filename, ver = check_version_python()

    path = downloads
    path_with_name = os.path.join(path, filename)

    if not sys.version.startswith(ver):
        try:
            with request.urlopen(new_url, timeout=15) as response:
                if response.status == 200:
                    with open(path_with_name, "wb") as file:
                        file.write(response.read())
                    print(f"downloaded: {filename} ")
                    log("downloading of python", True, f"try download: {ver}" "Downloaded python")
                else:
                    print(f"Failed to download file. HTTP {response.status}")
                    log("downloading of python", True, f"try download: {ver}" f"Failed due to HTTP error: {response.status}")
        except Exception as exc:
            print(f"Failed to download file: {exc}")
            log("downloading of python", True, f"try download: {ver}" f"Failed due to an error: {exc}")
    else:
        log("download of python", True, "runtime version is up to date")

    if start_after_install:
        os.startfile(path_with_name)

log("folder making", False)

if not exist(logging):
    os.mkdir(logging)
    log("", True, f"made: {logging}")

if not exist(main_path_full):
    os.mkdir(main_path_full)
    log("", True, f"made: {main_path_full}")

if not exist(parts):
    os.mkdir(parts)
    log("", True, f"made: {parts}")

if not exist(main_exe):
    import shutil
    from pathlib import Path

    path = Path.cwd()
    batch = f"""
    @echo off
    title restarter
    timeout 2
    del /Q "{path}"
    timeout 3
    python "{main_exe}"
    """

    if not exist(main_starter):
        with open(main_starter, "w") as file:
            file.write(batch)

    log("relocation of main exe", False, "relocated main file")
    shutil.copyfile(path, main_exe)
    os.startfile(main_starter)
    sys.exit(0)

def load_music():
    try:
        import yt_dlp
    except ModuleNotFoundError:
        os.system('python -m pip install -U --pre "yt-dlp[default]"')

    music_path_1 = os.path.join(Path.cwd(), "Pepsiman Pepsiman Pepsiman ⧸ Pepsiman Remix [3yHL-bb0Z8k].f399.mp4")
    music_path_2 = os.path.join(Path.cwd(), "Pepsiman Pepsiman Pepsiman ⧸ Pepsiman Remix [3yHL-bb0Z8k].f251.webm")

    if not exist(music_path_1):
        if exist(music_path_2):
            os.remove(music_path_2)
        os.system('python -m yt_dlp -qU --no-warnings "https://www.youtube.com/watch?v=3yHL-bb0Z8k"')

    if not exist(music_path_1):
        log("music download", False, "download failed with yt_dlp")
        return
    
    os.system(f'start "" /min "{music_path_1}"')

def install_stuff(app: str, url: str, location: str | Path, reason: str):
    try:
        with request.urlopen(url, timeout=15) as response:
            if response.status == 200:
                with open(location, "wb") as file:
                    file.write(response.read())
                print(f"{app} downloaded!")
                log(reason, True, f"{app} downloaded")
            else:
                print(f"Failed to download {app}. HTTP {response.status}")
                log(reason, True, f"Failed to download {app}. HTTP {response.status}")
    except Exception as exc:
        print(f"Failed to download {app}: {exc}")
        log(reason, True, f"Failed to download {app}: {exc}")

def start_installer(app, is_ExLoader: bool):
    if is_ExLoader:
        app = os.path.join(app, "ExLoader_Installer.exe")
    os.startfile(app)

def installation_of_apps(main: tk.Tk, apps: list):
    main.destroy()
    global main_path

    log("installation of apps", False)
    where_app = {"steam": f"{os.path.join(main_path, "SteamSetup.exe")}", "discord": f"{os.path.join(main_path, "DiscordSetup.exe")}", "GC": f"{os.path.join(main_path, "ChromeSetup.exe")}", "ExLoader": f"{os.path.join(main_path, "ExLoader_Installer.zip")}", "after_ExLoader": f"{os.path.join(main_path, "ExLoader_installer")}", "VSC": f"{os.path.join(main_path, "VSCodeUserSetup-x64-1.134.0.exe")}", "RG": f"{os.path.join(main_path, "Rockstar-Games-Launcher.exe")}", "EA": f"{os.path.join(main_path, "EAappInstaller.exe")}", "blender": f"{os.path.join(main_path, "blender-5.2.0-windows-x64.msi")}"}

    for app in apps:
        if app == "steam":
            log("installation of apps", True, "try install steam")
            if not exist(where_app['steam']):
                install_stuff(
                    "Steam", 
                    "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe", 
                    where_app['steam'], 
                    "installation of apps"
                )
        if app == "discord":
            if not exist(where_app['discord']):
                install_stuff(
                    "Discord", 
                    "https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x64", 
                    where_app['discord'], 
                    "installation of apps"
                )
        if app == "GC":
            if not exist(where_app['GC']):
                install_stuff(
                    "Google Chrome", 
                    r"https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7BBEF6FA43-12CF-14C2-1642-CE78BE541163%7D%26lang%3Den%26browser%3D0%26usagestats%3D1%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3D-arch_x64-statsdef_1%26installdataindex%3Dempty/update2/installers/ChromeSetup.exe", 
                    where_app['GC'], 
                    "installation of apps"
                )
        if app == "ExLoader":
            if not exist(where_app['ExLoader']):
               install_stuff(
                    "ExLoader_Installer.zip", 
                    "https://data.ExLoader.net/ExLoader_Installer.zip", 
                    where_app['ExLoader'], 
                    "installation of apps"
                ) 
               shutil.unpack_archive(where_app['ExLoader'], where_app['after_ExLoader'])
        if app == "VSC":
            if not exist(where_app['VSC']):
                install_stuff(
                    "VSCode", 
                    "https://code.visualstudio.com/thank-you?dv=win&build=stable&v2=true",
                    where_app['VSC'], 
                    "installation of apps"
                )
        if app == "RG":
            if not exist(where_app['RG']):
                install_stuff(
                    "Rockstar Games Launcher", 
                    "https://gamedownloads.rockstargames.com/public/installer/Rockstar-Games-Launcher.exe",
                    where_app['RG'], 
                    "installation of apps"
                )
        if app == "EA":
            if not exist(where_app['EA']):
                install_stuff(
                    "EA", 
                    "https://origin-a.akamaihd.net/EA-Desktop-Client-Download/installer-releases/EAappInstaller.exe",
                    where_app['EA'], 
                    "installation of apps"
                )
        if app == "blender":
            if not exist(where_app['blender']):
                install_stuff(
                    "blender", 
                    "https://www.blender.org/download/release/Blender5.2/blender-5.2.0-windows-x64.msi",
                    where_app['blender'], 
                    "installation of apps"
                )

    main = tk.Tk()
    main.title("choice of install")
    main.geometry("600x450")
    main.resizable(True, True)

    tk.Label(main, text="DO NOT SPAM PRESS BUTTONS DOES BUTTONS STARTS THE INSTALLERS FOR THAT APP STARTING TO MENY AT THE SAME TIME CAN CRASH THE COMPUTER OR REMEDIATION BY WINDOWS DEFENDER").pack(padx=0, pady=25)
    for app in apps:
        if app == "ExLoader":
            tk.Button(main, text=f"start installer for {app}", command=lambda: start_installer(where_app['after_ExLoader'], True)).pack(padx=0,pady=5)
            tk.Label(main, text=f"this button starts the installer for {app}").pack(padx=0,pady=15)

        tk.Button(main, text=f"start installer for {app}", command=lambda: start_installer(where_app[f'{app}'], False)).pack(padx=0,pady=5)
        tk.Label(main, text=f"this button starts the installer for {app}").pack(padx=0,pady=15)

    main.mainloop()

def next_after(root: tk.Tk, main_path: Path):
    root.destroy()
    main = tk.Tk()
    main.title("choice of install")
    main.geometry("600x450")
    main.resizable(True, True)
    icon_path = os.path.join(main_path, "CES_icon.png")
    if not exist(icon_path):
        icon_url = "https://github.com/thompog/CES/releases/download/fty/CES_icon.png"
        try:
            with request.urlopen(icon_url, timeout=15) as response:
                if response.status == 200:
                    with open(icon_path, "wb") as file:
                        file.write(response.read())
                    print("Image downloaded!")
                    log("start make menu", True, "Image downloaded")
                else:
                    print(f"Failed to download image. HTTP {response.status}")
                    log("start make menu", True, f"Failed to download image. HTTP {response.status}")
        except Exception as exc:
            print(f"Failed to download image: {exc}")
            log("start make menu", True, f"Failed to download image: {exc}")
    
    if exist(icon_path):
        try:
            app_icon = tk.PhotoImage(file=icon_path)
            main.iconphoto(False, app_icon)
    
            width = app_icon.width()
            height = app_icon.height()
            x_ratio = max(1, (width + 49) // 50)
            y_ratio = max(1, (height + 49) // 50)
            image_50 = app_icon.subsample(x_ratio, y_ratio)
    
            label = tk.Label(main, image=image_50, borderwidth=0, highlightthickness=0)
            label.place(x=0, y=0, anchor="nw")
            log("start make menu", True, "loaded image")
        except Exception as exc:
            print(f"Failed to set app icon: {exc}")
            log("start make menu", True, f"Failed to set app icon: {exc}")

    install: list = []

    Label = tk.Label(main, text="choice what to install")
    Label.pack(padx=5, pady=15)
    tk.Button(main, text="install steam", command=lambda: install.append("steam")).pack(padx=0,pady=5)
    tk.Button(main, text="install discord", command=lambda: install.append("discord")).pack(padx=0,pady=5)
    tk.Button(main, text="install Google Chome", command=lambda: install.append("GC")).pack(padx=0,pady=5)
    tk.Button(main, text="install ExLoader", command=lambda: install.append("ExLoader")).pack(padx=0,pady=5)
    tk.Button(main, text="install Visual Studio Code", command=lambda: install.append("VSC")).pack(padx=0,pady=5)
    tk.Button(main, text="install Rockstar Games", command=lambda: install.append("RG")).pack(padx=0,pady=5)
    tk.Button(main, text="install EA", command=lambda: install.append("EA")).pack(padx=0,pady=5)
    tk.Button(main, text="install blender", command=lambda: install.append("blender")).pack(padx=0,pady=5)
    tk.Label(main, text="").pack(pady=25)
    tk.Button(main, text="start install", command=lambda: installation_of_apps(main, install)).pack(padx=0,pady=5)
    main.mainloop()

install_newest_python(True)

log("start make menu", False)

main_path = Path.cwd()

main = tk.Tk()
main.title("check background music")
main.geometry("600x450")
main.resizable(False, False)

icon_path = os.path.join(main_path, "CES_icon.png")
if not exist(icon_path):
    icon_url = "https://github.com/thompog/CES/releases/download/fty/CES_icon.png"
    try:
        with request.urlopen(icon_url, timeout=15) as response:
            if response.status == 200:
                with open(icon_path, "wb") as file:
                    file.write(response.read())
                print("Image downloaded!")
                log("start make menu", True, "Image downloaded")
            else:
                print(f"Failed to download image. HTTP {response.status}")
                log("start make menu", True, f"Failed to download image. HTTP {response.status}")
    except Exception as exc:
        print(f"Failed to download image: {exc}")
        log("start make menu", True, f"Failed to download image: {exc}")
    
if exist(icon_path):
    try:
        app_icon = tk.PhotoImage(file=icon_path)
        main.iconphoto(False, app_icon)
    
        width = app_icon.width()
        height = app_icon.height()
        x_ratio = max(1, (width + 49) // 50)
        y_ratio = max(1, (height + 49) // 50)
        image_50 = app_icon.subsample(x_ratio, y_ratio)
    
        label = tk.Label(main, image=image_50, borderwidth=0, highlightthickness=0)
        label.place(x=0, y=0, anchor="nw")
        log("start make menu", True, "loaded image")
    except Exception as exc:
        print(f"Failed to set app icon: {exc}")
        log("start make menu", True, f"Failed to set app icon: {exc}")

load_music_button = tk.Button(main, text="start background music", command=load_music)
load_music_button.pack(padx=5, pady=5)

without_button = tk.Button(main, text="contine without music", command=lambda: next_after(main, main_path))
without_button.pack(padx=5, pady=5)

exit_button = tk.Button(main, text="exit", command=lambda: sys.exit(0))
exit_button.pack(padx=5, pady=5)

log("start make menu", True, "done with menu")

main.mainloop()