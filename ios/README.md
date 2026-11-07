# Flash Aero · iOS

> 2026-10-31 整合候选：已合入最新 iOS 导航、分享扩展与 Spotlight，并保留加固修复。旧 LAN 仍停用，已清理仅供其使用的网络声明；Android 的 WorkManager 依赖仍合并 ACCESS_NETWORK_STATE，未为清理 LAN 强删调度框架能力。当前仅支持文件导出/系统分享；升级本端不会修复仍运行旧版本的另一端。详见 [整合与验收](../docs/hardening/integration-20261031.md)。

2026-10-30 功能收口检查点：模拟器测试18项、FlashKit204项及通用模拟器测试构建通过；修复today/ideas深链被旧弹层遮挡，并新增文件往返/磁盘重开验证。完整界面、VoiceOver、iOS18与真机验收仍未完成，详见[执行记录与交付](../docs/hardening/ios-acceptance-20261030.md)。

> 2026-10-25 加固候选：旧版 LAN 因未认证下载/明文风险经批准暂时停用，请使用文件导出/系统分享；没有不安全回退。四端候选支持既有分区 schema1/2，原生 IANA 别名策略已统一；完整 app/真机矩阵仍未验收。见 [审查交接与限制](../docs/hardening/review-handoff.md)。签名团队未变；本轮移除旧LAN专用声明，历史构建记录仍保留。

iPhone 原生实现（Alpha）。SwiftUI + SwiftData，零第三方依赖；数据层、领域逻辑、设计语言与大部分页面
与 macOS 共用 [`shared/FlashKit`](../shared/FlashKit) 本地 Swift Package。

- Bundle ID：`com.flash.app.ios`（小组件扩展 `com.flash.app.ios.widget`）
- 部署目标：iOS 18.0（与 macOS 15.0 同代 API）；iOS 26+ 启用 Liquid Glass
- 设备：仅 iPhone（`TARGETED_DEVICE_FAMILY = 1`）；可随窗口缩放（iPhone Duo 展开内屏双栏）
- 模块名 `Flash`（与 macOS 一致，`@testable import Flash`）

## 功能（2026-10-24）

| 模块 | 说明 |
| --- | --- |
| 此刻 | 问候区、今日一览（宽窄三档自适应）、快速捕捉、最近闪念（点按编辑 / 长按收藏删除）、灵感提醒提示行；≥700pt 宽度双栏 |
| 记录 | 常显搜索栏（200ms 防抖）、全部/日志/灵感/待整理/已收藏、筛选面板（标签/重要度/日期）、新建菜单、待整理批量改分类或标签、左滑收藏 / 右滑删除、日志流入口 |
| 日志流 | 共享 `LogFlowView`：标签、收藏、排序、日期范围 |
| 情绪 | 七级滑杆 + 强度 + 子情绪 + 备注、本周趋势、近期记录（共享 `EmotionView`） |
| 日历与任务 | 月历、日详情、任务新建/编辑/完成、截止时间与本地提醒、灵感转任务与「查看灵感」回链 |
| 回顾 | 四种时间窗口、洞察、活跃度、KPI（窄屏 2×2）、情绪趋势与分布、日历分段 |
| Memory | 周报：四类计数、本周情绪、亮点、周导航 |
| 全局搜索 | 各 Tab 右上角放大镜：跨日志/灵感/情绪/任务，点结果跨 Tab 定位 |
| 设置 | 主题、灵感提醒（开关 + 每天/每 3 天/每周）、导出到「文件」、系统分享、标准/恢复导入（差异预览、合并/覆盖、覆盖前 TOCTOU 重校验）、旧LAN停用提示、清空、关于 |
| 欢迎页 | 首次启动三页横滑 |

### 快速记录（iOS 版 Quick Capture）

规则对齐 macOS PRD §13–14：默认灵感、可切日志、回车即存、保存即关（成功触感）、未提交保留草稿。入口：

- iOS 26+ 标签栏上方 Liquid Glass 常驻条「现在想记录什么？」（滚动时标签栏收起）；iOS 18–25 为右下悬浮按钮；
- 控制中心 / 锁屏 / 操作按钮：「Flash 快速记录」控件；
- 中号主屏小组件的「灵感 / 日志」按钮；
- Siri 与快捷指令：「用 Flash 记一闪」打开面板；「记一闪」动作直接写入、不打开 App；
- 深链 `flash://capture[?category=idea|log]`；
- 系统分享面板「记到 Flash」（分享扩展，见下）。

### 分享扩展与系统搜索

- **分享扩展**（`FlashShareExtension`，`com.flash.app.ios.share`）：在其他 App 的分享面板接收纯文本与一个网页链接，
  可编辑正文、选灵感（默认）或日志后保存。SwiftData 主库不在 App Group 内，扩展**不打开主库**，只把内容投递到
  App Group 收件箱；Flash 启动或回到前台时经 `CaptureInboxImporter` 按快速记录同一套规则（`QuickCaptureCommit`：
  去空白、字数上限、标签与重要度）收入，提示「已收入 N 条分享内容」。没有用 `flash://capture` 深链交接：
  分享扩展无法打开宿主 App，深链还会把正文放进 URL。
- **系统搜索**：日志与灵感写入 Core Spotlight，点结果经 `FocusRouter` 打开该记录。新增 / 编辑即写，删除即撤，
  清空与覆盖导入整体重建，启动时对账一次；「设置 › 隐私 › 在系统搜索中显示」可关闭。

### 灵感提醒（PRD v3 §6.3）

从未打开查看过的灵感累计 ≥ 3 条时：记录 Tab 角标、此刻「想法等待梳理」提示行（点按打开最早一条）、
卡片「未读」标记，以及晚上 8 点本地通知（默认开启、每天；可在设置关闭或改为每 3 天 / 每周）。
已读状态只存本机（`IdeaViewStateStore`），不进备份；首次启用以现有灵感为基线（对齐 Android）。
通知权限只在确需提醒时申请；点按通知经 `flash://ideas` 打开灵感筛选。

### 小组件与通知

- 主屏「Flash 此刻」（小 / 中）：今日记录、待办、主导情绪、待梳理想法；锁屏圆形 / 矩形 / 单行。
- 数据走 App Group `group.com.flash.app.ios` 的 `widget-snapshot.json`；App 每次写库后重载时间线，跨日自动归零。
- 任务提醒通知带「完成」「稍后 10 分钟」操作，不打开 App 直接写库并重排。

### 动效与玻璃

- 卡片 → 编辑弹层、快速记录入口 → 面板为缩放转场（iOS 18 `matchedTransitionSource` + `.zoom`）。
- 保存 Success / 删除 Light / 选择 Selection 触感（PRD v3 §3.5.3）。
- 玻璃只用于浮层（80% Clean / 20% Glass）：iOS 26+ 系统 Liquid Glass（导航栏、标签栏、底部配件、弹层、`.glass` / `.glassProminent` 按钮）；更早系统回退材质与 bordered 样式。
- 全部动效尊重「减弱动态效果」（共享 `Motion` 令牌）。

## 架构

- `App/`：`AppState`（Tab、各 Tab 导航栈、跨模块定位 `FocusRouter`、快速记录与深链）、`IdeaReminderCenter`、
  `NotificationDelegate`。
- `UI/`：iOS 外壳（RootView、记录、设置、搜索、欢迎、快速记录）；其余页面直接用 FlashDesign 共享视图。
- `Intents/`：App Intents 与 Siri/快捷指令短语，经 `IntentBridge` 取同一仓储。
- `FlashWidget/`：小组件扩展与控制中心控件。
- `FlashShare/`：分享扩展（只依赖 FlashCore，不打开主库）。
- `App/SpotlightIndexer.swift`：日志 / 灵感 → Core Spotlight。

共享视图在 iOS 上的差异只在 FlashDesign 的少数修饰器里（`flashPanelWidth`、`flashEditorChrome`、
`flashHaptic`、`flashZoomSource` 等），macOS 行为不变。

## 平台差异

- UIKit 仅一处：`FlashDesign/Theme/BrandColors.swift` 的 `UIColor(dynamicProvider:)`
  （SwiftUI 无代码内 light/dark 双值 Color API）及几个系统语义色。其余全部 SwiftUI。
- iPhone Duo（iOS 27.1+ SDK）：同一时间只用一块屏，折叠/展开时窗口实时缩放，无跨屏拼接 API。
  布局只按可用宽度决策（`onGeometryChange` / `ViewThatFits`），不读屏幕、方向或机型。
  展开内屏需在 Device Hub 操作，`simctl io <device> screenshot --display=<UUID>` 可分屏截图。
- 无悬停：共享 `LogCardView` 在 iOS 用 `actionsVisibility: .hidden`，操作走轻扫与长按菜单。

## 隐私与数据安全

- **锁屏通知**：任务提醒的标题固定为「Flash 任务提醒」，任务名只在正文。类别设了隐藏预览占位
  （「你有一个任务提醒」+ `.hiddenPreviewsShowTitle`），系统「显示预览」为「解锁时」（iOS 默认）时，
  锁屏只显示通用文案。灵感提醒正文只含数量。
- **小组件**：主屏与锁屏小组件标记 `privacySensitive()`，锁屏且需要隐藏敏感内容时由系统打码。
- **快速记录草稿**：存于 Application Support 的 `quick-capture-draft.json`，以 `.completeFileProtection`
  写入（锁定即不可读），并标记不纳入 iCloud / 电脑备份。旧版存在 UserDefaults 的草稿会在首次启动时迁入并删除。
- **分享扩展**：
  - 只读取用户在分享面板里主动交给 Flash 的文本 / 链接，不读剪贴板、不联网，没有任何内容离开设备；
  - 保存后每条内容是 App Group 容器 `capture-inbox/` 下的一个 JSON 文件，以 `.completeFileProtection` 写入（锁定即不可读），
    目录与文件都标记不纳入 iCloud / 电脑备份；
  - 留存：Flash 下次启动或回到前台时收入并立即删除文件；最多积压 50 条，满了扩展会提示先打开 Flash；
    损坏的文件记日志后删除；
  - 数据库内存降级期间不收入、不删除，留到下次正常启动，避免写进临时库后丢失；
  - 扩展有独立 `PrivacyInfo.xcprivacy`：无跟踪、无收集数据类型、无 required-reason API（时间戳存在 JSON 里，不读文件属性）。
- **系统搜索（Spotlight）**：
  - 收录什么：每条日志 / 灵感的首行（≤60 字）作标题、其后正文摘录（≤300 字）、类型与标签关键词、创建时间；
    情绪与任务不收录；
  - 存在哪：本机独立命名索引 `flash-records`，保护级别 `.complete`（设备锁定时不可读）；
    不设公开索引，不经 Apple 服务器，不随 iCloud 同步。系统「Siri 建议」可能在搜索与建议里展示已收录的条目；
  - 留存：删除记录即从索引撤下；清空全部、覆盖导入会清空索引后按现有数据重建；启动时全量对账一次；
    点开一条已不存在的结果会顺手撤掉它；
  - 数据库内存降级期间不写、不删、不重建索引；
  - 如何关闭：「设置 › 隐私 › 在系统搜索中显示」，关闭即清空 Flash 的整个索引；或在 iOS「设置 › Apps › Flash Aero ›
    Siri 与搜索」中关闭「在搜索中显示 App 内容」。默认开启。
- **数据库落盘**：SwiftData 存储沿用系统默认保护级别（首次解锁后可读）。不提升到「锁定即不可读」：
  锁屏上点通知的「完成 / 稍后」需要在锁定状态写库。存储随系统设备备份一同备份：这是用户希望换机后恢复的数据。
- **诊断日志**：错误经 `FlashLog`（`os.Logger`）记录。事件名与错误类型公开，错误详情为 `.private`，
  设备日志里显示为 `<private>`，不再用 `print` 输出可能含记录正文或路径的错误描述。
- **数据库打不开（内存降级）**：提示「原有数据仍在本机、未被改动」，并请用户完全退出后重新打开；
  不再建议导出。降级期间以下操作全部暂停：
  - 启动时的提醒重建、小组件刷新、灵感已读状态写入；
  - 导出、分享、局域网收发、导入、清空。

  临时库只含本次启动后的内容，不是完整备份：
  - 用它覆盖导入会抹掉真实数据，所以 `BackupImportCoordinator` 直接拒绝（`BackupError.temporaryStore`）；
  - 按它重建提醒会撤掉全部真实提醒。

## 签名与已知限制

- 未设置 `DEVELOPMENT_TEAM`。真机上 App Group 需要团队签名，否则小组件显示「打开 Flash 开始记录今天」引导态；
  模拟器用下方「签名模拟器构建」即可看到实时数据。
- 分享扩展同样依赖 App Group：真机未设团队签名时，扩展提示「共享容器不可用」，不会保存。
  模拟器用「签名模拟器构建」可走通。
- 交互式小组件（在小组件里勾选完成任务）未做：需要把 SwiftData 存储迁到 App Group 容器，属独立迁移。
- 控制中心控件、通知「完成/稍后」、主屏与锁屏小组件保留既有模拟器手动点验记录（2026-10-24）。旧LAN模拟器↔同机Mac点验是停用前的历史证据，不代表当前可用或真机安全；当前候选全部LAN入口只显示替代指导。WidgetKit敏感标记已加入，锁屏实际遮蔽/通知/真机行为仍待验。

## 构建与测试

```bash
cd ios
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project Flash.xcodeproj -scheme Flash \
  -destination 'generic/platform=iOS Simulator' build-for-testing CODE_SIGNING_ALLOWED=NO

# 在模拟器运行测试
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project Flash.xcodeproj -scheme Flash \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test CODE_SIGNING_ALLOWED=NO

# 签名模拟器构建（嵌入 App Group，小组件可读到实时数据；无需团队）
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project Flash.xcodeproj -scheme Flash \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=
```

共享逻辑的单测在包内跑：`cd ../shared/FlashKit && swift test`。调试灌注：启动环境变量
`FLASH_SEED_SYNTHETIC=80`（空库时生成确定性合成数据，可走完整备份链路）。

## 纸上书写候选验收

Memory 导航标题已接入本地化目录。简中、阿拉伯语、德语和英语各 28 项候选测试通过，新增译文待母语者复核。
