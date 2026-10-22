# 双轨录制手册

两条录制轨，按场景选择：**标签页 screencast（首选，确定性）** 与 **桌面 gdigrab（备选）**。

## 轨 1：标签页 screencast（`scripts/rec_tab.py`）

原理：CDP `Page.startScreencast` 由浏览器合成器供帧，不受桌面状态（熄屏/静态画面）影响。

```
python rec_tab.py <域名子串> <输出mp4> <停止标记文件> [最长秒数=300]
```

流程：轮询 `/json/list` 找匹配标签页 → attach（**`suppress_origin=True`，否则 Chrome 403**）→ startScreencast（jpeg, quality 65, everyNthFrame 1）→ 收帧存 `f%05d.jpg` 并逐帧 Ack → 发现停止标记 / ws 关闭 / 超时 → 停止 → ffmpeg 合成（`-framerate 4` + `-vf scale=trunc(iw/2)*2:trunc(ih/2)*2`，**奇数尺寸会让 libx264 报错**）。

编排侧约定：
1. 先清理同域残留标签页（录制器按域名 attach，残留旧标签会采到 0 帧）。
2. 启动录制器（后台、输出重定向到日志）→ 2s 后执行驱动 → 结束后写停止标记 → `WaitForExit(120s)`。
3. python/ffmpeg 的脚本与输出路径**含空格必须加引号**（Start-Process ArgumentList 不自动加引号）；建议脚本与临时产物放无空格的 `%TEMP%`，最终 `Move-Item` 到证据目录。

## 轨 2：桌面 gdigrab（`scripts/rec_desktop.ps1`）

适用：需要整个桌面语境（多窗口操作、浏览器外动作）。

```
rec_desktop.ps1 -Out <mp4> -DurationSec 130 [-Framerate 6]
```

实现要点（全部踩过坑）：
- ffmpeg 取自 `imageio-ffmpeg`（`get_ffmpeg_exe()`），参数用**单一字符串**传 `Start-Process`，输出路径带引号；stderr 重定向到日志。
- 启动判定放宽为"进程 8s 仍活着"——gdigrab 首帧延迟是常态。
- 结束等待：`-t` 到点 + **45s 宽限**等自然退出；强杀会毁掉 mp4（moov 未写）。
- 长批录制前启动 `SetThreadExecutionState(0x80000003)` 唤醒 Job（**熄屏 = 无帧 = 0 字节**）。
- 每次尝试前 `Stop-Process ffmpeg` 清残留。

## 通用规则

- **先启录制器、后操作**（铁律）；停止标记由编排器在驱动结束后写入。
- 产物命名：`录屏_{阶段}_{对象}_{动作}_{日期}.mp4`，与 manifest 同目录。
- 合成后校验：文件 > 100KB 且 ffprobe/`ffmpeg -i` 能读出 Duration；缩略图用 `-sseof -1.5` 抽末帧（命中数画面）。
- 已知坑全集见 SKILL.md「Pitfalls」——每条都有真实事故背书。
