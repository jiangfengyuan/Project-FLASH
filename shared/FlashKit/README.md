# FlashKit

macOS 与 iOS 共用的本地 Swift Package（swift-tools 6.0，Swift 6 语言模式，macOS 15 / iOS 18）。

| 产物 | 内容 |
| --- | --- |
| `FlashCore` | 模型（`Models/`）、SwiftData 版本化实体与迁移、`FlashRepository`、备份（flash-backup-v2）、`BackupImportCoordinator`（导入预览 / 合并 / 覆盖）与 LAN 直传、领域纯函数（`Domain/`，含 `IdeaReminder`）、`SettingsStore`、`KeyChord`、小组件快照协议、`IdeaViewStateStore` / `IdeaReminderScheduler` / `TaskReminderScheduler`、展示层（`HomeViewModel`、`QuickCaptureCommit`、`FocusRouter`、`TaskSaving`、`TaskReminderActions`） |
| `FlashDesign` | 设计令牌、动效、品牌色、玻璃双轨与玻璃按钮、共用组件（卡片、Chip、Toast、空态、记录卡、此刻页卡片），以及 `Features/` 下两端共用的页面：Memory、回顾、情绪、日历与任务编辑、日志流与编辑面板、记录筛选与列表、设置分组与局域网面板 |

约定：

- 由 `macos/Flash/` 迁入（`git mv` 保留历史），对外 API 显式 `public`；值类型显式 `Sendable`
  （跨模块不再隐式推断）。
- 平台差异只用 `#if canImport(AppKit)` / `#if os(iOS)` 隔离在少数文件：`BrandColors`、
  `WidgetSnapshotStore.groupIdentifier`、`LocalBackupTransfer` 的 Bonjour 设备名、玻璃 `#available`。
  AppKit 专属代码（`KeyChord(nsEvent:)`、全局热键）留在 macOS 工程。
- 页面在两端的差异只走 `Support/PlatformModifiers.swift` 的修饰器（`flashPanelWidth`、`flashCheckboxToggleStyle`、
  `flashEditorChrome`、`flashHaptic`、`flashZoomSource` / `flashZoomTransition`、`flashRoundedFieldStyle`）与
  `flashUsesSystemNavigationTitle` 环境值，macOS 行为保持不变。
- 多页面同时存活（iOS 各 Tab 常驻）时用 `FocusRouter.consume(matching:)`，只消费属于本页的定位请求。
- `Category` 与 ObjectiveC 运行时同名：使用方模块各放一个 `typealias Category = FlashCore.Category`，
  公开签名中写 `FlashCore.Category`。
- SwiftData 实体名不含模块名（`LogEntity` 等），迁入前写入的 macOS 数据库可直接打开（已用旧版代码写库、新包读写验证）。

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -scheme FlashKit-Package -destination 'generic/platform=iOS Simulator' build
```
