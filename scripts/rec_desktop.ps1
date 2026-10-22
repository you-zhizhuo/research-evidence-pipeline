# rec_desktop.ps1 — 桌面录制轨（ffmpeg gdigrab；自然退出 + 唤醒 + 引号修正）
# 用法: & .\rec_desktop.ps1 -Out "$env:TEMP\rec.mp4" -DurationSec 130
# 注意: 输出路径含空格也没问题（内部已引号）；长批录制请保持本进程存活。
param(
  [Parameter(Mandatory)][string]$Out,
  [int]$DurationSec = 130,
  [int]$Framerate = 6,
  [switch]$KeepAwake
)
$ErrorActionPreference = 'Stop'
$PY = "$env:LOCALAPPDATA\Programs\Python\Python314\python.exe"
$FF = & $PY -c "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())"

if ($KeepAwake) {
  # 熄屏 = 无帧 = 0 字节；开唤醒线程（ES_CONTINUOUS|ES_SYSTEM_REQUIRED|ES_DISPLAY_REQUIRED）
  $null = Start-Job -ScriptBlock {
    Add-Type -Namespace W -Name P -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint esFlags);'
    while ($true) { [W.P]::SetThreadExecutionState([uint32]'2147483651') | Out-Null; Start-Sleep -Seconds 25 }
  }
}

Remove-Item $Out -Force -ErrorAction SilentlyContinue
$ffLog = "$env:TEMP\ff_rec.err.log"
# 单字符串参数：输出路径必须带引号（ArgumentList 不自动加引号）
$argStr = "-hide_banner -loglevel warning -f gdigrab -framerate $Framerate -i desktop -t $DurationSec -c:v libx264 -preset veryfast -pix_fmt yuv420p -y `"$Out`""
$ff = Start-Process -FilePath $FF -ArgumentList $argStr -PassThru -WindowStyle Hidden -RedirectStandardError $ffLog
Start-Sleep -Seconds 8
if ($ff.HasExited) { throw "ffmpeg 启动即退出：$(Get-Content $ffLog -Tail 3)" }
Write-Output "REC: 录制中（$DurationSec{s}）"
$sw = [Diagnostics.Stopwatch]::StartNew()
# 等 -t 自然结束 + 45s 宽限（gdigrab 首帧延迟；强杀毁 mp4）
while (-not $ff.HasExited -and $sw.Elapsed.TotalSeconds -lt ($DurationSec + 45)) { Start-Sleep -Seconds 2 }
if (-not $ff.HasExited) { Write-Output 'REC: 宽限超时，强制结束'; Stop-Process -Id $ff.Id -Force }
Start-Sleep -Seconds 2
if ((Test-Path $Out) -and (Get-Item $Out).Length -gt 100KB) {
  Write-Output ("REC: 完成 " + (Get-Item $Out).Length + " bytes")
} else {
  throw "REC: 失败（文件缺失或过小）"
}
