---
name: research-evidence-pipeline
description: |
  Research proposal evidence pipeline ("导备查"): from a research direction to a proposal PPT with a complete evidence chain. Ten stages: search-term design → tri-database search (CNKI/PubMed/WoS) with mandatory screen recording → CSV export → dedup → inclusion/exclusion criteria → rule-replay screening → full-text acquisition (EZproxy download lists) → close reading → final selection → project folder + proposal PPT (videos embedded).
  Invoke when: user gives a research direction and wants the full proposal-evidence pipeline; wants search-process screen recordings as proof; wants clickable institutional download lists; wants screening redone and auditable.
license: MIT
metadata:
  hermes:
    tags: [research-pipeline, evidence, screen-recording, cnki, pubmed, web-of-science, ezproxy, screening, prisma, ppt]
    related_skills: [nature-literature-pipeline, nature-downloader, zotero]
  compatibility: "Windows; Chrome --remote-debugging-port=9222; institutional EZproxy session (QR login); Python 3.10+ with pymupdf/python-pptx/openpyxl/websocket-client/imageio-ffmpeg; PowerShell 5.1"
---

# 导备查 · 立项证据流水线（Research Evidence Pipeline）

从一个研究方向出发，十阶段流水线产出**带完整证据链的立项材料**：三库检索全程录屏留证、导出原件为唯一口径、纳排规则即代码可重放、全文下载有台账、精读终筛可回核、最终生成标准项目文件夹与内嵌检索录屏的立项 PPT。

## 何时使用

- 用户给出一个研究方向，要求走完整立项调研流程（检索→筛选→精读→PPT）；
- 导师要求证明"检索真实执行过"，需要检索过程录屏 + 命中数对照；
- 需要把付费文献整理成机构代理可点击下载清单；
- 纳排结果被质疑，需要规则重放、逐条审计、重新留证。

## What It Does

```
研究方向（一句话）
  │
  ├─ ① SEARCH DESIGN      概念分解 → 三库语法草拟 → 语法预检（0 命中即弃用改写）
  │       产出：检索式记录表                      ✋ 人工：确认检索式
  ├─ ② TRI-DB SEARCH      🔴 全程录屏：逐字符真实键入 → 真实点击 → 命中数 + STATE 留痕
  │       会话预检（EZproxy 过期 → 用户扫码 → 复检通过才开工）
  ├─ ③ EXPORT CSV         🔴 Agent 执行的导出操作 → 录屏；人工导出不适用
  │       产出：三库导出原件（.enw/.txt/CSV = 唯一口径）
  ├─ ④ DEDUP              库内 + 跨库去重，只删真重复 → 去重台账
  ├─ ⑤ I/E CRITERIA       书面化纳排标准（排除码 + 诱骗词剥离）→ 冻结为配置
  │                                       ✋ 人工：确认标准并冻结
  ├─ ⑥ SCREENING          规则即代码脚本重放 + 人工 rescue 逐条留痕 + 单人筛选声明
  │       产出：纳排总表 + 核心严筛表 + 差异审计
  ├─ ⑦ FULL-TEXT GET      🔴 OA fetch / 出版商页面 / EZproxy 通道 → 录屏
  │       下载清单（OA/订阅/中文分类）+ 台账 + 磁盘复核
  │                                       ✋ 人工：无法获取全文的排除须确认
  ├─ ⑧ CLOSE READING      精读表建档（标题/来源/日期/摘要/方法/创新/纳入理由）分类输出
  ├─ ⑨ FINAL I/E          终筛 + 确定性匹配回核（构成 = 池内 N1 + 其他来源 N2 + 漏网 0）
  │       产出：终筛表 + 二次淘汰表               ✋ 人工：终筛确认
  └─ ⑩ FOLDER + PPT       标准项目文件夹骨架（01-07 + _归档）+ 整理清单
          → 立项 PPT（证据三层：留档口径 + 静态截图 + 录屏内嵌视频）
```

## Quick Start

```
模式 A（只要下载清单）：
把文献列表整理成澳科大可点击下载清单，列表在 XX.xlsx，输出到桌面

模式 B（只要检索取证）：
给这 6 条检索式留取证录屏，检索式表在 01_检索记录表.xlsx，嵌入 PPT 第 3-5 页

全流程：
我的研究方向是「X 真伪鉴别」，检索截止 YYYY-MM-DD，
按十阶段流水线走：三库检索全程录屏，最终生成项目文件夹和立项 PPT。
```

Agent 逐阶段推进，每阶段末尾汇报**阶段性成果 + 下一步**；全程 5 个人工决策点（✋）：确认检索式、确认纳排标准、确认全文排除、确认终筛、扫码授权。其余全自动。

## Architecture

| Layer | Purpose | Files |
|-------|---------|-------|
| **Engine**（规则层，按需加载） | CDP 驱动手册、录制手册、证据规范、阶段细则 | `references/cdp-drivers.md`、`references/recording.md`、`references/evidence-pack.md`、`references/pipeline-stages.md` |
| **Application**（脚本层） | CDP 公共库、三库驱动、双轨录制、清单生成、PPT 装配 | `scripts/`（cdp_lib.ps1、search_cnki.ps1、search_pubmed.ps1、search_wos.ps1、rec_desktop.ps1、rec_tab.py、make_manifest.py、ppt_embed.py） |
| **Templates** | 机构配置模板、检索式记录表模板 | `templates/` |

**按需加载**：进入某阶段前只读对应 reference 文件，不要预载全包。

## Configuration

所有机构相关内容集中在 `templates/institution-config-template.md`，换机构只改这一个文件：

- EZproxy 前缀、CAS 统一认证门户、登录方式（默认澳科大：WeMust 扫码）
- 三库入口 URL 与驱动类型、CDP 调试端口（默认 9222）
- 录制参数（fps、单条时长、证据输出目录）

## Built-in Safeguards

1. **网页 Agent 留证规则（铁律）**：任何 Agent 在网页上执行的操作（检索、导出、下载、翻页、fetch），必须"先启录制器、后执行操作"。没有对应录屏的在线操作视为未执行。人机验证与登录等待如实保留在录像中（本身即证据）。
2. **留档唯一口径**：数据库官网计数天然漂移。命中数以检索日留档（记录表/导出原件）为唯一依据；录屏与当日实况仅作过程证据，manifest 中逐条如实标注差异，**录屏画面/题注不充当数字来源**。
3. **规则即代码**：纳排标准冻结为脚本（词表 + 逻辑 + 排除码），重放即验证；人工 rescue 逐条留痕；单人筛选必须如实声明。
4. **字段语法预检**：检索式先用 API/变体试测（如 PubMed 已弃用 `[TA]`，实测返回 0；用全称 `[Title/Abstract]`），0 命中的语法不得进入正式检索。
5. **会话自愈环**：EZproxy 探针检测到跳登录页 → 停下请用户扫码 → 复检通过才继续，绝不带过期会话硬跑。
6. **只删真重复**：去重仅删确实重复的书目记录，疑则保留；无法获取全文的排除必须经用户确认。
7. **磁盘复核**：下载台账必须与磁盘实际文件一致才可报数。

## Related Skills

- `nature-downloader` — 自动化下载（互补：它做 API/OA 自动获取，本 skill 做手动清单 + 取证）
- `nature-literature-pipeline` — 每日文献推送流水线（骨架参考）
- `zotero` — 终筛文献入库管理

## References

| Reference | Purpose |
|-----------|---------|
| `references/pipeline-stages.md` | 十阶段细则：每阶段输入/动作/输出/留痕/人工点 |
| `references/cdp-drivers.md` | CNKI/PubMed/WoS 三库驱动差异与验证规则 |
| `references/recording.md` | 双轨录制手册（screencast/gdigrab）+ 完整坑清单 |
| `references/evidence-pack.md` | 三层证据体系、manifest 规范、PPT 内嵌规范、文件夹骨架 |

## Pitfalls

1. **含空格路径必须加引号**：Start-Process 的 ArgumentList 不自动加引号（ffmpeg 与 python 脚本各栽过一次）。
2. **here-string 不可嵌套**：PowerShell 内层 JS 一律抽独立文件读取。
3. **CDP screencast 必须 `suppress_origin=True`**：否则 Chrome 403 拒绝 WebSocket。
4. **gdigrab 强杀毁 mp4**：等自然退出（45s 宽限），首帧延迟是常态。
5. **熄屏导致 gdigrab 无帧**：长批录制前开 `SetThreadExecutionState` 唤醒线程。
6. **残留标签页先清理**：录制器按域名 attach，残留旧标签会 attach 错对象采到 0 帧。
7. **python-pptx 坐标全程 EMU**：复用原形状坐标时不要再包 `Inches()`（×914400 会生成天文数字坐标，PowerPoint 拒开而 python-pptx 仍可读）。
8. **OneDrive 脱水 pptx**：编辑走 TEMP 副本，写回前杀 POWERPNT 进程。
