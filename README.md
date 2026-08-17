# Flash 一闪

> 闪过即留，一目了然 —— 本地优先的灵感 / 日志 / 情绪记录应用。

爱发电主页：ifdian.net/a/HEY10086D

Flash 是一款面向个人用户的本地优先笔记应用，支持快速记录日志、收藏灵感、日历聚合回顾与每日情绪记录。数据完全存储在本地，无需后端、不联网、不收集任何数据，三端通过 JSON 备份文件互通。

## 仓库结构

本仓库自 2026-08-14 起为**纯原生仓库**（Web 版与 Capacitor 壳已退役，git 历史可查）：

```
├── android/        # 原生 Android：Kotlin + Jetpack Compose + Material 3 + Room
├── macos/          # 原生 macOS：SwiftUI + SwiftData（universal2，arm64 + x86_64，含菜单栏伴侣）
├── scripts/        # Android 发布签名脚本
├── ROADMAP.md      # 开发路线图
└── README.md
```

## 构建与测试

### Android（`android/`）

```bash
cd android
./gradlew :app:assembleDebug    # 产出 app/build/outputs/apk/debug/app-debug.apk
./gradlew test                  # 单元测试
```

### macOS（`macos/`）

要求 macOS 15+（Apple Silicon 与 Intel 均支持），Xcode 26+：

```bash
cd macos
# 若 xcode-select 指向 CommandLineTools，需加 DEVELOPER_DIR 前缀指向完整 Xcode
xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug build
xcodebuild -project Flash.xcodeproj -scheme Flash -configuration Debug test
```

详细说明见 [macos/README.md](macos/README.md)。

## 数据互通

三端（Android / macOS / 历史 Web 版）共享同一 JSON 备份格式 `flash-backup-v1`，字段与校验规则逐字对齐：

```json
{ "version": "flash-backup-v1", "exportedAt": "...", "appVersion": "...",
  "notes": "", "logs": [...], "emotions": [...] }
```

在各端「设置 → 导出备份 / 导入备份」（支持合并导入与覆盖导入）即可跨端迁移数据。
