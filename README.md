<p align="center">
  <img src="assets/brand/flash-standard-icon.png" alt="Flash 一闪 App 图标：叠放的暖色纸张、手写 Make It Possible 与一支铅笔" width="160" />
</p>

<h1 align="center">Flash 一闪</h1>

<p align="center">
  <strong>闪过即留，一目了然。</strong><br />
  本地优先的日志、灵感、情绪与任务记录应用 —— Android · iOS · macOS · HarmonyOS 四端原生实现
</p>

<p align="center">
  <img alt="Version" src="https://img.shields.io/badge/version-Flash_Aero_v0.1.0_(Alpha)-6C5CE7" />
  <img alt="License: MPL 2.0" src="https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg" />
  <img alt="Platforms" src="https://img.shields.io/badge/platforms-Android_|_iOS_|_macOS_|_HarmonyOS-lightgrey" />
</p>

---

Flash 帮你在念头闪过的那一刻把它留下：一句日志、一个灵感、一次情绪、一项待办。
**没有账号，也没有后端** —— 所有数据默认只保存在你自己的设备上；换设备时用 JSON 备份文件，
或在同一局域网内用六位 PIN 临时配对直传。

> **当前状态：Alpha。** 版本 **Flash Aero v0.1.0**（`Aero` 是 v0 阶段代号；首个正式版将命名为 **Flash Pulse v1.0.0**）。
> 功能主体已在四端实现，设备品质验收、跨设备互传真机验收与正式签名分发仍在进行，详见[项目状态](#项目状态)。

## 目录

- [功能](#功能)
- [平台与技术栈](#平台与技术栈)
- [快速开始](#快速开始)
- [测试与持续集成](#测试与持续集成)
- [数据、备份与隐私](#数据备份与隐私)
- [品牌与 App 图标](#品牌与-app-图标)
- [仓库结构](#仓库结构)
- [文档索引](#文档索引)
- [项目状态](#项目状态)
- [参与与支持](#参与与支持)
- [许可证](#许可证)

## 功能

| 模块 | 能做什么 |
| --- | --- |
| **此刻** | 问候与今日一览（今日记录、待办、最近情绪），快速捕捉输入框，最近闪念；未读灵感较多时提示梳理 |
| **记录** | 日志与灵感时间线；关键词搜索，按标签、重要度、日期、收藏筛选；`!!` 语法标记重要度；「待整理」批量改分类或标签；灵感一键转为任务（保留来源关联） |
| **情绪** | 七级情绪（滑杆或 emoji）+ 可选强度 + 子情绪（伤心 / 生气 / 难受）+ 备注；本周趋势与近期记录 |
| **日历与任务** | 日志、情绪、任务按日聚合的月历；任务截止时间、完成状态与本地系统提醒 |
| **回顾** | 本周、本月、近 30 天、近 90 天窗口；每日活跃度、与上一窗口的趋势洞察、情绪趋势与分布 |
| **Memory** | 规则聚合的周报：本周计数、情绪概览、亮点，可按周翻看 |
| **备份与传输** | JSON 导出 / 导入（差异预览后合并或覆盖）、损坏或旧版备份的恢复入口、系统分享、局域网 PIN 配对直传 |
| **新手引导** | 首次安装四步引导：欢迎 → 能做什么 → 隐私 → 偏好（外观与辅助功能）；每步可跳过，可在「设置 › 辅助功能」重新查看 |
| **辅助功能** | 应用内「减少动态效果」（与系统设置取或）；iOS / Android 应用内文字大小；iOS 触感反馈开关；HarmonyOS 文字大小跟随系统；全端读屏标签与选中状态 |

### 各端特色

- **macOS**：⇧⌘Space 全局快捷键唤起 Quick Capture（可改键）、菜单栏伴侣、⌘K 全局搜索、⌘1–⌘7 模块切换、桌面小组件。
- **iOS**：Liquid Glass 常驻快速记录入口（iOS 26+）、控制中心控件、Siri 与快捷指令、灵感提醒推送、主屏与锁屏小组件、缩放转场与触感反馈。
- **Android**：Material 3 与玻璃拟态两种界面风格、快速创建悬浮按钮、Android 13+ 主题图标。
- **HarmonyOS**：手机 / 折叠屏 / 平板响应式导航、桌面服务卡片、星闪 / 实况窗 / 闪控球等系统能力的合规检测页。

## 平台与技术栈

| 平台 | 技术栈 | 最低系统 | 工程 |
| --- | --- | --- | --- |
| Android | Kotlin · Jetpack Compose · Material 3 · Room | Android 8.0（API 26），目标 API 36 | [`android/`](android/README.md) |
| iOS | SwiftUI · SwiftData，仅 iPhone | iOS 18（iOS 26 启用 Liquid Glass） | [`ios/`](ios/README.md) |
| macOS | SwiftUI · SwiftData，universal2（arm64 + x86_64） | macOS 15 | [`macos/`](macos/README.md) |
| HarmonyOS | ArkTS · ArkUI · 加密 RDB · Preferences，纯原生 HAP | HarmonyOS 5.0（API 12），目标 SDK 26.0.0 | [`harmonyos/`](harmonyos/README.md) |

iOS 与 macOS 共用本地 Swift Package [`shared/FlashKit`](shared/FlashKit/README.md)（数据层、领域逻辑、设计语言与大部分页面）。
三端（Android、Apple、HarmonyOS）通过同一份备份协议互通，协议由仓库内的契约测试统一约束。
历史上的 React + Capacitor Web/混合版已退役，可在 git 历史中查阅。

## 快速开始

### Android

需要 JDK 17+ 与 Android SDK（API 36）。

```bash
cd android
./gradlew :app:assembleDebug        # 输出 app/build/outputs/apk/debug/app-debug.apk
./gradlew :app:testDebugUnitTest    # 单元测试
```

`settings.gradle.kts` 在本地默认优先使用国内镜像；境外网络或 CI 中设置 `CI=1` 即直连 Google / Maven Central。
发布签名见 [`scripts/generate-android-keystore.sh`](scripts/generate-android-keystore.sh) 与 [android/README.md](android/README.md)。

### iOS

需要 Xcode 26（本仓库日常使用 Xcode beta；使用正式版 Xcode 时去掉 `DEVELOPER_DIR` 前缀）。

```bash
cd ios
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -scheme Flash -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

### macOS

```bash
cd macos
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -scheme Flash -destination 'platform=macOS' build
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild test -scheme Flash -destination 'platform=macOS'
```

共享包测试：

```bash
cd shared/FlashKit
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
```

### HarmonyOS

需要 DevEco Studio 与 HarmonyOS SDK。可直接用 DevEco Studio 打开 `harmonyos/`，或命令行构建调试版 HAP：

```bash
cd harmonyos
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  assembleHap --mode module -p product=default -p module=entry@default \
  -p buildMode=debug --no-daemon
```

业务逻辑的主机测试无需 SDK，只要 Node.js：见下一节。

## 测试与持续集成

| 范围 | 命令 | CI |
| --- | --- | --- |
| 备份契约（三端共享夹具） + HarmonyOS 业务逻辑 | `npm ci --prefix scripts/backup-contract --ignore-scripts`<br />`node scripts/backup-contract/generate-cases.cjs --check`<br />`node --test scripts/backup-contract/contract.test.cjs harmonyos/tests/*.test.cjs` | ✓ |
| Android 单元测试与仪器测试构建 | `./gradlew :app:testDebugUnitTest :app:assembleDebugAndroidTest` | ✓ |
| macOS 单元测试 | `xcodebuild test -scheme Flash -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO` | ✓ |
| App 图标资源一致性 | `python3 scripts/brand/generate_app_icons.py --check` | — |

工作流定义见 [`.github/workflows/backup-contract.yml`](.github/workflows/backup-contract.yml)。
HarmonyOS 主机测试运行真实的控制器与存储源码，但使用平台替身，**不能代替真机验收**。

## 数据、备份与隐私

- **本地优先**：没有账号和服务器，数据保存在本机数据库中（HarmonyOS 使用加密 RDB）。
- **备份格式**：四端共用分区、带版本的 JSON 格式 `flash-backup-v2`，并兼容导入 v1：

  ```json
  { "version": "flash-backup-v2", "exportedAt": "...", "appVersion": "...",
    "notes": "", "schemas": { "logs": 1, "emotions": 1, "tasks": 1 },
    "data": { "logs": [...], "emotions": [...], "tasks": [...] } }
  ```

  标准导入严格校验，有任何问题都整体拒绝、不写入；「恢复损坏或旧版备份」入口逐条跳过非法记录并报告跳过数量。
  导入前会展示新增、修改、相同与仅本机存在的差异，再选择合并或覆盖。
  完整定义见 [docs/flash-backup-v2.md](docs/flash-backup-v2.md)，面向非技术读者的说明见 [docs/flash-backup-protocol-for-managers.md](docs/flash-backup-protocol-for-managers.md)。
- **局域网直传**（[握手 v1.1](docs/contracts/lan-handshake-v1.1.md)）：发送方生成随机六位 PIN（60 秒有效、最多尝试五次），
  接收方发起挑战、发送方证明知道 PIN，传输内容带 HMAC 完整性校验，成功后服务立即关闭；数据不经过任何 Flash 服务器。
- **请注意**：
  - 备份文件与局域网传输内容**均为明文，未做端到端加密**，请只在可信的设备与网络中使用。
  - 局域网 v1.1 与早期的明文 PIN 版本不兼容，两端需使用同一代构建；旧数据可通过 JSON 恢复入口迁移。
  - 跨设备互传（文件与局域网）尚未完成真机验收，见 [契约验收矩阵](docs/contracts/acceptance.md)。
- 快照备份与未来的自动同步（`flash-sync-v1`）分层设计，同步不会改变备份语义。

## 品牌与 App 图标

<img src="assets/brand/flash-standard-icon.png" alt="" width="96" align="right" />

官方图标为暖色叠放纸张、手写 “Make It Possible” 与一支铅笔。唯一主资源是
[`assets/brand/flash-standard-icon.png`](assets/brand/flash-standard-icon.png)，各平台资源全部由脚本派生：

- **iOS**：默认、深色、着色三种外观；清透外观由系统生成。
- **macOS**：按标准网格生成的 16–1024 尺寸。
- **Android**：自适应图标与 Android 13+ 主题图标专用单色剪影。
- **HarmonyOS**：1024 分层图标（前景 + 不透明背景）。

```bash
python3 scripts/brand/generate_app_icons.py            # 重新生成（需要 Pillow 与 NumPy）
python3 scripts/brand/generate_app_icons.py --check    # 校验
```

设计边界、各端规则与外观矩阵见 [官方图标规范](docs/brand/APP_ICON.md)。请勿手工修改派生图标。

## 仓库结构

```
.
├── android/              Android 原生工程（Compose）
├── ios/                  iOS 原生工程（iPhone）
├── macos/                macOS 原生工程（含小组件与单元测试）
├── shared/FlashKit/      iOS / macOS 共用 Swift Package
├── harmonyos/            HarmonyOS 原生工程（ArkTS + ArkUI）与主机测试
├── assets/brand/         品牌主资源（官方图标）
├── docs/                 协议、契约、品质验收与品牌规范
├── scripts/
│   ├── backup-contract/  备份契约夹具生成与校验
│   ├── brand/            App 图标派生与校验脚本
│   └── generate-android-keystore.sh
├── ROADMAP.md            路线图与验收门槛
└── LICENSE               MPL-2.0
```

## 文档索引

| 文档 | 内容 |
| --- | --- |
| [ROADMAP.md](ROADMAP.md) | 各端现状、发布候选验收门槛与后续计划 |
| [docs/flash-backup-v2.md](docs/flash-backup-v2.md) | 备份协议规范 |
| [docs/contracts/](docs/contracts/README.md) | 契约夹具、JSON Schema、LAN 握手 v1.1、跨端验收矩阵 |
| [docs/quality/device-matrix.md](docs/quality/device-matrix.md) | 设备品质验收矩阵 |
| [docs/brand/APP_ICON.md](docs/brand/APP_ICON.md) | 官方图标规范与各端集成 |
| [docs/harmonyos7-adaptation.md](docs/harmonyos7-adaptation.md) | HarmonyOS 系统能力适配记录 |
| [docs/three-platform-refactoring-and-gap-remediation.md](docs/three-platform-refactoring-and-gap-remediation.md) | 三端重构与差距补齐记录 |
| 各端 README | [Android](android/README.md) · [iOS](ios/README.md) · [macOS](macos/README.md) · [HarmonyOS](harmonyos/README.md) · [FlashKit](shared/FlashKit/README.md) |

## 项目状态

| 平台 | 当前情况 | 待完成 |
| --- | --- | --- |
| Android | Debug 可构建，单元测试通过 | 设备品质矩阵、仓库外新密钥正式签名 |
| macOS | 本机可运行 | 小组件数据联通、Developer ID 签名与公证 |
| iOS | 模拟器可运行 | 真机小组件与分发签名、设备品质矩阵 |
| HarmonyOS | 主机测试与未签名 HAP 构建通过 | 真机验证、证书签名、受限系统能力准入 |

- **验收与发布**：自动测试通过不等于跨设备互操作已通过。发布前的验收门槛与优先级见 [ROADMAP.md](ROADMAP.md)。
- **历史构建**：现存的历史 APK / macOS ZIP 不代表当前代码，不应继续分发。

## 参与与支持

项目目前由个人维护，处于 Alpha 阶段。欢迎通过 [Issue](https://github.com/jiangfengyuan/Project-FLASH/issues) 反馈问题与建议；
提交改动前请运行上文对应平台的测试，涉及备份格式的改动需同步更新契约夹具。

如果 Flash 对你有帮助，欢迎在 [爱发电](https://ifdian.net/a/HEY10086D) 支持开发。

## 许可证

Copyright © 2026 Fengyuan Jiang

本项目以 [Mozilla Public License 2.0](LICENSE)（MPL-2.0）发布：可以自由使用、修改和再分发（包括商用）；
对本仓库已有文件的修改需以相同条款开源，你新编写的独立文件不受此限。
商标及与本项目无关的素材不在授权范围内。
