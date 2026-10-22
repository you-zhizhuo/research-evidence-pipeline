# -*- coding: utf-8 -*-
"""make_manifest.py — 检索录屏 manifest 生成器
用法: python make_manifest.py --dir <录屏目录> --meta <meta.json> [--out <清单.md>]
meta.json 形如:
{
  "CNKI_S001": {"platform": "中国知网", "query": "SU=(...)", "archive_hit": "528", "live_hit": "528"},
  ...
}
留档命中(archive_hit)为唯一口径；当日实况(live_hit)仅作过程对照，差异逐条如实呈现。
"""
import sys, os, re, json, argparse, subprocess
sys.stdout.reconfigure(encoding='utf-8')
import imageio_ffmpeg

ap = argparse.ArgumentParser()
ap.add_argument('--dir', required=True)
ap.add_argument('--meta', required=True)
ap.add_argument('--out', default=None)
args = ap.parse_args()
D = args.dir
OUT = args.out or os.path.join(D, '检索录屏清单.md')
META = json.load(open(args.meta, encoding='utf-8'))
FF = imageio_ffmpeg.get_ffmpeg_exe()
THUMBS = os.path.join(D, 'thumbs')
os.makedirs(THUMBS, exist_ok=True)

def dur_of(path):
    try:
        r = subprocess.run([FF, '-i', path], capture_output=True, text=True, errors='replace', timeout=60)
        m = re.search(r'Duration: (\d+):(\d+):(\d+)', r.stderr)
        if m:
            return f"{int(m.group(1))*3600 + int(m.group(2))*60 + int(m.group(3))}s"
    except Exception:
        pass
    return '?'

rows = []
for f in sorted(os.listdir(D)):
    if not f.endswith('.mp4'):
        continue
    key = f.split('_检索过程')[0].replace('录屏_', '')
    meta = META.get(key, {})
    platform = meta.get('platform', '')
    query = meta.get('query', '')
    archive = meta.get('archive_hit', '')
    live = meta.get('live_hit', '')
    mp4 = os.path.join(D, f)
    duration = dur_of(mp4)
    size = os.path.getsize(mp4)
    # 末帧缩略图（命中数画面）
    thumb = os.path.join(THUMBS, key + '.jpg')
    try:
        subprocess.run([FF, '-y', '-loglevel', 'error', '-sseof', '-1.5', '-i', mp4,
                        '-frames:v', '1', '-q:v', '3', thumb], capture_output=True, timeout=60)
    except Exception:
        pass
    rows.append((key, platform, query, live, archive, f, duration, size))
    print(f'{key}: {duration}, {size:,} B, 实况 {live} / 留档 {archive}, 缩略图 {"OK" if os.path.exists(thumb) else "-"}')

md = ['# 检索录屏清单', '',
      '说明：以下录屏为检索操作连续录像（逐字符真实键入 → 点击检索 → 命中数出现）。',
      '**命中数以留档（检索记录表/导出原件）为唯一口径**；录屏当日实况仅作过程对照，差异系数据库收录动态，逐条如实标注。',
      '录屏画面/题注不充当数字来源。', '',
      '| 编号 | 数据库 | 检索式 | 当日实况 | 留档口径 | 文件 | 时长 | 大小 |',
      '|---|---|---|---|---|---|---|---|']
for key, platform, query, live, archive, f, duration, size in rows:
    md.append(f'| {key} | {platform} | `{query}` | {live} | **{archive}** | {os.path.basename(D)}\\\\{f} | {duration} | {size:,} B |')
md += ['', '> 本清单由 scripts/make_manifest.py 生成；重跑即刷新。']
with open(OUT, 'w', encoding='utf-8') as fh:
    fh.write('\n'.join(md))
print('清单已生成:', OUT)
