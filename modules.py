import time
import easyocr
import pyautogui
import numpy as np
import cv2
import pydirectinput
import mss
from PIL import Image
import base64
import requests

reader = easyocr.Reader(['en'], gpu=True)

def get_text(x1,y1,x2,y2):
    img = np.array(pyautogui.screenshot(region=(x1,y1,x2-x1,y2-y1)))
    ing = cv2.cvtColor(ing,cv2.COLOR_RGB2GRAY)
    text = reader.readtext(img,detail=0)
    return text

def cl_at(x,y,delay=0.2, count=1):
    if x is None or y is None:
        raise IndexError()
    pydirectinput.moveTo(x,y)
    time.sleep(delay)
    pydirectinput.moveTo(x+1,y+1)
    for i in range(count):
        pydirectinput.click()
    time.sleep(delay)

def hold_key(key, duration):
    pydirectinput.keyDown(key)
    time.sleep(duration)
    pydirectinput.keyUp(key)

def take_screen(type="", region={}):
    """
    It takes a screenshot for itch monitor there is in type defined by the user.
    The output file will be "monitori.png"
    The i is for witch monitor it is if its a screenshot from monitor 1 and is type "png"
    then the output will be "monitor1.png"
    If "region" is None and "type" is not region then it screenshots the hole monitor else in the region of the monitor
    """
    with mss.mss() as sct:
        if type == "PIL" or type == "pil":
            for i, monitor in enumerate(sct.monitors):
                scr = sct.grab(sct.monitors[i])
                img = Image.frombytes('RGB', scr.size, scr.bgra, 'raw', 'BGRX')
                img.save(f'monitor{i}.png')
        elif type == "PNG" or type == "png":
            for i, monitor in enumerate(sct.monitors):
                scr = sct.grab(sct.monitors[i])
                mss.tools.to_png(scr.rgb, scr.size, output=f"monitor{i}.png")
        elif type == "region" or type == "Region":
            scr = sct.grab(region)
            mss.tools.to_png(scr.rgb, scr.size, output="region.png")
        else:
            print(f'error: cant take screenshot of type "{type}"')
            return
        
def send_image_to_discord(image_file, url):
    img = cv2.imread(image_file)
    string_img = base64.b64encode(cv2.imencode('.png', img)[1]).decode()
    req = {"image": string_img}
    res = requests.post(url, json=req)
    return res