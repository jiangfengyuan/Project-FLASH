# Flash 一闪 · 四端原生路线图

2026-11-21（香港）复核。近期里程碑是 **Android 手机 + Mac 受控测试候选**。Flash Paper 1.0 Alpha 1 已统一四端版本，完整 Alpha 验收仍未通过。正式版名为 Flash Paper 1.0.0，发布日期待定。[版本规则](docs/release/versioning.md) · [Alpha 验收](docs/acceptance/paper-alpha1-20261114.md)

## 候选来源

11/15 已将 Paper、备份修复、新引导与辅助功能、Standard Icon、标准草案和生产开关关闭的 LAN v2 合到 main@9330a62。Mac 弹层遮挡及移动端锁定快速记录已有修复和回归。Apple CI 步骤已包含 FlashKit 测试、macOS App 测试及 iOS 模拟器编译。[整合记录](docs/integration/unified-main-20261115.md) · [CI 定义](.github/workflows/backup-contract.yml)

11/21 已合入 #7 并将本地与 GitHub main 对齐到 43d22f9。push 的四项检查全绿，旧 PR #3 的内容已入主线并已关闭。本轮候选新增 Android v4 持久化、两端 v2 正文导出，并修复 Aero Beta1 旧库迁移。候选的验证层级和后续真机事项见 [恢复验收](docs/contracts/acceptance.md)。[整合后 CI](https://github.com/jiangfengyuan/Project-FLASH/actions/runs/44916802432)

## 工程任务与验收顺序

| 复核窗口 | 工作 | 完成标准 |
| --- | --- | --- |
| P0 · 11/21–23 起 | 已合入 #7 并恢复主线 CI。双端候选按最终源码重建，记录测试包及签名条件。 | 候选 SHA 的远端检查全绿，干净检出可重建两个包，保留命令、工具链和摘要。 |
| P0 · 并行启动 | Android 和 Mac 默认读写 v4，支持主动选择 v2 正文兼容导出；HarmonyOS 继续使用 v1/v2。 | 用实际 App 双向、同端验证明文和加密恢复。按约定核对合并/覆盖后的字段与提醒，覆盖错误口令、损坏、取消、回滚和重启。完整备份保留标签和回收站。[v4 契约](docs/contracts/flash-backup-v4.md) · [验收矩阵](docs/contracts/acceptance.md) |
| P0 · 并行启动 | 已识别并修复 Beta1 两实体库回退内存；Beta1／Beta2 来源可追溯的合成库已完成升级重开。另排隔离签名环境原位安装验证。 | 用已知版本生成的测试库验证升级前后记录、新写入及重启持久性，记录失败重试时原库和 WAL 的保全情况。[验收线索](docs/acceptance/paper-alpha1-20261114.md) |
| P1 · 11/24–30 | Android 手机和 Mac 跑通记录、编辑、搜索、回顾、任务提醒与应用锁。 | 锁屏/睡眠、认证取消、已有弹层、只写快速记录及路由按平台设计工作。补齐当前 Paper 的读屏、键盘、大字号、Android RTL 与新增引导文案证据。[品质矩阵](docs/quality/device-matrix.md) |
| P1 · 12/01–07 | 前项通过后交付受控包并收集首轮反馈。 | 包、源码 SHA、SHA-256、实际安装/升级/恢复和限制均可追溯。公开分发另核 Android release 密钥及 Mac Developer ID/公证。 |

以上是复核窗口，阻塞未关闭时顺延。每条结果记录候选 SHA、设备与系统、构建摘要、语言/字号、操作、结果和证据。使用独立安装及虚构数据。

iOS/HarmonyOS 继续编译和自动回归，签名与设备就绪后补认证、通知、扩展/服务卡片及原生存储。LAN v2 另验最低系统、后台与锁屏、权限、大文件以及四端双向互通，生产开关保持关闭。管理控制台单列部署和云端验证。下一项功能扩展由双端试用反馈决定。
