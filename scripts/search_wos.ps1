# search_wos.ps1 — Web of Science 高级检索驱动（经机构 EZproxy；Angular 按钮用 JS click）
# 用法: & .\search_wos.ps1 -Query 'TS=("star anise") AND TS=(authentication)' -Out hit.png
# 前提: 浏览器已有一条 *webofscience* 标签页且 EZproxy 会话有效（否则先走会话自愈环：请用户扫码）
param(
  [Parameter(Mandatory)][string]$Query,
  [Parameter(Mandatory)][string]$Out,
  [int]$WaitS = 40,
  [int]$Port = 9222,
  [string]$EzproxyHost = 'www-webofscience-com.libezproxy.must.edu.mo'   # 换机构改这里
)
$ErrorActionPreference = 'Stop'
$script:CDP_PORT = $Port
. (Join-Path $PSScriptRoot 'cdp_lib.ps1')

$tab = Find-CdpTab 'webofscience'
if (-not $tab) {
  # 无标签则新开（若会话过期会跳登录页，由调用方处理扫码）
  $tab = New-CdpTab "https://$EzproxyHost/wos/woscc/advanced-search"
  Start-Sleep -Seconds 12
}
$ws = Connect-Cdp $tab
$id = 1
Send-Cdp $ws $id 'Page.enable' @{}; $null = Wait-Resp $ws $id 10; $id++
Send-Cdp $ws $id 'Runtime.enable' @{}; $null = Wait-Resp $ws $id 10; $id++
Send-Cdp $ws $id 'Page.bringToFront' @{}; $null = Wait-Resp $ws $id 10; $id++

# 若不在高级检索页则导航过去
$r = Eval $ws $id "location.href"; $id++
if ($r.result.result.value -notlike '*advanced-search*') {
  Send-Cdp $ws $id 'Page.navigate' @{url = "https://$EzproxyHost/wos/woscc/advanced-search"} | Out-Null
  $null = Wait-Resp $ws $id 20; $id++
  Start-Sleep -Seconds 10
}

# 填入检索式（WoS 高级检索主输入框）并校验
$fillJs = @'
(function(q){
  const ta = document.querySelector('textarea#advancedSearchInputArea')
          || document.querySelector('textarea[id*="searchArea"]')
          || document.querySelector('textarea');
  if (!ta) return 'nofield';
  ta.focus(); ta.value = q;
  ta.dispatchEvent(new Event('input', {bubbles: true}));
  return String(q.length);
})("__QUERY__")
'@
$fillJs = $fillJs.Replace('__QUERY__', $Query.Replace("'", "\'"))
$r = Eval $ws $id $fillJs; $id++
$flen = "$($r.result.result.value)"
Write-Output ("FILL-LEN: $flen (期望 $($Query.Length))")
if ($flen -eq 'nofield') { throw 'WoS 检索框未找到' }

Start-Sleep -Seconds 2
# Angular 按钮：合成鼠标常无效，用 JS click
$r = Eval $ws $id @'
(function(){
  const els = [...document.querySelectorAll('button, input[type=submit], span.button, a')];
  for (const el of els) {
    const t = (el.innerText || el.value || '').trim();
    if (t === '检索' || t === 'Search') {
      el.click();
      return 'clicked:' + t;
    }
  }
  return 'nobtn';
})()
'@
$id++
Write-Output ("SUBMIT: $($r.result.result.value)")
Start-Sleep -Seconds 5

# 等待结果数（结果页 document.title 或结果计数区）
$hit = ''
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $WaitS) {
  Start-Sleep -Seconds 3
  $r = Eval $ws $id @'
(function(){
  const el = document.querySelector('.brand-blue-number, span[data-ta="result-count"]');
  if (el) return el.innerText.replace(/[^0-9,]/g,'');
  const m = (document.body.innerText||'').match(/([\d,]+)\s+result/i);
  return m ? m[1] : '';
})()
'@
  $id++
  $v = "$($r.result.result.value)"
  if ($v -match '^[\d,]+$') { $hit = $v; break }
}
Write-Output ("HIT: " + $(if ($hit) { $hit } else { '(未捕获到数字)' }))
$r = Eval $ws $id "location.href.substring(0,120) + ' @@ ' + (document.title||'').substring(0,60)"; $id++
Write-Output ("STATE: $($r.result.result.value)")
Start-Sleep -Seconds 2
Capture-Screen $ws $id $Out; $id++
try { $ws.Dispose() } catch {}
# WoS 标签保留（会话复用），不关闭
