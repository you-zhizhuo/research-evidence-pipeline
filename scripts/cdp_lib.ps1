# cdp_lib.ps1 — CDP 公共函数库（dot-source 使用）
# 用法: . (Join-Path $PSScriptRoot 'cdp_lib.ps1')
# 约定: Chrome 以 --remote-debugging-port=9222 启动；坐标一律 EMU/物理像素；JS 长段抽 .js 文件。

$script:CDP_PORT = if ($script:CDP_PORT) { $script:CDP_PORT } else { 9222 }
$script:CDP_CT = [Threading.CancellationToken]::None

function Invoke-CdpHttp([string]$Path) {
  Invoke-RestMethod -Uri "http://127.0.0.1:$script:CDP_PORT$Path" -TimeoutSec 10
}
function New-CdpTab([string]$Url) {
  $enc = [Uri]::EscapeDataString($Url)
  try { return Invoke-RestMethod -Method Put -Uri ("http://127.0.0.1:$script:CDP_PORT/json/new?$enc") -TimeoutSec 20 }
  catch { return Invoke-RestMethod -Uri ("http://127.0.0.1:$script:CDP_PORT/json/new?$enc") -TimeoutSec 20 }
}
function Close-CdpTab([string]$TabId) {
  try { $null = Invoke-RestMethod -Uri ("http://127.0.0.1:$script:CDP_PORT/json/close/" + $TabId) -TimeoutSec 5 } catch {}
}
function Find-CdpTab([string]$UrlMatch) {
  $tabs = Invoke-CdpHttp '/json/list'
  return ($tabs | Where-Object { $_.type -eq 'page' -and $_.url -like "*$UrlMatch*" } | Select-Object -First 1)
}
function Connect-Cdp($tab) {
  $ws = [System.Net.WebSockets.ClientWebSocket]::new()
  $null = $ws.ConnectAsync([Uri]::new($tab.webSocketDebuggerUrl), $script:CDP_CT).GetAwaiter().GetResult()
  return $ws
}
function Recv-All($ws) {
  $buf = New-Object byte[] 8388608
  $ms = New-Object System.IO.MemoryStream
  do {
    $seg = [ArraySegment[byte]]::new($buf)
    $r = $ws.ReceiveAsync($seg, $script:CDP_CT).GetAwaiter().GetResult()
    if ($r.Count -gt 0) { $ms.Write($buf, 0, $r.Count) }
  } while (-not $r.EndOfMessage)
  $s = [Text.Encoding]::UTF8.GetString($ms.ToArray()); $ms.Dispose(); return $s
}
function Send-Cdp($ws, [int]$id, [string]$method, [hashtable]$params) {
  $payload = @{id = $id; method = $method; params = $params} | ConvertTo-Json -Depth 20 -Compress
  $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
  $null = $ws.SendAsync([ArraySegment[byte]]::new($bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $script:CDP_CT).GetAwaiter().GetResult()
}
function Wait-Resp($ws, [int]$id, [int]$maxSec = 40) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt $maxSec) {
    $txt = Recv-All $ws
    if ([string]::IsNullOrWhiteSpace($txt)) { continue }
    try { $o = $txt | ConvertFrom-Json } catch { continue }
    if ($o.id -eq $id) { return $o }
  }
  throw "CDP timeout id=$id"
}
function Eval($ws, [int]$id, [string]$expr) {
  Send-Cdp $ws $id 'Runtime.evaluate' @{expression = $expr; returnByValue = $true}
  return (Wait-Resp $ws $id 25)
}
function Click-At($ws, [int]$idBase, [double]$x, [double]$y) {
  Send-Cdp $ws $idBase 'Input.dispatchMouseEvent' @{type = 'mouseMoved'; x = $x; y = $y; button = 'none'} | Out-Null
  $null = Wait-Resp $ws $idBase 10
  Send-Cdp $ws ($idBase + 1) 'Input.dispatchMouseEvent' @{type = 'mousePressed'; x = $x; y = $y; button = 'left'; clickCount = 1} | Out-Null
  $null = Wait-Resp $ws ($idBase + 1) 10
  Send-Cdp $ws ($idBase + 2) 'Input.dispatchMouseEvent' @{type = 'mouseReleased'; x = $x; y = $y; button = 'left'; clickCount = 1} | Out-Null
  $null = Wait-Resp $ws ($idBase + 2) 10
}
function Type-Text($ws, [int]$idBase, [string]$Text) {
  # 逐字符真实键入；返回下一个可用 id
  $id = $idBase
  foreach ($ch in $Text.ToCharArray()) {
    Send-Cdp $ws $id 'Input.dispatchKeyEvent' @{type = 'keyDown'; text = "$ch"; key = "$ch"; unmodifiedText = "$ch"} | Out-Null
    $null = Wait-Resp $ws $id 10; $id++
    Send-Cdp $ws $id 'Input.dispatchKeyEvent' @{type = 'keyUp'; key = "$ch"} | Out-Null
    $null = Wait-Resp $ws $id 10; $id++
  }
  return $id
}
function Send-Enter($ws, [int]$idBase) {
  Send-Cdp $ws $idBase 'Input.dispatchKeyEvent' @{type = 'keyDown'; key = 'Enter'; code = 'Enter'; windowsVirtualKeyCode = 13; text = "`r"} | Out-Null
  $null = Wait-Resp $ws $idBase 10
  Send-Cdp $ws ($idBase + 1) 'Input.dispatchKeyEvent' @{type = 'keyUp'; key = 'Enter'; code = 'Enter'; windowsVirtualKeyCode = 13} | Out-Null
  $null = Wait-Resp $ws ($idBase + 1) 10
  return ($idBase + 2)
}
function Capture-Screen($ws, [int]$id, [string]$OutPng) {
  Send-Cdp $ws $id 'Page.captureScreenshot' @{format = 'png'}
  $r = Wait-Resp $ws $id 40
  [IO.File]::WriteAllBytes($OutPng, [Convert]::FromBase64String($r.result.data))
  Write-Output ("SAVED: $OutPng " + (Get-Item $OutPng).Length + " bytes")
}
