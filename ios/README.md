# Flash Aero · iOS

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
| 设置 | 主题、灵感提醒（开关 + 每天/每 3 天/每周）、导出到「文件」、系统分享、标准/恢复导入（差异预览、合并/覆盖、覆盖前 TOCTOU 重校验）、局域网收发、清空、关于 |
| 欢迎页 | 首次启动三页横滑 |

### 快速记录（iOS 版 Quick Capture）

规则对齐 macOS PRD §13–14：默认灵感、可切日志、回车即存、保存即关（成功触感）、未提交保留草稿。入口：

- iOS 26+ 标签栏上方 Liquid Glass 常驻条「现在想记录什么？」（滚动时标签栏收起）；iOS 18–25 为右下悬浮按钮；
- 控制中心 / 锁屏 / 操作按钮：「Flash 快速记录」控件；
- 中号主屏小组件的「灵感 / 日志」按钮；
- Siri 与快捷指令：「用 Flash 记一闪」打开面板；「记一闪」动作直接写入、不打开 App；
- 深链 `flash://capture[?category=idea|log]`。

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

共享视图在 iOS 上的差异只在 FlashDesign 的少数修饰器里（`flashPanelWidth`、`flashEditorChrome`、
`flashHaptic`、`flashZoomSource` 等），macOS 行为不变。

## 平台差异

- UIKit 仅一处：`FlashDesign/Theme/BrandColors.swift` 的 `UIColor(dynamicProvider:)`
  （SwiftUI 无代码内 light/dark 双值 Color API）及几个系统语义色。其余全部 SwiftUI。
- iPhone Duo（iOS 27.1+ SDK）：同一时间只用一块屏，折叠/展开时窗口实时缩放，无跨屏拼接 API。
  布局只按可用宽度决策（`onGeometryChange` / `ViewThatFits`），不读屏幕、方向或机型。
  展开内屏需在 Device Hub 操作，`simctl io <device> screenshot --display=<UUID>` 可分屏截图。
- 无悬停：共享 `LogCardView` 在 iOS 用 `actionsVisibility: .hidden`，操作走轻扫与长按菜单。

## 签名与已知限制

- 未设置 `DEVELOPMENT_TEAM`。真机上 App Group 需要团队签名，否则小组件显示「打开 Flash 开始记录今天」引导态；
  模拟器用下方「签名模拟器构建」即可看到实时数据。
- 交互式小组件（在小组件里勾选完成任务）未做：需要把 SwiftData 存储迁到 App Group 容器，属独立迁移。
- 控制中心控件与通知「完成/稍后」已编译并有单测覆盖，未在模拟器手动点验。

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
