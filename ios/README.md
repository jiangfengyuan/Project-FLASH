# Flash Aero · iOS

iPhone 原生实现（开发中）。SwiftUI + SwiftData，零第三方依赖；数据层、领域逻辑与设计语言
与 macOS 共用 [`shared/FlashKit`](../shared/FlashKit) 本地 Swift Package。

- Bundle ID：`com.flash.app.ios`
- 部署目标：iOS 18.0（与 macOS 15.0 同代 API）
- 设备：仅 iPhone（`TARGETED_DEVICE_FAMILY = 1`），竖屏
- 模块名 `Flash`（与 macOS 一致，`@testable import Flash`）

## 现状（2026-10-18）

| 模块 | 状态 |
| --- | --- |
| 此刻 | ✅ 首个端到端切片：问候区、今日一览、快速捕捉（日志/灵感）、最近闪念（长按收藏/删除，删除二次确认），写入经 `FlashRepository` |
| 记录 / 回顾 / Memory / 设置 | 占位页（`EmptyStateView`），按里程碑移植 |
| 日志流 / 情绪 / 日历与任务 | 未开始；作为次级入口在 Tab 内推入 |

启动装配与 macOS 同源：`RepositoryEnvironment.makeDefault()`（持久化失败降级内存并弹窗）、
`SettingsStore` 主题、`TaskReminderScheduler.rebuild`、`WidgetSnapshot.refresh`。

## 里程碑

| 里程碑 | 内容 |
| --- | --- |
| M2 | 记录 + 日志流：搜索、筛选、编辑（LogEditSheet）、全局搜索（替代 ⌘K） |
| M3 | 情绪：七级 + 强度 + 子情绪 + 备注、周趋势 |
| M4 | 日历 + 任务 + 本地提醒、灵感转任务 |
| M5 | 回顾 + Memory 周报 |
| M6 | 设置：主题、备份导入导出（fileImporter/fileExporter + 分享）、LAN 直传（需 `NSLocalNetworkUsageDescription`/`NSBonjourServices`）、欢迎页 |
| M7 | iOS 增强：主屏/锁屏小组件（含交互式完成任务）、控制中心/操作按钮/快捷指令 Quick Capture、触感反馈、提醒通知「完成/稍后」操作 |

候选未排期：分享扩展、Spotlight 索引、Face ID 锁、图片附件（需备份契约 schema 3）。

## 平台差异

- UIKit 仅一处：`FlashDesign/Theme/BrandColors.swift` 的 `UIColor(dynamicProvider:)`
  （SwiftUI 无代码内 light/dark 双值 Color API）及两个系统语义色。其余全部 SwiftUI。
- Liquid Glass 双轨：iOS 26+ `.glassEffect`，iOS 18–25 回退 `.regularMaterial`。
- iPhone Duo（iOS 27.1+ SDK）：同一时间只用一块屏，折叠/展开时窗口实时缩放，无跨屏拼接 API。
  布局只按可用宽度决策（`onGeometryChange`），不读屏幕、方向或机型；此刻页 ≥700pt 双栏。
  展开内屏需在 Device Hub 操作，`simctl io <device> screenshot --display=<UUID>` 可分屏截图。
- 无悬停：共享 `LogCardView` 的悬停操作按钮在 iOS 不出现，操作走长按菜单。
- App Group `group.com.flash.app.ios`（小组件数据）需团队签名；未签名构建自动跳过快照写入。
- App 图标未配置：`assets/logo.png` 是带留白的 macOS 风格图标，iOS 需要满版 1024² 无透明图。

## 构建与测试

```bash
cd ios
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project Flash.xcodeproj -scheme Flash \
  -destination 'generic/platform=iOS Simulator' build-for-testing CODE_SIGNING_ALLOWED=NO

# 在模拟器运行测试（需可用的 iPhone 模拟器）
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project Flash.xcodeproj -scheme Flash \
  -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO
```

共享逻辑的单测在包内跑：`cd ../shared/FlashKit && swift test`。
