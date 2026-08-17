# Flash 一闪 · macOS

桌面端原生实现。SwiftUI + SwiftData，零第三方依赖，App Sandbox 内运行，无网络权限。

- Bundle ID：`com.flash.app.macos`
- 部署目标：macOS 15.0
- 架构：universal2（arm64 + x86_64）

## 功能

| 模块 | 说明 |
| --- | --- |
| 首页 | 当日概览、快速记录、最近动态、情绪快照、本周洞察、全局搜索（⌘K） |
| 探索 | 日志 + 灵感统一信息流，模块筛选，底部快速输入（`!!` 标记重要度） |
| 记录流 | 搜索、标签 / 日期筛选、排序、编辑、删除 |
| 情绪 | 七级滑块 + 子情绪 + 备注，周趋势，近期记录 |
| 日历 | 日志与情绪按日聚合的月历 |
| 统计 | KPI、情绪趋势、子情绪分布 |
| 设置 | 主题（系统 / 浅色 / 深色）、备份导入导出、清空数据 |
| 菜单栏伴侣 | MenuBarExtra：快速记录（回车即存）、今日概览、一键跳转主窗口 |

快捷键：⌘N 新建、⌘K 搜索、⌘, 设置、⇧⌘E 导出备份、⌘1…⌘6 切换模块。

动效统一走 `Flash/Theme/FlashMotion.swift`（Soft / Fast / Playful），
全量尊重系统「减弱动态效果」。

## 架构

读路径：视图经 SwiftData `@Query` 直读；聚合 / 统计 / 搜索等纯逻辑下沉到
`Flash/Domain/` 的纯函数（与 Android 端算法口径一一对应，可直接单测）。
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

当前 51 个用例，覆盖模型 / Repository / BackupService / SettingsStore /
Domain 纯函数 / 主题色。

## 备份格式

与 Android 端 `Backup.kt` 互通的 `flash-backup-v1` JSON：

```json
{ "version": "flash-backup-v1", "exportedAt": "...", "appVersion": "...",
  "notes": "...", "logs": [...], "emotions": [...] }
```

- `version` 不匹配拒绝导入；非法条目逐条跳过；单文件上限 50 MB。
- 读写走 App Sandbox 的用户择定文件授权，导出文件权限 0600。

## 性能基线

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
- universal2 的 x86_64 切片只在 Apple Silicon 上交叉编译验证过，未做 Intel 实机测试。
- iCloud 同步、原生 iOS 版（可共享 SwiftData 模型）是后续候选，不在本版本。
