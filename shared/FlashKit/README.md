# FlashKit

macOS 与 iOS 共用的本地 Swift Package（swift-tools 6.0，Swift 6 语言模式，macOS 15 / iOS 18）。

| 产物 | 内容 |
| --- | --- |
| `FlashCore` | 模型（`Models/`）、SwiftData 版本化实体与迁移、`FlashRepository`、备份（flash-backup-v2）与 LAN 直传、领域纯函数（`Domain/`）、`SettingsStore`、`KeyChord`、小组件快照协议、展示层 `HomeViewModel` / `QuickCaptureCommit` |
| `FlashDesign` | 设计令牌（间距/圆角/字体/阴影）、动效、品牌色、玻璃双轨，以及共用组件（卡片、Chip、Toast、空态、记录卡、此刻页卡片） |

约定：

- 由 `macos/Flash/` 迁入（`git mv` 保留历史），对外 API 显式 `public`；值类型显式 `Sendable`
  （跨模块不再隐式推断）。
- 平台差异只用 `#if canImport(AppKit)` / `#if os(iOS)` 隔离在少数文件：`BrandColors`、
  `WidgetSnapshotStore.groupIdentifier`、`LocalBackupTransfer` 的 Bonjour 设备名、玻璃 `#available`。
  AppKit 专属代码（`KeyChord(nsEvent:)`、全局热键）留在 macOS 工程。
- `Category` 与 ObjectiveC 运行时同名：使用方模块各放一个 `typealias Category = FlashCore.Category`，
  公开签名中写 `FlashCore.Category`。
- SwiftData 实体名不含模块名（`LogEntity` 等），迁入前写入的 macOS 数据库可直接打开（已用旧版代码写库、新包读写验证）。

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -scheme FlashKit-Package -destination 'generic/platform=iOS Simulator' build
```
