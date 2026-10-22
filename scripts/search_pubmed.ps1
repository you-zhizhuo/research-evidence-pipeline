# search_pubmed.ps1 — PubMed 检索驱动（含 JS focus 兜底 + Enter 补发）
# 用法: & .\search_pubmed.ps1 -Query '(Illicium verum[Title/Abstract]) AND identification[Title/Abstract]' -Out hit.png
param(
  [Parameter(Mandatory)][string]$Query,
  [Parameter(Mandatory)][string]$Out,
  [int]$WaitS = 30,
  [int]$Port = 9222
)
$ErrorActionPreference = 'Stop'
$script:CDP_PORT = $Port
. (Join-Path $PSScriptRoot 'cdp_lib.ps1')

$tab = New-CdpTab 'https://pubmed.ncbi.nlm.nih.gov/'
$ws = Connect-Cdp $tab
$id = 1
Send-Cdp $ws $id 'Page.enable' @{}; $null = Wait-Resp $ws $id 10; $id++
Send-Cdp $ws $id 'Runtime.enable' @{}; $null = Wait-Resp $ws $id 10; $id++
Send-Cdp $ws $id 'Page.bringToFront' @{}; $null = Wait-Resp $ws $id 10; $id++
Start-Sleep -Seconds 10

# 等检索框出现（最多 15s）
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt 15) {
  $r = Eval $ws $id "!!(document.querySelector('input#id-term')||document.querySelector('input[name=term]'))"; $id++
  if ($r.result.result.value -eq $true) { break }
  Start-Sleep -Seconds 2
}

# 定位并点击
$r = Eval $ws $id @'
(function(){
  const ta = document.querySelector('input#id-term') || document.querySelector('input[name="term"]');
  if (!ta) return '{}';
  const r = ta.getBoundingClientRect();
  return JSON.stringify({x: Math.round(r.x + r.width/2), y: Math.round(r.y + Math.min(r.height/2, 30))});
})()
'@
$id++
$tpos = (($r.result.result.value) | ConvertFrom-Json)
if (-not $tpos.x) { throw 'PubMed 检索框未找到' }
Click-At $ws $id $tpos.x $tpos.y; $id += 3
Start-Sleep -Milliseconds 600

# 键入 + 校验（两次机会：第二次 JS focus 兜底）
$fillOk = $false
for ($attempt = 1; $attempt -le 2 -and -not $fillOk; $attempt++) {
  if ($attempt -gt 1) {
    $r = Eval $ws $id "var t=document.querySelector('input#id-term')||document.querySelector('input[name=term]'); if(t){t.focus(); t.value='';} 'focused'"; $id++
    Start-Sleep -Milliseconds 400
  }
  $id = Type-Text $ws $id $Query
  Start-Sleep -Milliseconds 600
  $r = Eval $ws $id "((document.querySelector('input#id-term')||document.querySelector('input[name=term]')||{}).value||'').length"; $id++
  Write-Output ("FILL-LEN: $($r.result.result.value) (期望 $($Query.Length))")
  if ([int]($r.result.result.value) -eq $Query.Length) { $fillOk = $true }
}
if (-not $fillOk) { throw 'PubMed 检索式键入失败（两次尝试）' }

# 提交：点按钮，8s 无结果补发 Enter
$r = Eval $ws $id @'
(function(){
  const btn = document.querySelector('button.search-btn');
  if (!btn) return '{}';
  const r = btn.getBoundingClientRect();
  return JSON.stringify({x: Math.round(r.x + r.width/2), y: Math.round(r.y + r.height/2)});
})()
'@
$id++
$bpos = (($r.result.result.value) | ConvertFrom-Json)
if ($bpos.x) { Click-At $ws $id $bpos.x $bpos.y; $id += 3 }
Start-Sleep -Seconds 4

$hit = ''; $enterSent = $false
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $WaitS) {
  Start-Sleep -Seconds 2
  if ($sw.Elapsed.TotalSeconds -gt 8 -and -not $enterSent -and $hit -eq '') {
    $enterSent = $true
    $id = Send-Enter $ws $id
    Write-Output '补发 Enter'
  }
  $r = Eval $ws $id @'
(function(){
  const v = document.querySelector('.results-amount .value');
  if (v) return v.innerText.trim();
  if ((document.body.innerText||'').includes('No results were found')) return '0';
  const m = (document.body.innerText||'').match(/([\d,]+)\s+results/);
  return m ? m[1] : '';
})()
'@
  $id++
  $v = "$($r.result.result.value)"
  if ($v -match '^[\d,]+$') { $hit = $v; break }
}
Write-Output ("HIT: " + $(if ($hit) { $hit } else { '(未捕获到数字)' }))
$r = Eval $ws $id "location.href.substring(0,120)"; $id++
Write-Output ("STATE: $($r.result.result.value)")
Start-Sleep -Seconds 2
Capture-Screen $ws $id $Out; $id++
try { $ws.Dispose() } catch {}
Close-CdpTab $tab.id
