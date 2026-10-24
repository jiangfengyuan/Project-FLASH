# Flash 一闪 · 三端原生路线图

更新日期：2026-10-05。当前版本 Flash Aero v0.1.0（Alpha）；首个正式版目标名称 Flash Pulse v1.0.0。本文记录现状和验收门槛，不承诺发布日期。

## 当前基线

| 平台 | 实现 | 当前边界 |
| --- | --- | --- |
| Android | Kotlin / Compose / Room，Material 与玻璃双风格 | Debug 可构建；正式签名与设备品质验收待收口 |
| macOS | SwiftUI / SwiftData，全局热键 Quick Capture、菜单栏伴侣、桌面小组件骨架，universal2 | 本机可运行；小组件数据联通与对外分发待 Developer ID 签名 + 公证 |
| iOS | SwiftUI / SwiftData，iPhone、iOS 18+，与 macOS 共用 FlashKit；快速记录、灵感提醒、主屏/锁屏小组件、控制中心控件 | 模拟器可运行；真机小组件数据与分发待团队签名；设备品质矩阵未开始 |
| HarmonyOS | ArkTS / ArkUI / 加密 RDB | 主机测试与未签名 HAP 构建通过；真机、签名和受限能力准入待完成 |

已实现：此刻、记录、回顾、Memory、设置五个一级入口；日志/灵感搜索与编辑；七级情绪与可选强度；日历任务与提醒、灵感转任务（保留来源关联）；收藏与已收藏筛选；⌘K 全局搜索浮层；记录日期编辑和保存失败保护；四种回顾窗口、每日活跃度、情绪分布和趋势洞察；Memory 周报（规则聚合）；JSON 备份、差异预览、合并/覆盖及 LAN 直传。

备份采用 `flash-backup-v2`（分区 schema 2：收藏/情绪强度/任务来源关联，macOS 先行读写，Android/HarmonyOS 跟进前显式拒绝 schema 2 文件）；标准入口严格校验；v1/损坏备份走独立恢复入口。LAN v1.1 使用六位 PIN、挑战应答和完整性校验，未提供端到端加密。自动测试通过不等于跨设备互操作通过。

UI/UX 三阶段主体实现已完成，完整设备品质验收仍在进行。实际结果见 [设备品质矩阵](docs/quality/device-matrix.md)，跨端传输见 [契约验收](docs/contracts/acceptance.md)。

## 下一阶段：发布候选验收

| 优先级 | 工作 | 完成标准 |
| --- | --- | --- |
| P0 | Android / macOS 品质矩阵与缺陷修复 | 双风格、深浅色、大字体、窄/宽窗口；键盘与读屏闭环有记录和证据 |
| P0 | Android ↔ macOS 文件与 LAN 双向互传 | 合并、覆盖、失败回滚、提醒恢复、时区、取消/超时/错误 PIN 全部通过 |
| P0 | HarmonyOS 真机补验 | 取得设备后验证 ArkUI、原生 RDB、读屏、响应式和三端互传；缺设备时保留未验收 |
| P0 | 签名与分发 | Android 使用仓库外新密钥；macOS Developer ID + 公证；HarmonyOS 证书和签名。逐端核验安装与升级 |
| P1 | 发布资料与版本 | README、协议、验收、官网中英文、发布说明与产物一致；记录 commit、构建时间、SHA-256 和签名状态 |

LAN v1.1 与历史明文 PIN 首包不兼容；两端需使用同代构建。迁移旧包优先导出 JSON，在新应用恢复入口预览后导入，确认数据完整再卸载旧包。历史 APK/ZIP 不代表当前代码，不能作为新版本继续分发。

## 验收之后

1. ~~先建立 1k / 10k / 100k 数据规模下的查询、搜索、内存和主线程阻塞基线，再按证据优化索引与日期窗口查询~~（macOS 已完成首轮：10k 合成数据微基准 + signpost 观测设施 + 视图层 revision 驱动优化，见 macOS README 性能基线；100k 与 Android/HarmonyOS 基线待补）。
2. 固化记录→编辑→回顾→备份恢复等核心设备回归路径；补 HarmonyOS 原生 RDB 与设备测试，主机替身不能替代设备验收。
3. ~~改善 HarmonyOS 减弱动效降级机制~~（已完成：系统无公开查询接口，自建应用内 `reduceMotion` 开关并持久化，全站动画经 `motionDuration` 归零，情绪保存动效同样尊重该开关）。
4. 根据实际反馈选择小步功能：~~全局快捷键、收藏、桌面小组件~~（macOS 已落地：⇧⌘Space Quick Capture 可改键、三分区收藏、WidgetKit 骨架待签名联通）；候选保留更细搜索、记录提醒。HarmonyOS 已落地未读灵感提醒（本地已读状态不进备份，今日概览提示行与记录入口未读角标，对齐 Android）。

原生 iOS（`ios/`，iPhone、iOS 18）功能已对齐 macOS 并完成 iOS 增强（2026-10-24，见 [iOS README](ios/README.md)）；macOS/iOS 共用 `shared/FlashKit`。iOS 的设备品质验收、签名与分发尚未开始，暂不列入当前发布门槛。灵感提醒推送（PRD v3 §6.3）目前只有 iOS 实现，Android / HarmonyOS 仍只有页面内提示。图片附件、iCloud/WebDAV 和自动同步仍是候选。自动同步需要独立 `flash-sync-v1` 设计，不改变快照备份语义。

## 工程原则

- 本地优先，无 Flash 账号或服务端；用户可主动导出和迁移。
- 跨端数据变更以 `docs/contracts/` 为准，先通过共用样例再做设备互操作。
- 构建、单测、模拟器检查、真机检查分别记录，未执行项不标记通过。
- 发布前运行三个原生工程的检查及备份契约测试；具体命令见各平台 README。
- 所有工作区改动写入根目录 CHANGELOG；旧 Web / React / Capacitor 阶段已退役，仅保留在 Git 历史中，不再作为现役任务。
