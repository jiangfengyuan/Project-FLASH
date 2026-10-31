# iOS 功能与加固分支整合 · 2026-10-31

本地候选分支：`codex/ios-integrated-candidate`。源码交付提交 `63d54f5c8b4300ec74b5ddcda44a6aa3b3c46681`；随后文档提交不改变已构建源码。没有推送、合并main、打标签、签名分发或操作Device Hub。

## 整合结果

- `b6fd83f` 为双父合并，保留 `996df04` 与 `6fba4f8` 历史。保留最新情绪一级入口/Memory次级入口、分享扩展、Spotlight、临时存储保护和隐私行为；同时保留加固分支的严格输入/时区/schema2/原子导出/取消与回滚防护。
- 冲突逐项处理：备份流水线同时检查临时存储与取消；保留两种错误类型；日志使用功能分支的私密日志接口；LAN入口沿用停用前置处理。快速记录保留多行输入/字数提示/测量高度，同时辅助字号使用大面板、滚动内容和键盘安全区操作栏。
- 自动合并后的搜索sheet仍注入同一FocusRouter；today/ideas深链仍关闭遮挡弹层，新导航回归与真实搜索装配测试通过。
- `9d875d4` 清理旧LAN声明并新增静态门禁。`63d54f5` 增加两项失败边界回归：失败提交不发布Spotlight回调；分享收件箱写库失败保留文件，成功重试仅写入一次。全套测试重新执行。
- 原有未提交截图脚本与ios-c5/ios-c6证据未纳入提交或覆盖；基线差异/状态随交付保存。

## LAN 权限处置及例外

历史网络实现仅留在测试夹具；生产控制器继续禁用：只有状态与替代提示，不监听/发现/连接，不生成PIN，不先获取快照或导出备份，无运行时恢复开关。旧实现仅在历史测试目标。

| 声明 | 处置及依据 |
| --- | --- |
| iOS/macOS Bonjour服务及本地网络说明 | 已移除；生产源码无旧发现调用；文件选择器、系统分享、Core Spotlight与App Group不由Flash直接建立LAN连接 |
| macOS network.client/server | 已移除；保留App Sandbox及用户选择文件读写；源码未发现URLSession或NW连接调用 |
| Android INTERNET/多播/NEARBY_WIFI_DEVICES | 已移除；生产入口无对应网络/权限请求调用，APK权限检查通过 |
| Android ACCESS_NETWORK_STATE | 删除了App自己原有声明，但WorkManager2.10.1的Manifest仍合并此权限。该依赖用于任务提醒调度；本轮不通过tools:node强制覆盖第三方框架声明。不能声称最终APK无网络状态权限，也未证明当前无网络约束的任务一定需要该权限 |
| Harmony INTERNET | 已移除；保留提醒权限，最终HAP的module.json确认无INTERNET |

这不是移除所有系统网络能力或保证没有任何网络流量：系统分享等服务可自行联网，网络状态读取权限也不等于访问互联网权限。没有修改其他产品能力来追求权限数量为零。

升级无需数据迁移；旧系统授权不主动重置，当前新包无发现/监听代码。降级旧包会恢复旧漏洞，不是安全回滚。旧端仍有未认证下载、明文和离线猜PIN风险；仅升级另一端不会修复它。重建计划与各端权限重新声明条件见[独立设计](lan-rebuild-20261031.md)。

## 本轮验证

所有构建和测试串行执行，Xcode-beta27.2（27B5028f）；Apple不使用团队签名。

| 门禁 | 本轮结果 | 范围 |
| --- | --- | --- |
| FlashKit | **242/242**，31套件 | 先合并后240项通过；新增两项回归后242项通过，不相加 |
| iOS | **25/25**，0失败/跳过 | iOS27.0/24A434，iPhone18Pro专用CoreSimulator；搜索装配、路由、Spotlight、提醒状态及文件/磁盘重开等；分享扩展与小组件编译通过 |
| iOS generic build-for-testing | 成功 | 最终权限配置下重新生成通用模拟器App、扩展与测试产物 |
| macOS | **13/13**，0失败/跳过 | macOS27.2，主机App测试及小组件构建，不代表完整UI验收 |
| 契约 | **68/68**，生成夹具检查通过 | `npm test --prefix scripts/backup-contract`及generate-cases --check |
| Harmony主机 | **219/219** | Node原生代码loader/替身；不代表设备RDB |
| Android | Debug **93/93**、Release **93/93**，0失败/跳过 | `./gradlew test --rerun-tasks`强制实际执行；Debug APK构建成功，无原生设备测试重跑 |
| Harmony HAP | 未签名构建成功 | ArkTS/hvigor；27任务执行，6项缓存；无设备安装 |
| LAN声明与生产源码门禁 | 通过 | 源码及构建后的Info.plist、Android合并Manifest、Harmony打包module.json；WorkManager例外如上 |
| 打包检查 | 通过 | APK权限、HAP最终模块；Apple主可执行文件未找到旧发送/接收/握手类型符号，静态检查不替代设备流量观察 |

失败/缓存记录保留：首次Android `test assembleDebug`成功但单测为UP-TO-DATE；显式 `testReleaseUnitTest`调用触发既有Release签名保护而拒绝，未修改保护或填入凭据；随后使用仓库规定的 `test --rerun-tasks`入口实际跑过全部186项。原始日志均保留，不把首次缓存结果冒充实际重跑。

Node使用原工作区已有的锁定依赖，通过NODE_PATH/FLASH_TYPESCRIPT_PATH引用；未安装新运行时依赖。各工具链路径、命令、构建与测试日志在交付目录中。当前受管安全扫描未重新执行，历史扫描仍只覆盖其原始快照，本次门禁不是完整安全审计。

## 产物、证据和复现

交付目录：`/Users/haydenjiang/Documents/DEV/flash-Alpha/outputs/ios-integrated-20261031/`。

- `Flash-integrated-simulator.zip`：通用模拟器Products，含App、FlashShareExtension、FlashWidgetExtension和测试包。SHA-256：`3dbfa45063bec37931fe6f17776cd0bddee62e18e7f13031aeb52533d78b011d`。不能安装真机。
- `app-debug.apk`、`entry-default-unsigned.hap`为其他端构建验证产物，不是正式分发包。
- `ios-tests.xcresult`、`macos-tests.xcresult`、原始日志、Android计数、全部源码与产物逐文件SHA-256在交付目录；紧凑收据见[evidence](evidence/integration-20261031/manifest.json)。manifest绑定源码提交，不含待验UI通过结论。

复现核心入口：

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --package-path shared/FlashKit
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project ios/Flash.xcodeproj -scheme Flash -destination 'generic/platform=iOS Simulator' build-for-testing CODE_SIGNING_ALLOWED=NO
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project ios/Flash.xcodeproj -scheme Flash -destination 'platform=iOS Simulator,id=CC4C60DA-A92D-44A6-A90D-F47AEA86341D' -parallel-testing-enabled NO test CODE_SIGNING_ALLOWED=NO
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -project macos/Flash.xcodeproj -scheme Flash -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
python3 scripts/check-lan-quarantine.py
```

Android使用Android Studio JBR与已安装SDK，执行`test --rerun-tasks`及`assembleDebug`；Harmony命令沿用其README。静态门禁可传 `--ios-app`、`--macos-app`、`--android-manifest`、`--harmony-module`检查构建产物。

## 保留的未验收项

不操作Device Hub；完整界面交互、VoiceOver/TalkBack、最低iOS18、真实文件选择器双向互传、真机分享扩展/App Group/Spotlight跳转/通知/锁屏保护、Harmony原生RDB与设备性能均仍需验证。安全LAN重建只是设计建议，尚未选定/集成新依赖，未启用新协议。本候选可以用于后续验收，不能描述为四端正式发布或iOS全部验收完成。
