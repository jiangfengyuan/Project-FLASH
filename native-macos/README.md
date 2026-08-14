# Flash 一闪 — 原生 macOS 版

Flash 一闪的桌面端原生实现：本地优先的灵感 / 日志 / 情绪记录应用。
SwiftUI + SwiftData，零第三方依赖，App Sandbox 内运行，数据不出本机。

- Bundle ID：`com.flash.app.macos`
- 版本：0.1.0 (1)
- 部署目标：macOS 15.0

## 功能清单

九个 UI 模块（含复用组件库），功能与 Android / Web 版对齐：

| 模块 | 说明 |
| --- | --- |
| Home 首页 | 当日概览（日志/灵感/情绪计数）、快速记录输入、最近 5 条记录 |
| Explore 探索 | 日志+灵感统一信息流、模块筛选、底部快速输入、灵感重要性标记（!! 语法） |
| LogFlow 记录流 | 日志搜索、筛选（关键词/日期/标签）、排序、编辑、删除 |
| Emotion 情绪 | 离散滑块（-3..+3）、子情绪标签、备注、历史列表 |
| Calendar 日历 | 日志与情绪按日聚合、月历网格、按日期查看 |
| Stats 统计 | KPI、情绪趋势、子情绪分布（Swift Charts） |
| Settings 设置 | 主题（跟随系统/浅色/深色）、备份导入导出、清空数据、关于 |
| Welcome 欢迎 | 首次启动引导 |
| 复用组件 | Sidebar / LogCardView / LogEditSheet / PlaceholderView |

快捷键：⌘N 新建记录、⌘F 搜索、⌘, 设置等，详见各视图菜单。

## 系统要求

- macOS 15.0 及以上
- Intel（x86_64）与 Apple Silicon（arm64）双架构（universal2 单二进制）
- 构建工具：Xcode（本仓库使用 Xcode beta，`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`；稳定版 Xcode 可去掉此前缀）

## 构建

```bash
cd native-macos

# Debug（日常开发）
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug \
  -derivedDataPath build/dd build

# Release universal2（双架构发布产物）
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Release \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  -derivedDataPath build/dd clean build
```

产物：`build/dd/Build/Products/{Debug,Release}/Flash.app`。

注意：工程使用 adhoc 签名（`CODE_SIGN_IDENTITY = "-"`）以便本地直接运行；
因此本地产物的 entitlements 会额外带上 `get-task-allow`（Xcode 对 adhoc 签名的默认注入，
不是 `Flash.entitlements` 里声明的内容）。对外分发需改用 Developer ID 签名 + 公证，
届时 `get-task-allow` 自动消失。

## 测试

```bash
cd native-macos
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild test -project Flash.xcodeproj -scheme Flash -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build/dd
```

当前 37 个 test case（模型 / Repository / BackupService / SettingsStore / Domain 纯函数 / 主题色）。

## 备份格式（与 Android / Web 互通）

导出为 JSON 文件，格式与 Android `Backup.kt`、Web `backup.ts` 完全一致：

```json
{ "version": "flash-backup-v1", "exportedAt": "...", "appVersion": "...",
  "notes": "...", "logs": [...], "emotions": [...] }
```

- 三端可互相导入导出；`version` 字段不匹配时拒绝导入并提示。
- 导入对非法条目逐条跳过而非整体失败；单文件上限 50 MB。
- macOS 端经 App Sandbox 的用户择定文件授权（`files.user-selected.read-write`）读写，无网络权限。

## 性能基线

测量环境：Apple M3 Pro / 36 GB / macOS 27.0 (26A5388g)，Release universal2 构建，热缓存。
测量日期：2026-08-14。

| 指标 | 实测 | 方法 |
| --- | --- | --- |
| 架构 | x86_64 + arm64（universal2） | `lipo -info` |
| 包体 | 4.3 MB（.app 整体；可执行文件 4.2 MB） | `du -sh`，远低于 20 MB 目标 |
| 冷启动 | 中位 0.084 s（3 次：0.084 / 0.093 / 0.083） | `open -n` 到进程检出的粗测，非首帧时间 |
| 空闲内存 | RSS 129.9 MB | 启动后静置 30 s，`ps -o rss=` |
| 滚动帧率 | 未测（无 Instruments） | 目测流畅；长列表均为 LazyVStack / LazyVGrid 懒加载；37 测试全过 |

冷启动数字为进程出现时间的下界近似，未含首帧渲染；后续可用
`os_signpost` + Instruments Time Profiler / Animation Hitches 补精确数据。

## 已知限制

- 无 Intel 实机验证：universal2 已含 x86_64 切片，但仅在 Apple Silicon 真机上运行过。
- menu bar extra（菜单栏快速记录）未做，列为后续候选。
- 本地 adhoc 签名，未公证；对外分发需 Developer ID + notarize。
- 帧率未做 Instruments 定量测量（见性能基线表）。
- iCloud 同步、原生 iOS 版（共享 SwiftData 模型）为后续候选，不在本版本范围。
