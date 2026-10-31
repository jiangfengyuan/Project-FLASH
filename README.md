# Flash Aero · 一闪

> 2026-10-31 整合候选：已合入最新 iOS 导航、分享扩展与 Spotlight，并保留加固修复。旧 LAN 仍停用，已清理仅供其使用的网络声明；Android 的 WorkManager 依赖仍合并 ACCESS_NETWORK_STATE，未为清理 LAN 强删调度框架能力。当前仅支持文件导出/系统分享；升级本端不会修复仍运行旧版本的另一端。详见 [整合与验收](docs/hardening/integration-20261031.md)。

闪过即留，一目了然。本地优先的日志 / 灵感 / 情绪记录应用。

当前版本：**Flash Aero v0.1.0**。`Aero` 是 v0 Alpha 阶段的版本代号；
首个正式版将统一命名为 **Flash Pulse v1.0.0**。

没有账号、没有后端——数据默认只存在你自己的设备上；换设备可通过 JSON 文件。
旧版局域网直传因安全风险暂时停用，请使用文件备份或系统分享。

[爱发电主页](https://ifdian.net/a/HEY10086D)

![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg)

## 平台

| 平台 | 技术栈 | 状态 |
| --- | --- | --- |
| Android | Kotlin + Jetpack Compose + Material 3 + Room | Flash Aero v0.1.0 |
| macOS | SwiftUI + SwiftData，universal2（arm64 + x86_64） | Flash Aero v0.1.0 |
| HarmonyOS | ArkTS + ArkUI + 加密 RDB + Preferences 设置存储，纯原生 HAP | Flash Aero v0.1.0 |
| iOS | SwiftUI + SwiftData，iPhone，iOS 18+（与 macOS 共用 FlashKit） | 开发中（Alpha，未发布） |

历史上有过 React + Capacitor 的 Web/混合版，已退役（git 历史可查），
本仓库现在包含 Android、macOS、HarmonyOS 三个纯原生工程，以及开发中的 iOS 工程（与 macOS 共用 `shared/FlashKit`）。

## 功能

- **快速记录**：macOS 有菜单栏伴侣（按回车保存），Android 首页有快速创建 FAB；`!!` 语法标记重要度；
- **日志 / 灵感**：时间线、搜索、标签与日期筛选、编辑删除；
- **情绪**：七级选择（macOS / HarmonyOS 为滑块，Android 为 emoji 按钮）+ 子情绪标签 + 备注，周趋势与统计图表；
- **日历**：日志与情绪按日聚合的月历视图；
- **回顾**：本周/本月/近 30 天/近 90 天窗口、每日活跃度、与前一窗口的趋势洞察、情绪分布，以及页内趋势/日历切换；
- **备份与传输**：JSON 导出 / 严格导入（合并或覆盖）、系统分享。旧版局域网发送/接收已暂时停用；点击入口会说明替代方式，不启动发现、监听或连接。四端候选现读写既有分区 schema 1/2，Android 使用获批的增量 Room4→5，保留新增可空字段；实际 app/真机导入矩阵未完成，不能宣称全部设备互读。[实际验收与限制](docs/contracts/acceptance.md)。

2026-10-25 加固进行中：现行 LAN v1.1 的公开 CHALLENGE 即释放完整明文备份、离线猜 PIN、未认证错误结束会话等缺陷已复核。用户批准本轮暂时停用旧协议，历史实现在测试目标内保留回归，应用中没有启用开关或不安全回退。替代协议尚未选定，也未添加密码库。见 [加固基线](docs/hardening/baseline-2026-10-24.md)、[LAN 决策与停用边界](docs/hardening/lan-v2-decision.md)、[时区/schema 兼容阻塞](docs/hardening/compatibility-blockers.md)。

加固审查交接见 [当前报告与未验证项](docs/hardening/review-handoff.md)；[Release 实测](docs/hardening/performance.md) 仅覆盖明确记录的共享 macOS host 工作负载，[下一 beta UI 提案](docs/hardening/next-beta-ui-plan.md) 仅规划与部分截图基线，尚未实施视觉改版。

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

### iOS（开发中）

iPhone、iOS 18+，与 macOS 共用本地 Swift Package `shared/FlashKit`（数据层、领域逻辑、设计语言与大部分页面）。
功能已对齐 macOS（此刻 / 记录 / 日志流 / 情绪 / 日历与任务 / 回顾 / Memory / 搜索 / 设置与备份），
并有 iOS 增强：快速记录（Liquid Glass 常驻入口、控制中心控件、Siri 与快捷指令）、灵感提醒通知、
主屏与锁屏小组件、缩放转场与触感反馈：

```bash
cd ios
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -scheme Flash -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
cd ../shared/FlashKit && DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
```

详见 [ios/README.md](ios/README.md) 与 [shared/FlashKit/README.md](shared/FlashKit/README.md)。

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
├── ios/         # 原生 iOS 工程（iPhone，开发中）
├── shared/      # macOS / iOS 共用 Swift Package（FlashKit）
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
