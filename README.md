# research-evidence-pipeline（导备查 · 立项证据流水线）

从一个研究方向出发，十阶段流水线产出**带完整证据链的立项材料**。

## 这是什么

面向"导师会问：检索真的执行过吗？数字从哪来？"的场景，把立项调研固化为一套**可重放、可审计、可演示**的流水线：

1. **检索式设计** — 概念分解、三库语法、0 命中预检（自动弃用过时语法）
2. **三库检索 + 全程录屏** — CNKI/PubMed/WoS 逐字符真实键入，标签页/桌面双轨录像
3. **导出与去重** — 导出原件为唯一口径，确定性匹配去重
4. **纳排筛选** — 规则即代码，重放即验证，人工 rescue 逐条留痕
5. **全文获取** — OA/订阅/中文分类清单 + EZproxy 机构代理 + 台账磁盘复核
6. **精读与终筛** — 精读表建档、终筛构成回核（漏网 = 0）
7. **文件夹 + 立项 PPT** — 标准骨架 + 三层证据（留档/截图/内嵌录屏视频）的 PPT

## 目录

```
├── SKILL.md              # skill 主文件（十阶段流程 + 铁律 + 坑清单）
├── references/           # 规则层：阶段细则 / CDP 驱动手册 / 录制手册 / 证据装配规范
├── scripts/              # 脚本层：CDP 公共库 + 三库驱动 + 双轨录制 + manifest + PPT 内嵌
└── templates/            # 机构配置模板 + 检索式记录表模板
```

## 快速开始

### 安装（他人使用）

```bash
# 1. 克隆到本机 skill 目录（TRAE/Codex）
git clone https://github.com/you-zhizhuo/research-evidence-pipeline.git
#    → 复制到 ~/.trae-cn/skills/research-evidence-pipeline/（Windows: C:\Users\<你>\.trae-cn\skills\）
#    重启会话后 skill 自动可用

# 2. 安装 Python 依赖
pip install -r requirements.txt

# 3. 启动带调试端口的 Chrome 并登录你的机构门户
chrome.exe --remote-debugging-port=9222
#    （在浏览器内完成机构登录，如 WeMust 扫码 / 校园账号）

# 4. 复制 templates/institution-config-template.md 填入贵校参数（换机构只改这里）
```

### 使用

1. Chrome 以 `--remote-debugging-port=9222` 启动，并在浏览器内完成机构登录（如 MUST WeMust 扫码）。
2. 复制 `templates/institution-config-template.md` 填入贵校参数。
3. 对 Agent 说：
   - 全流程：`我的研究方向是「X」，按十阶段流水线走：三库检索全程录屏，最终生成项目文件夹和立项 PPT。`
   - 只要取证：`给这些检索式留取证录屏，嵌入 PPT 第 3-5 页。`
   - 只要清单：`把文献列表整理成可点击下载清单。`

## 实跑背书

本流水线的每个阶段都在一次完整的立项调研中实跑验证：CNKI 六式（S001 精确复现 528 条命中）、PubMed 三式、WoS 两式（76/273 与留档精确一致）共 11 段录屏；245 篇 PDF 台账与磁盘一致；终筛 118 篇构成回核漏网 0；11 段视频全部内嵌 29 页 PPT。

## License

MIT
