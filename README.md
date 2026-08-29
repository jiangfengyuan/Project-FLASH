# Flash Aero · 一闪

闪过即留，一目了然。本地优先的日志 / 灵感 / 情绪记录应用。

当前版本：**Flash Aero v0.1.0**。`Aero` 是 v0 Alpha 阶段的版本代号；
首个正式版将统一命名为 **Flash Pulse v1.0.0**。

没有账号、没有后端、不申请网络权限——数据只存在你自己的设备上，
换设备靠 JSON 备份文件互通。

[爱发电主页](https://ifdian.net/a/HEY10086D)

![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg)

## 平台

| 平台 | 技术栈 | 状态 |
| --- | --- | --- |
| Android | Kotlin + Jetpack Compose + Material 3 + Room | Flash Aero v0.1.0 |
| macOS | SwiftUI + SwiftData，universal2（arm64 + x86_64） | Flash Aero v0.1.0 |

历史上有过 React + Capacitor 的 Web/混合版，已退役（git 历史可查），
本仓库现在是纯原生仓库。

## 功能

- **快速记录**：macOS 有菜单栏伴侣（按回车保存），Android 有全局 FAB；`!!` 语法标记重要度；
- **日志 / 灵感**：时间线、搜索、标签与日期筛选、编辑删除；
- **情绪**：七级滑块 + 子情绪标签 + 备注，周趋势与统计图表；
- **日历**：日志与情绪按日聚合的月历视图；
- **统计**：累计 KPI、情绪趋势、子情绪分布；
- **备份**：JSON 导出 / 导入（合并或覆盖），macOS与Android两端格式一致、可互读。

## 构建

### Android

```bash
cd android
./gradlew :app:assembleDebug   # 产出 app/build/outputs/apk/debug/app-debug.apk
./gradlew test                 # 单元测试
```

详见 [android/README.md](android/README.md)。

### macOS

要求 macOS 15+ 与 Xcode 26。本仓库日常用 Xcode beta 构建（`DEVELOPER_DIR` 前缀），
稳定版 Xcode 可去掉：

```bash
cd macos
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -scheme Flash -destination 'platform=macOS' build
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild test -scheme Flash -destination 'platform=macOS'
```

详见 [macos/README.md](macos/README.md)。

## 仓库结构

```
├── android/     # 原生 Android 工程
├── macos/       # 原生 macOS 工程（含单元测试）
├── scripts/     # Android 发布签名脚本
├── ROADMAP.md   # 开发路线图
└── README.md
```

## 备份格式

两端共享同一 JSON 格式 `flash-backup-v1`：

```json
{ "version": "flash-backup-v1", "exportedAt": "...", "appVersion": "...",
  "notes": "", "logs": [...], "emotions": [...] }
```

在「设置 → 导出备份 / 导入备份」操作即可跨端迁移；版本不匹配会拒绝导入，
非法条目逐条跳过而不是整体失败。

## 路线图与参与

见 [ROADMAP.md](ROADMAP.md)。目前处于个人维护的 Alpha 阶段，
问题与建议欢迎提 Issue。

## 许可证

Copyright (c) 2026 Fengyuan Jiang

[Mozilla Public License 2.0](LICENSE)（MPL-2.0）。

可自由使用、修改、再分发（包括商用）；对本仓库已有文件的修改需以
相同条款开源，你自己新写的文件不受此限。商标与本项目无关的素材不在授权范围内。
