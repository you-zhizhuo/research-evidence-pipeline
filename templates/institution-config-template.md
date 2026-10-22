# 机构配置模板（换机构只改本文件）

复制本模板为 `institution-config.md`（或直接改默认值），A/B 两模式共用。

| 参数 | 默认值（澳科大 MUST 示例，均为公开配置） | 说明 |
|------|------|------|
| EZproxy 前缀 | `https://libezproxy.must.edu.mo` | 机构代理，包装订阅文献链接；WoS 走 `https://www-webofscience-com.libezproxy.must.edu.mo` |
| CAS 统一认证门户 | `https://login.must.edu.mo` | 会话过期跳转至此即判定"需重新授权" |
| 登录方式 | WeMust App 扫码 / 校园门户账号 | 一次登录，A/B 共用会话 |
| 下载清单包装格式 | `https://libezproxy.must.edu.mo/login?url={目标URL}` | 仅"出版商订阅"类包装 |
| CDP 调试端口 | `9222` | Chrome `--remote-debugging-port=9222` 启动 |
| 录制输出目录 | `{项目}/05_输出文档/检索录屏` | mp4 + thumbs + manifest |
| 截图输出目录 | `{项目}/05_输出文档/evidence_screenshots` | 静态截图与证据页 |
| 三库入口 | CNKI `kns.cnki.net`；PubMed `pubmed.ncbi.nlm.nih.gov`；WoS 经 EZproxy | 驱动类型见 `references/cdp-drivers.md` |
| 录制参数 | 标签页 4fps 合成；桌面 6fps；单条时长 CNKI 130s / PubMed 90s / WoS 150s | 按检索式长度调整 |

**隐私约定**：本模板与 skill 全部文件不得包含用户名、密码、cookie、令牌。登录一律由用户在浏览器内完成。
