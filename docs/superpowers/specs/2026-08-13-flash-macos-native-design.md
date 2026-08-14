# Flash（一闪）原生 macOS 版 · 设计文档

日期：2026-08-13
状态：待评审（视觉规范一节待 macOS 27 UI Kit 研究回填）

## 1. 目标与非目标

### 目标
- 构建原生 macOS 版 Flash，功能与现有原生 Android 版**完全对齐**
- Universal 2 二进制：同一 App 同时原生支持 Apple Silicon（arm64）与 Intel（x86_64）
- 最低系统 macOS 15 Sequoia；macOS 26+（Liquid Glass）渐进增强
- 遵循 Apple HIG（Designing for macOS）+ macOS 27 UI Kit + Apple 隐私准则
- 与 Android/Web 版 JSON 备份互通（同一 schema）

### 非目标（YAGNI）
- iCloud / CloudKit 同步（后续版本再议）
- 抽象跨 Apple 平台 Swift Package（未来原生 iOS 版再说）
- 网络功能、账号体系、遥测（本 App 纯本地，永不联网）
- Catalyst / 复用 Web 版（用户明确要求真原生）

## 2. 技术选型

| 项 | 决策 | 理由 |
|---|---|---|
| UI 框架 | SwiftUI（App lifecycle） | 官方原生方向，HIG 组件齐全 |
| 数据层 | SwiftData | macOS 15 基线可用，与 Room 概念对齐 |
| 设置存储 | @AppStorage（UserDefaults） | 对应 Android SharedPreferences |
| 依赖 | **零第三方** | 安全面最小、包体最小 |
| 构建 | Xcode 工程，`ARCHS=arm64 x86_64`，`MACOSX_DEPLOYMENT_TARGET=15.0` | Universal 2 |
| 测试 | Swift Testing + XCTest | 与 Apple 工具链一致 |

工程位置：`app/native-macos/`（与 `native-android/` 并列）。

## 3. 架构与分层

与 Android 版镜像对齐，降低双端维护成本：

```
native-macos/
├── Flash.xcodeproj
├── Flash/
│   ├── FlashApp.swift            # App 入口、ModelContainer、菜单栏命令
│   ├── Models/                   # 数据模型（storageKey 与 Android/Web 逐字对齐）
│   │   ├── ColorTag.swift        # urgent/inspiration/daily/memo/emotion/idea（含 hex）
│   │   ├── Category.swift        # log/idea
│   │   ├── EmotionLevel.swift    # -3...3，含 emoji 映射
│   │   ├── SubEmotion.swift      # sad/angry/uncomfortable
│   │   ├── LogItem.swift
│   │   └── EmotionRecord.swift
│   ├── Data/
│   │   ├── FlashDatabase.swift   # SwiftData ModelContainer 装配
│   │   ├── Entities.swift        # @Model LogEntity / EmotionEntity（列名对齐 Room）
│   │   ├── FlashRepository.swift # CRUD + 查询（对齐 Android FlashRepository）
│   │   ├── BackupService.swift   # JSON 导入导出（§6）
│   │   └── SettingsStore.swift   # @AppStorage：themeMode/welcomed（Mac 无 uiStyle/dynamicColor）
│   ├── Domain/
│   │   └── EmotionStats.swift    # 算法逐行对齐 Android EmotionStats.kt
│   ├── Theme/
│   │   ├── BrandColors.swift     # 品牌色 / 模块色
│   │   └── Materials.swift       # macOS 15 系统材质；macOS 26 Liquid Glass 分支
│   └── UI/
│       ├── RootSplitView.swift   # NavigationSplitView 骨架
│       ├── Sidebar.swift
│       ├── Welcome/  Home/  LogFlow/  Emotion/  Explore/
│       ├── Calendar/  Stats/  Settings/
│       └── Components/           # LogCard、QuickCreateButton 等
└── FlashTests/                   # Swift Testing
```

## 4. 导航与交互（HIG 原生）

- `NavigationSplitView`：侧栏列出 首页 / 记录流 / 情绪 / 探索 / 日历 / 统计 / 设置
- 记录流、日历：「列表 → 详情」布局（记录流为列表 + 编辑 sheet，日历为月网格 + 当日详情区，功能等价于双栏）；情绪、统计、设置：整幅内容区
- 原生工具栏放主操作（新建记录 ⌘N、导出备份 ⇧⌘E、搜索 ⌘F）；完整菜单栏命令与标准快捷键（⌘, 设置等）
- 首次启动欢迎页在同窗内切换展示，完成后不再出现（welcomed 标记）
- 右键上下文菜单（删除记录等）、键盘导航、Focus Ring、VoiceOver 标签
- 浅/深色：跟随系统（默认），可强制浅色/深色（themeMode: system/light/dark）

## 5. 数据层

SwiftData `@Model`，字段/列名与 Room Entities 一一对应：

**logs**：`id`(String, PK), `content`, `colorTag`, `category`, `importance`(Int 0-4), `createdAt`(ISO-8601 String), `recordDate`(yyyy-MM-dd)

**emotions**：`id`(String, PK), `level`(Int -3...3), `subEmotion`(String?), `status`(String?), `note`(String?), `recordDate`, `createdAt`

存储值（storageKey）与 Android `Models.kt` 逐字对齐，保证三端备份文件通用。

## 6. JSON 备份互通

格式与 Android `Backup.kt` / Web `backup.ts` 完全一致：

```json
{
  "version": "flash-backup-v1",
  "exportedAt": "<ISO-8601>",
  "appVersion": "<semver>",
  "notes": "",
  "logs":    [{ "id", "content", "colorTag", "category", "importance", "createdAt", "recordDate" }],
  "emotions":[{ "id", "level", "subEmotion", "status", "note", "recordDate", "createdAt" }]
}
```

导入模式（对齐 Android `FlashRepository`，导入前弹 Alert 让用户选）：
- **合并导入**：同 id 记录覆盖，其余现有数据保留（对应 `mergeAll`）
- **覆盖导入**：清空后整体替换（对应 `replaceAll`），需二次确认

导入校验（对齐 `validateBackup`/`sanitizeBackup`）：
- 文件整体非法 → 报 `BackupFormatError`，不改动现有数据
- 单条非法 → **跳过并计数**（skippedLogs / skippedEmotions），导入结果向用户报告
- 校验规则：id 必须为 UUID、recordDate 必须 `yyyy-MM-dd`、createdAt 严格 ISO-8601、colorTag/category/subEmotion 必须在枚举内、importance 收敛 0-4、level 收敛 -3...3
- 安全上限：文件 ≤ 50MB、数组长度上限、content/note 长度上限（防畸形 JSON 炸弹）
- 文件选择走 NSOpenPanel / NSSavePanel（用户显式授权路径）

## 7. 安全与隐私（严格遵循 Apple Privacy 准则）

- **零网络**：不申请 `com.apple.security.network.*` 任何 entitlement，从系统层面断网
- App Sandbox + Hardened Runtime 全开，entitlements 最小化：仅 `files.user-selected.read-write`
- `PrivacyInfo.xcprivacy` 隐私清单：声明**未收集任何数据**；UserDefaults 访问声明 Required Reason（CA92.1）
- App Store 隐私营养标签：Data Not Collected
- 无账号、无遥测、无第三方 SDK；本地数据受 FileVault 保护
- 发布：Developer ID 签名 + Notarization 公证

## 8. 性能（量化指标 + 架构专项优化）

指标（开发中用 Instruments 反复验证，写入验收标准）：
- 冷启动：M 系列 < 1s；Intel < 1.5s
- 列表滚动稳定 60fps（含 Intel 核显）；M 系列 ProMotion 适配 120Hz
- 空闲内存 < 150MB（M3 Pro / macOS 27 实测基线 129.9MB，ps RSS 口径；原 80MB 目标对 SwiftUI+SwiftData 运行时基线不现实，2026-08-14 修订）；安装包 < 20MB（实测 4.3MB）

架构专项：
- **M 系列**：全模块优化（WMO）、ProMotion 自适应、Metal 友好的图表绘制
- **Intel（更需优化）**：老核显（UHD 630 / Iris Plus）约束下——
  - 背景用预渲染静态渐变位图，**不用**全屏实时材质混合
  - 严格限制模糊半径/阴影层数，控制离屏渲染
  - 图表路径缓存、列表懒加载、图片降采样
- 双架构统一：`os_signpost` 打点；Time Profiler / Allocations / Energy 回归

已知限制：开发机为 M3 Pro，无 Intel 实机；Intel 体验靠 Universal 编译 + 规避 arm-only API + 上述保守渲染策略保证，文档如实标注。

## 9. 测试

- Swift Testing：Repository CRUD、备份 导出→导入 往返等价、EmotionStats 三端结果一致（同一组夹具数据）
- UI 冒烟：XCUITest 启动 + 侧栏导航 + 新建记录主流程
- 手动清单：浅/深色、窗口缩放/最小尺寸、快捷键、导入导出、Intel 构建产物 `lipo -info` 验证双架构

## 10. 视觉规范（依据 macOS 27 UI Kit + HIG 研究）

来源：4688 页官方 UI Kit（数值见 p4681 Change Log 与画板实测）+ HIG 官方镜像 + WWDC25。标注 [经验值] 的条目官方无硬性规范。

### 10.1 窗口
- 合理最小尺寸 **960×640pt**（官方无规范值，自定），默认 1200×760；窗口底部不放关键信息/操作
- 窗口三态（key/main/inactive）外观交给系统，不自定义红绿灯区域；macOS 26+ 自动获得 16pt 窗口圆角

### 10.2 导航
- `NavigationSplitView` 三栏：侧栏 240pt（可拖范围 225–275，最大 350 [经验值]）+ 内容列表 + 详情
- 侧栏：节标题灰色小字加粗；选中行圆角矩形填充；**图标跟随系统 controlAccentColor**，不写死品牌色；行尺寸不写死（系统 Small/Medium/Large 三档自适应）
- 允许隐藏侧栏（工具栏按钮 + View 菜单命令，措辞随状态切换）；窗口变窄自动收起
- 工具栏三分区：leading=侧栏开关+标题，center=常用项，trailing=主操作+搜索框；**每个工具栏项在菜单栏都有对应命令**；窗口标题 ≤15 字符
- 主要动作用 `.prominent`，每视图至多 1–2 个，放 trailing

### 10.3 材质与 Liquid Glass（分层铁律）
- **功能层**（工具栏/侧栏/Alert/Popover）：玻璃材质——用系统标准组件自动获得，不给自定义着色背景
- **内容层**（编辑器、日志卡片、图表区）：**禁止玻璃**，用 `textBackgroundColor`/标准材质；macOS 15–25 用五档标准材质（按语义选，不按颜色选）
- 自定义玻璃效果只给最重要的功能元素；相邻玻璃形状用 `GlassEffectContainer` 分组
- 必须在「降低透明度」「增强对比度」两个辅助功能设置下实测

### 10.4 色彩
- 文本/控件/背景**全语义色**：`labelColor`/`secondaryLabelColor`/`tertiaryLabelColor`、`controlAccentColor`、`selectedContentBackgroundColor`、`separatorColor`、`windowBackgroundColor` 等，禁止硬编码
- 品牌 accent 仅在用户系统强调色为 multicolor 时生效，否则跟随用户色
- 情绪七级色、六色标签：每个自定义色提供 light/dark/高对比三变体，对比度 ≥ WCAG AA（4.5:1）
- 玻璃着色（tint）克制：只给状态指示与主要动作，颜色加在背景而非符号上

### 10.5 排版
- SF Pro；macOS 无 iOS 式文本样式表：正文 13pt、辅助说明 11pt、注释 10pt（下限）、窗口标题 13pt 粗体
- SF Symbols 与文字同字重；编辑器正文用 `userFont` 动态变体

### 10.6 控件
- 全部使用系统标准控件与尺寸档（默认 regular；标志性主动作可用 macOS 26 的 Extra Large）；不硬编码高度，Auto Layout 自适应
- 点击热区 ≥28×28pt；破坏性动作=系统红且**永不给 primary role**
- Alert 用系统样式（首选=实心胶囊、破坏性=浅红底红字、取消=灰胶囊）
- 设置页：inset 圆角分组表单，左标签右控件，行间行底 border
- 分段控件/开关/滑块用系统标准样式（玻璃上不加 over-glass 变体，macOS 27 已移除）

### 10.7 交互细节
- 不重新定义标准快捷键；输入区支持 ⌘Z/⇧⌘Z 多级撤销（Edit 菜单 Undo 动态命名）
- 菜单项不可用=禁用而非隐藏；右键菜单少量且菜单栏可找到
- 全键盘可达（Tab 序=视觉序），焦点环 `keyboardFocusIndicatorColor` 清晰可见
- 可选增强：menu bar extra「快速记录」（HIG 推荐场景，列入二期候选）

### 10.8 双架构设计含义
- **macOS 26 是 Intel 最后支持的大版本**；部署目标 macOS 15 + universal2 的决策正确且必要
- macOS 26+ 自动获得 edge-to-edge 全高侧栏与 Liquid Glass；macOS 15–25 用标准材质兜底，布局代码不写分支（仅材质/API 层 `if #available`）
