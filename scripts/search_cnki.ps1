# search_cnki.ps1 — CNKI 专业检索驱动（逐字符键入 + 命中数捕获 + 截图）
# 用法: & .\search_cnki.ps1 -Query 'SU=(八角+八角茴香)*(鉴别+检测)' -Out hit.png
param(
  [Parameter(Mandatory)][string]$Query,
  [Parameter(Mandatory)][string]$Out,
  [int]$WaitS = 60,
  [int]$Port = 9222
)
$ErrorActionPreference = 'Stop'
$script:CDP_PORT = $Port
. (Join-Path $PSScriptRoot 'cdp_lib.ps1')

$advUrl = 'https://kns.cnki.net/kns8s/AdvSearch'
$tab = New-CdpTab $advUrl
$ws = Connect-Cdp $tab
$id = 1
Send-Cdp $ws $id 'Page.enable' @{}; $null = Wait-Resp $ws $id 10; $id++
Send-Cdp $ws $id 'Runtime.enable' @{}; $null = Wait-Resp $ws $id 10; $id++
Send-Cdp $ws $id 'Page.bringToFront' @{}; $null = Wait-Resp $ws $id 10; $id++
Start-Sleep -Seconds 8

# 切专业检索并定位 textarea（输入框按页面实际 DOM 调整；专业检索为 textarea[name=complexSearch] 或同类）
$probe = @'
(function(){
  // 展开高级检索页签中的专业检索
  const tabs = [...document.querySelectorAll('li,span,a,div')];
  for (const el of tabs) {
    const t = (el.innerText||'').trim();
    if (t === '专业检索' && el.children.length <= 1) { el.click(); break; }
  }
  const ta = document.querySelector('textarea[name="complexSearch"]')
          || document.querySelector('textarea.search-input')
          || document.querySelector('textarea');
  if (!ta) return '{}';
  const r = ta.getBoundingClientRect();
  return JSON.stringify({x: Math.round(r.x + Math.min(r.width/2, 300)), y: Math.round(r.y + 16)});
})()
'@
$r = Eval $ws $id $probe; $id++
$pos = ($r.result.result.value | ConvertFrom-Json)
if (-not $pos.x) { throw 'CNKI 专业检索输入框未找到' }
Click-At $ws $id $pos.x $pos.y; $id += 3
Start-Sleep -Milliseconds 500

# 逐字符键入（铁律：真实键入，可被录屏作证）
$id = Type-Text $ws $id $Query
Start-Sleep -Milliseconds 500
$r = Eval $ws $id "((document.querySelector('textarea[name=`"complexSearch`"]')||document.querySelector('textarea')||{}).value||'').length"; $id++
Write-Output ("FILL-LEN: $($r.result.result.value) (期望 $($Query.Length))")

# 点击「检索」按钮
$r = Eval $ws $id @'
(function(){
  const els = [...document.querySelectorAll('input,button,span,a')];
  for (const el of els) {
    const t = (el.value || el.innerText || '').trim();
    if (t === '检 索' || t === '检索') {
      const r = el.getBoundingClientRect();
      return JSON.stringify({x: Math.round(r.x + r.width/2), y: Math.round(r.y + r.height/2)});
    }
  }
  return '{}';
})()
'@
$id++
$bpos = (($r.result.result.value) | ConvertFrom-Json)
if ($bpos.x) { Click-At $ws $id $bpos.x $bpos.y; $id += 3 }
else { $id = Send-Enter $ws $id; Write-Output '未找到检索按钮，回车提交' }
Start-Sleep -Seconds 4

# 等待命中（人机验证出现时等待人工完成，上限 WaitS；如实留在录屏中）
$hit = ''
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $WaitS) {
  Start-Sleep -Seconds 3
  $r = Eval $ws $id @'
(function(){
  const m = (document.body.innerText||'').match(/共(?:找到|检索到)?\s*([\d,]+)\s*条/);
  if (m) return m[1];
  const el = document.querySelector('.pagerTitleCell em');
  if (el) return el.innerText.trim();
  return '';
})()
'@
  $id++
  $v = "$($r.result.result.value)"
  if ($v -match '^[\d,]+$') { $hit = $v; break }
}
Write-Output ("HIT: " + $(if ($hit) { $hit } else { '(未捕获到数字)' }))
$r = Eval $ws $id "location.href.substring(0,110)"; $id++
Write-Output ("STATE: $($r.result.result.value)")
Start-Sleep -Seconds 2
Capture-Screen $ws $id $Out; $id++
try { $ws.Dispose() } catch {}
Close-CdpTab $tab.id
