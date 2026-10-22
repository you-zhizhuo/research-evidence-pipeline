# -*- coding: utf-8 -*-
"""rec_tab.py — CDP 标签页录屏（Page.startScreencast 采帧 → ffmpeg 合成 mp4）
用法: python rec_tab.py <域名子串> <输出mp4> <停止标记文件> [最长秒数=300]
流程: 轮询 /json/list 找匹配标签页 → attach(suppress_origin=True) → startScreencast
      → 收帧存 jpg 并逐帧 Ack → 停止标记/ws 关闭/超时 → ffmpeg 合成（偶数尺寸缩放）。
关键坑: Chrome 拒绝带 Origin 的 WebSocket（403）→ 必须 suppress_origin=True；
        奇数尺寸帧会让 libx264 报错 → scale=trunc(iw/2)*2:trunc(ih/2)*2；
        subprocess 必须 import。
"""
import sys, os, json, time, base64, subprocess
sys.stdout.reconfigure(encoding='utf-8')
import urllib.request
import websocket
import imageio_ffmpeg

MATCH = sys.argv[1]
MP4 = sys.argv[2]
STOP = sys.argv[3]
MAXS = int(sys.argv[4]) if len(sys.argv) > 4 else 300
PORT = int(os.environ.get('CDP_PORT', '9222'))
TMPD = MP4 + '.frames'
os.makedirs(TMPD, exist_ok=True)

def http_json(url):
    return json.loads(urllib.request.urlopen(url, timeout=10).read())

def find_tab():
    for t in http_json(f'http://127.0.0.1:{PORT}/json/list'):
        if t.get('type') == 'page' and MATCH in t.get('url', ''):
            return t
    return None

tab = None
t0 = time.time()
while time.time() - t0 < 60 and tab is None:
    tab = find_tab()
    if tab is None:
        time.sleep(2)
if tab is None:
    print('REC-ERR: 未找到匹配标签页:', MATCH)
    sys.exit(1)
print('REC: attach', tab['url'][:80])

n = 0
ws = websocket.create_connection(tab['webSocketDebuggerUrl'], timeout=2, max_size=None, suppress_origin=True)
mid = 0
def send(method, params=None):
    global mid
    mid += 1
    ws.send(json.dumps({'id': mid, 'method': method, 'params': params or {}}))
    return mid
def recv_msg(timeout=1.5):
    ws.settimeout(timeout)
    try:
        return json.loads(ws.recv())
    except websocket.WebSocketTimeoutException:
        return None
    except Exception:
        return '__CLOSED__'

send('Page.enable')
send('Page.startScreencast', {'format': 'jpeg', 'quality': 65, 'everyNthFrame': 1, 'maxWidth': 1600})
t_start = time.time()
while time.time() - t_start < MAXS:
    if os.path.exists(STOP):
        break
    m = recv_msg()
    if m == '__CLOSED__':
        print('REC: ws 已关闭（标签页关闭）')
        break
    if not m or not isinstance(m, dict):
        continue
    if m.get('method') == 'Page.screencastFrame':
        p = m['params']
        n += 1
        with open(os.path.join(TMPD, f'f{n:05d}.jpg'), 'wb') as fh:
            fh.write(base64.b64decode(p['data']))
        try:
            send('Page.screencastFrameAck', {'sessionId': p['sessionId']})
        except Exception:
            pass
try:
    send('Page.stopScreencast')
except Exception:
    pass
try:
    ws.close()
except Exception:
    pass
print(f'REC: 采帧 {n} 张，用时 {time.time()-t_start:.0f}s')

if n == 0:
    print('REC-ERR: 无帧')
    sys.exit(1)
FF = imageio_ffmpeg.get_ffmpeg_exe()
r = subprocess.run([FF, '-y', '-loglevel', 'error', '-framerate', '4',
                    '-i', os.path.join(TMPD, 'f%05d.jpg'),
                    '-vf', 'scale=trunc(iw/2)*2:trunc(ih/2)*2',
                    '-c:v', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p', MP4],
                   capture_output=True, text=True)
if r.returncode != 0:
    print('REC-ERR: 合成失败', r.stderr[-300:])
    sys.exit(1)
print(f'REC: mp4 完成 {os.path.getsize(MP4)} bytes（{n} 帧 @4fps ≈ {n//4}s）')
