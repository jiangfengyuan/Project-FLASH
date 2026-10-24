# Flash Aero · macOS

桌面端原生实现。SwiftUI + SwiftData，零第三方依赖，在 App Sandbox 内运行。

当前发布身份为 **Flash Aero v0.1.0**；`Aero` 为 v0 Alpha 阶段的版本代号。
首个正式版将统一命名为 **Flash Pulse v1.0.0**。

- Bundle ID：`com.flash.app.macos`
- 部署目标：macOS 15.0
- 架构：universal2（arm64 + x86_64）

## 功能

| 模块 | 说明 |
| --- | --- |
| 此刻（一级） | 当日概览、快速记录、最近动态、情绪快照、本周洞察、醒目的全宽搜索入口 |
| 记录（一级） | 关键词/标签搜索、日志 + 灵感筛选、已收藏筛选、底部快速输入；灵感可「转为任务」并保留来源关联 |
| 日志流（次级） | 搜索、标签 / 日期 / 收藏筛选、排序、编辑、删除 |
| 情绪（次级） | 七级滑块 + 可选强度（1–5）+ 子情绪 + 备注，周趋势，近期记录 |
| 日历（次级） | 日志与情绪按日聚合的月历；任务支持截止时间、完成状态、本地提醒与来源灵感回链 |
| 回顾（一级） | 四种时间窗口、活跃度、趋势洞察、情绪分布与页内日历 |
| Memory（一级） | 周报：四类计数、本周情绪基调、收藏优先的 Highlights、周导航（PRD §22 规则聚合版） |
| 全局搜索 | ⌘K 唤起浮层，跨日志/灵感/情绪/任务搜索，↑↓ 选择、Enter 跳转定位、Esc 关闭 |
| 收藏 | 日志/灵感/情绪/任务星标；记录页与日志流「已收藏」筛选；周报 Highlights 优先取收藏 |
| 设置（一级） | 主题、Quick Capture 快捷键（录制改键/恢复默认）、备份导入导出、系统分享、PIN 配对局域网直传、清空数据 |
| 菜单栏伴侣 | MenuBarExtra：快速记录（回车即存）、今日概览、一键跳转主窗口 |
| 桌面小组件 | WidgetKit（small/medium）：✦ Flash、今日记录数、今日待办数、主导情绪 emoji，点击经 `flash://today` 回到此刻页；数据走 App Group 快照（见「安全与已知限制」） |
| Quick Capture 面板 | 全局热键（默认 ⇧⌘Space，Carbon RegisterEventHotKey，沙盒可用）唤起浮动面板；Enter/⌘Enter 保存即关、Esc 放弃、未提交保留草稿；主窗口关闭后 App 驻留菜单栏，热键保持可用 |

快捷键：⇧⌘Space 全局 Quick Capture（可自定义）、⌘N 新建、⌘K 全局搜索、⌘, 设置、⇧⌘E 导出备份、⌘1…⌘7 切换模块（1 此刻 2 记录 3 日志流 4 日历 5 情绪 6 回顾 7 Memory）。

动效统一走 `FlashDesign/Theme/FlashMotion.swift`（Soft / Fast / Playful），
全量尊重系统「减弱动态效果」。

## 架构

模型、SwiftData 实体与仓储、备份/LAN、领域纯函数、设计令牌与共用组件位于与 iOS 共用的
本地 Swift Package [`../shared/FlashKit`](../shared/FlashKit)（`FlashCore` / `FlashDesign`，2026-10-18 迁入）；
本工程只保留 macOS 专属部分（窗口与菜单命令、菜单栏伴侣、全局热键 Quick Capture、各页面视图、桌面小组件）。

读路径：视图经 SwiftData `@Query` 直读；聚合 / 统计 / 搜索等纯逻辑下沉到
`FlashCore/Domain/` 的纯函数（与 Android 端算法口径一一对应，可直接单测）。
写路径：统一经 `FlashRepository`，装配入口只有一个
（`RepositoryEnvironment.makeDefault()`，含持久化失败时的内存降级与启动告警）。

本地单机应用的读路径不叠仓库抽象，是有意的取舍，不是技术债。

## 构建

```bash
cd macos

# Debug（日常开发，只编本机架构）
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -scheme Flash -destination 'platform=macOS' build

# Release universal2（对外分发产物，注意目标是 generic 平台）
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -scheme Flash -destination 'generic/platform=macOS' \
  -configuration Release build
```

`DEVELOPER_DIR` 前缀仅在 `xcode-select` 指向 CommandLineTools 或需要用
Xcode beta 时才加。'platform=macOS'（My Mac）目标即使 Release 也只编本机架构，
要双架构必须用 'generic/platform=macOS'（或 Archive）。

产物签名是 adhoc，仅限本机运行；对外分发需要 Developer ID 签名 + 公证。

## 测试

```bash
cd macos
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild test -scheme Flash -destination 'platform=macOS'
```

App 测试覆盖 AppState 与 KeyChord（含 NSEvent 录制）；模型 / Repository / 备份 / LAN /
SettingsStore / Domain 纯函数 / 主题色 / Schema 迁移 / Quick Capture 草稿与保存规则 /
HomeViewModel / WeeklyMemory / WidgetSnapshot / 任务提醒等共享逻辑的测试随代码迁入
FlashKit，用 `cd ../shared/FlashKit && swift test` 运行。测试数量以当次执行汇总为准。

## 备份格式

与 Android/HarmonyOS 互通的 `flash-backup-v2` JSON（同时兼容导入 v1）：

```json
{ "version": "flash-backup-v2", "exportedAt": "...", "appVersion": "...",
  "schemas": { "logs": 2, "emotions": 2, "tasks": 2 },
  "data": { "logs": [...], "emotions": [...], "tasks": [...] } }
```

- 分区 schema 2（2026-10-05 起）：新增可选字段——三分区 `isFavorite`、情绪 `intensity`（1–5）、任务 `sourceLogId`（灵感转任务的来源关联）。macOS 导出写 2、读取接受 1 与 2；Android/HarmonyOS 跟进前会显式拒绝 schema 2 文件（不静默丢弃），详见 `app/docs/contracts/README.md`。
- 标准入口严格校验 v2，任何非法条目整体拒绝；独立恢复入口用于 v1 或旧/损坏备份，逐条跳过可恢复范围内的非法记录。未知版本/分区拒绝导入；单文件上限 50 MB。
- 读写走 App Sandbox 的用户择定文件授权，导出文件权限 0600。
- 「通过系统分享」会创建沙箱缓存副本并调用系统分享服务，可选择 AirDrop、
  信息、邮件或云盘；Flash 不会自行上传文件。
- 「局域网发送 / 接收」通过 Bonjour 自动发现 Android 或 macOS 设备。发送方生成
  随机六位 PIN，PIN 60 秒失效、最多尝试五次；正确配对并完成一次传输后监听立即
  关闭。接收后会分析新增、修改、相同与仅本机数据，再选择差异合并或覆盖。仅启用
  App Sandbox 的客户端 / 服务端网络能力，数据不经过 Flash 服务器；
  建议只在可信的家庭或办公局域网使用。

## 性能基线

### 观测设施（2026-10-05 起）

- `FlashCore/Data/Perf.swift`：OSSignposter 封装（subsystem 取宿主 Bundle ID，macOS 为 `com.flash.app.macos`），
  插桩点 `StartupAssembly` / `TasksForReminderRebuild` / `StatsAggregate` /
  `CalendarAggregate` / `HomeDerive`，Instruments 的 Points of Interest 模板按名过滤。
  （2026-10-05 性能优化：`SnapshotForReminderRebuild` 随 snapshot()→tasksOnly() 改名。）
- `FlashCore/Data/DebugSeeder.swift`（仅 DEBUG）：`FLASH_SEED_SYNTHETIC=10000` 启动时向空库
  灌注确定性合成数据（1 万日志 / 5 千情绪 / 2 千任务，LCG 种子固定，多次运行数据集一致）。
- `FlashKit/Tests/FlashCoreTests/PerfBaselineTests.swift`：聚合/搜索管线微基准，结果写
  `/tmp/flash-perf-baseline.txt`；断言为宽松上限，只拦截病态回归。

### 微基准（Debug 构建，M3 Pro，2026-10-05）

| 管线（10k 日志 / 5k 情绪 / 2k 任务） | 优化前 | 优化后 |
| --- | --- | --- |
| `aggregateDay`（日历日聚合） | 11.0 ms | 10.7 ms |
| `LogFilter.apply(query)` | 15.1 ms | 14.9 ms |
| Stats 管线（日均值+子情绪+活跃度+洞察，90 天窗） | 18.4 ms | 17.5 ms |
| `GlobalSearch` | 39.4 ms | 38.7 ms |

优化后单次耗时持平属预期：本轮优化的是视图层调用频次（按键/hover/页面状态翻转
不再触发全表映射与聚合），领域函数本身未改。收益体现在交互期 CPU 占用而非微基准。

### 实测基线（Release）

2026-10-06（M3 Pro / 36 GB，Release universal2，含 FlashWidget.appex）：包体 16 MB（`.app` 整体，`du -sh`；增量来自小组件、Quick Capture、Memory 等新功能与令牌资源）。

2026-08-14 实测（M3 Pro / 36 GB，Release universal2，热缓存）：

| 指标 | 实测 | 方法 |
| --- | --- | --- |
| 包体 | 4.3 MB（.app 整体） | `du -sh` |
| 冷启动 | 中位 0.084 s（3 次粗测） | `open -n` 到进程检出，非首帧时间 |
| 空闲内存 | RSS 129.9 MB | 静置 30 s 后 `ps -o rss=` |

冷启动是进程出现时间的下界近似；帧率未做 Instruments 定量测量，
长列表均为 Lazy 容器。

## 安全与已知限制

- 静态加密依赖系统 FileVault；未开 FileVault 的机器上数据库明文落盘。
- adhoc 签名未公证，仅限本机使用。
- **桌面小组件数据联通依赖 App Group，需 Developer ID 签名版本。** `com.apple.security.application-groups` 使用未注册组 ID 时进程启动即被 secinit 杀死，因此主 App 与 `FlashWidget` target 均不声明 App Group entitlement；当前 adhoc 构建中快照写入静默跳过，小组件恒显示「打开 Flash 开始记录今天」引导态。代码已按 App Group 协议（`widget-snapshot.json`）完整实现，签出 Developer ID 版本时只需为两个 target 加组 entitlement 即联通。
- universal2 的 x86_64 切片只在 Apple Silicon 上交叉编译验证过，未做 Intel 实机测试。
- iCloud 同步是后续候选，不在本版本。原生 iOS 版开发中（`../ios/`，与本工程共用 FlashKit）。

## 验收与发布状态（2026-09-26）

设备品质结果与未验项目见 [品质矩阵](../docs/quality/device-matrix.md)，跨端互传状态见 [契约验收](../docs/contracts/acceptance.md)。局域网使用 [握手 v1.1](../docs/contracts/lan-handshake-v1.1.md)：六位 PIN、挑战应答与 payload HMAC；内容未做端到端加密。历史明文 PIN 首包不兼容，双方需使用同代构建，旧数据经 JSON 文件迁移。
