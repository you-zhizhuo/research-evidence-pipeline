# CDP 三库驱动手册

公共库 `scripts/cdp_lib.ps1` 提供：`Invoke-Cdp`（HTTP /json 操作）、`New-CdpTab`、`Close-CdpTab`、`Send-Cdp`、`Wait-Resp`、`Recv-All`、`Eval`、`Click-At`、`Type-Text`。三库驱动脚本全部 dot-source 它。

**通用纪律**：
- 铁律：先启录制器（`rec_tab.py`，按域名 attach）再执行任何网页操作。
- 所有等待用轮询而非固定 sleep 兜底；命中数捕获失败要输出 STATE（URL+标题+正文片段）便于诊断。
- 键入用 CDP `Input.dispatchKeyEvent`（keyDown 带 text / keyUp），一个字符一对事件；点击用 `Input.dispatchMouseEvent`（moved→pressed→released，坐标取元素中心）。
- 引用块内 JS 较长时抽独立 `.js` 文件读取（here-string 不可嵌套）。

## CNKI（知网）

- 入口：高级检索 `https://kns.cnki.net/kns8s/AdvSearch` → 切到「专业检索」。
- 语法：`SU=` 主题字段（无引号；`+` 或、`*` 与）。示例：`SU=(八角+八角茴香+大茴香)*(鉴别+鉴定+检测)`。
- 要点：
  - 检索框定位后**逐字符键入**（约 0.1-0.2s/字符），键入完校验 `value.length` 与期望一致再点「检索」。
  - 命中数选择器以结果页为准（`.result-table-list` 出现即结果页）；STATE 抓取页面文本兜底。
  - **人机验证（拖动拼图）**：脚本等待（上限 240s），由人工在窗口内完成——如实留在录屏中。
  - 反爬强：批量导出须人工机构登录，单次约 500 条上限，超出分批。

## PubMed

- 入口：`https://pubmed.ncbi.nlm.nih.gov/`。
- 语法：字段**全称** `[Title/Abstract]`。**`[TA]` 已被 PubMed 弃用（2026-10 实测返回 0）**；同理对任何缩写字段先做 API 预检：`https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&retmode=json&term=...`。
- 要点：
  - 等 `input#id-term` 出现（最多 15s）→ 点击 → 全选清空 → 逐字符键入 → **校验 value 长度**；若为 0 用 JS `el.focus()` 兜底后重打一轮（共两次机会）。
  - 提交：点击 `button.search-btn`；8s 后无结果数则补发一次 Enter。
  - 命中数：`.results-amount .value`；正文兜底正则 `/([\d,]+)\s+results/`；出现 `No results were found` 时如实记录 0 并触发语法预检复查。

## Web of Science（经机构 EZproxy）

- 入口：`https://{EZPROXY_PREFIX}/wos/woscc/advanced-search`（须先有有效会话）。
- 会话预检：列出 `/json/list` 找 `*webofscience*` 标签；URL 落在 `login.must.edu.mo`（或换成贵校 CAS 域）即会话过期 → 停下请用户扫码 → 复检。
- 语法：`TS=` 主题，通配 `*` 可用。示例：`TS=("Illicium verum" OR "star anise") AND TS=(identification OR authentication)`。
- 要点：
  - 页面是 Angular 单页应用：按钮点击用 `Runtime.evaluate` 里的 JS click（合成鼠标事件常不触发）。
  - 全量导出必须人工：新开活动标签页 + 选「Records 1–N」，页面默认「All records on page」会截断；导出数与页面命中数可能差 1 条，如实记录。
  - EZproxy 会话有时效（数小时级），长任务中途过期属正常，走会话自愈环。
