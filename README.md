# Flash Aero · 一闪

闪过即留，一目了然。本地优先的日志 / 灵感 / 情绪记录应用。

当前版本：**Flash Aero v0.1.0**。`Aero` 是 v0 Alpha 阶段的版本代号；
首个正式版将统一命名为 **Flash Pulse v1.0.0**。

没有账号、没有后端——数据默认只存在你自己的设备上；换设备可通过 JSON 文件，
也可在同一局域网内临时配对直传。

[爱发电主页](https://ifdian.net/a/HEY10086D)

![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg)

## 平台

| 平台 | 技术栈 | 状态 |
| --- | --- | --- |
| Android | Kotlin + Jetpack Compose + Material 3 + Room | Flash Aero v0.1.0 |
| macOS | SwiftUI + SwiftData，universal2（arm64 + x86_64） | Flash Aero v0.1.0 |
| HarmonyOS | ArkTS + ArkUI + 加密 RDB + Preferences 设置存储，纯原生 HAP | Flash Aero v0.1.0 |

历史上有过 React + Capacitor 的 Web/混合版，已退役（git 历史可查），
本仓库现在包含 Android、macOS 与 HarmonyOS 三个纯原生工程。

## 功能

- **快速记录**：macOS 有菜单栏伴侣（按回车保存），Android 首页有快速创建 FAB；`!!` 语法标记重要度；
- **日志 / 灵感**：时间线、搜索、标签与日期筛选、编辑删除；
- **情绪**：七级选择（macOS / HarmonyOS 为滑块，Android 为 emoji 按钮）+ 子情绪标签 + 备注，周趋势与统计图表；
- **日历**：日志与情绪按日聚合的月历视图；
- **回顾**：本周/本月/近 30 天/近 90 天窗口、每日活跃度、与前一窗口的趋势洞察、情绪分布，以及页内趋势/日历切换；
- **备份与传输**：JSON 导出 / 导入（合并或覆盖）；支持系统分享，以及同一局域网内通过六位临时 PIN 自动发现、配对直传，两端格式一致、可互读。注意：设备互传（文件分享与局域网直传）尚未完成真机验收，验收矩阵见 [docs/contracts/acceptance.md](docs/contracts/acceptance.md)。

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

### HarmonyOS

要求 DevEco Studio 与 HarmonyOS SDK。可直接用 DevEco Studio 打开 `harmonyos/`，
或执行命令行调试构建：

鸿蒙版已对齐 Android 四模块首页与快速创建体验，并加入页面转场、手机/折叠屏/平板
响应式导航，以及星闪、实况窗、闪控球的合规能力检测页；需审核能力的限制见子工程说明。

```bash
cd harmonyos
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
assembleHap --mode module -p product=default -p module=entry@default \
-p buildMode=debug --no-daemon
```

详见 [harmonyos/README.md](harmonyos/README.md)。

## 仓库结构

```
├── android/     # 原生 Android 工程
├── macos/       # 原生 macOS 工程（含单元测试）
├── harmonyos/   # 原生 HarmonyOS 工程（ArkTS + ArkUI）
├── scripts/     # Android 发布签名脚本
├── ROADMAP.md   # 开发路线图
└── README.md
```

## 备份格式

三端共享同一分区版本化 JSON 格式 `flash-backup-v2`，并继续兼容导入 v1：

```json
{ "version": "flash-backup-v2", "exportedAt": "...", "appVersion": "...",
  "notes": "", "schemas": { "logs": 1, "emotions": 1, "tasks": 1 },
  "data": { "logs": [...], "emotions": [...], "tasks": [...] } }
```

在「设置 → 导出备份 / 导入备份」操作即可跨端迁移；版本不匹配会拒绝导入。
导入分两个入口：标准入口执行严格校验，任何问题整体拒绝、不写库；
「恢复损坏或旧版备份」入口则逐条跳过非法记录并显示跳过数量，用于抢救旧数据。

v2 增加 Calendar 任务、截止时间、完成状态和提醒时间。协议将快照备份与未来的
`flash-sync-v1` 自动同步层分离，后续同步可复用相同分区模型而不改变备份语义；
完整定义见 [docs/flash-backup-v2.md](docs/flash-backup-v2.md)。

也可使用系统分享面板，或选择「局域网发送 / 接收」进行直传。局域网发送方会
生成随机六位 PIN，接收方只有输入正确 PIN 才能取得备份；PIN 60 秒失效、最多
尝试五次，成功后服务立即关闭。接收方会看到新增、修改、相同与仅本机数据的差异，
再选择保留本机数据并合并，或覆盖全部。数据不经过 Flash 服务器。
设备互传尚待真机验收（见 [docs/contracts/acceptance.md](docs/contracts/acceptance.md)），
局域网直传建议只在可信的家庭或办公网络使用。

## 路线图与参与

见 [ROADMAP.md](ROADMAP.md)。目前处于个人维护的 Alpha 阶段，
问题与建议欢迎提 Issue。

## 许可证

Copyright (c) 2026 Fengyuan Jiang

[Mozilla Public License 2.0](LICENSE)（MPL-2.0）。

可自由使用、修改、再分发（包括商用）；对本仓库已有文件的修改需以
相同条款开源，你自己新写的文件不受此限。商标与本项目无关的素材不在授权范围内。

## 验收与发布状态（2026-09-26）

UI/UX 阶段三主体实现已完成；完整设备矩阵见 [设备品质验收](docs/quality/device-matrix.md)，跨端文件/LAN 互操作仍见 [契约验收](docs/contracts/acceptance.md)。现有发布目录中的 APK 与 macOS ZIP 是历史构建，不能代表当前代码或作为本轮新版继续分发。后续顺序见 [三端原生路线图](ROADMAP.md)。

局域网采用 [握手 v1.1](docs/contracts/lan-handshake-v1.1.md)：六位 PIN，接收方发挑战、发送方证明 PIN 知识，payload 使用 HMAC 完整性校验；备份内容未做端到端加密，仅用于可信局域网。历史明文 PIN 首包与新版不兼容，双方需升级至同代构建；旧数据可经 JSON 恢复入口迁移。
