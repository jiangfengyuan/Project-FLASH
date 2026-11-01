# iOS 功能收口检查点 · 2026-10-30

状态：构建与自动测试通过；完整界面/无障碍验收未完成，不授予正式发布验收。

## 源码与交付

- 起点 `aa18464`。保留原有截图脚本修改及 ios-c5/ios-c6 未提交证据；本轮未覆盖它们。初始差异存于交付目录 `initial.patch`、`initial-status.txt`。
- 本轮修复：`flash://today`、`flash://ideas` 关闭遮挡目标页的搜索/快速记录弹层；未知链接保留当前弹层。快速记录关闭仍走原有草稿保存路径，实际草稿手势闭环待复验。
- 新增两项深链回归和一项 iOS 备份集成测试。集成测试使用 UUID 隔离磁盘目录，经过生产导出、文件读取、差异预览、覆盖、SwiftData容器重开和再导出，核对收藏、情绪强度、任务来源、现代时区及提醒时间。提醒重建注入空操作，不能证明系统提醒恢复或进程重启。
- Xcode-beta 27.2（27B5028f），Debug，`CODE_SIGNING_ALLOWED=NO`；未改变团队、权限、依赖、存储迁移或备份格式，无共享产品代码修改。
- 交付目录：`/Users/haydenjiang/Documents/DEV/flash-Alpha/outputs/ios-acceptance-20261030/`。包含 Products（App、扩展、测试包与 xctestrun）、ZIP、xcresult、原始日志与哈希清单。
- ZIP SHA-256：`03bc9ef0a352001fc0b11597f8b7a246395836da3a2c0f1402a7eecb12254ff0`。源码文件/产物逐项哈希见 [manifest](evidence/ios-acceptance-20261030/manifest.json)。构建时源码尚未提交；随后提交为 `78200cb`，逐项复核源码哈希与测试构建一致。manifest保留基线SHA、已验证提交及准确改动文件哈希。

## 本轮执行结果

| 验证 | 结果及边界 |
| --- | --- |
| FlashKit | 204 项 / 26 套件通过；共享逻辑主机测试，不是 iOS 设备UI |
| iOS完整套件 | 18 项通过，0失败/跳过/运行时警告；iPhone 18 Pro专用模拟器，iOS27.0 / 24A434，arm64 |
| 通用模拟器构建 | `build-for-testing` 成功，含FlashWidgetExtension |
| 搜索 | CUA从真实主页面点全局搜索，弹层打开无崩溃；真实RootView挂载与任务跨Tab路由测试通过；实际输入/结果点按未完成 |
| 备份 | iOS生产流水线文件往返与磁盘容器重开通过；文件选择器、系统分享UI、iOS↔macOS应用双向操作未完成 |
| 深链 | capture类别、today、ideas、未知链接和弹层清理回归通过；真实通知/小组件触发待验 |
| 记录/情绪/任务/回顾/Memory | 仓储、快速记录、提醒状态转换、周报等共享自动门禁通过；完整创建编辑/回链/滚动操作待验 |
| LAN | 沿用候选停用实现及通过的FlashKit停用测试；未重启旧传输服务 |
| 原有AX5修复 | 保留420c51c/4049a75/aa18464；本轮未重新授予视觉验收 |

新增备份测试首轮因Swift初始化参数顺序错误未编译；修正测试后完整18项通过，失败原日志保留为 `ios-final.log`。首次修复后17项测试日志为 `ios-tests.log`，最终18项为 `ios-verified.log`，不混用计数。

## 复现

从本加固工作树依次执行，环境均设置 `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer`：

```sh
cd shared/FlashKit
swift test --scratch-path /private/tmp/flash-ios-acceptance-20261030/swift-build
cd ../..
xcodebuild -project ios/Flash.xcodeproj -scheme Flash -destination 'platform=iOS Simulator,id=CC4C60DA-A92D-44A6-A90D-F47AEA86341D' -parallel-testing-enabled NO -derivedDataPath /private/tmp/flash-ios-acceptance-20261030/DerivedData test CODE_SIGNING_ALLOWED=NO
xcodebuild -project ios/Flash.xcodeproj -scheme Flash -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/flash-ios-acceptance-20261030/DerivedData build-for-testing CODE_SIGNING_ALLOWED=NO
```

安装交付App：`DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun simctl install <已启动模拟器UDID> <交付目录>/Products/Debug-iphonesimulator/Flash.app`。测试产物路径保留完整 Products 结构；运行测试使用其中xctestrun与匹配的模拟器。产物仅供模拟器，不能安装真机。

## 仍需完成的验收

当前仅有iOS27.0/27.1运行时，iOS18未安装。专用模拟器保留此前虚构记录与待办，无清空或重置。CUA点击搜索后输入操作遇到 `windowNotFoundAtPosition`；Raise、Zoom to Fit及Window菜单恢复尝试后，捕获又返回ScreenCaptureKit -3812。已请求用户将窗口置前恢复，未绕过工具输入限制。

窗口恢复后继续：实际搜索结果定位、快速记录草稿/取消/保存与重启；各模块非空CRUD、灵感转任务回链、回顾刷新；文件选择器导出/分享/标准与恢复导入/合并覆盖/取消；通知拒绝与通知动作、快捷指令、小组件刷新。再在紧凑和大屏、明暗、默认/AX5、键盘及减弱动态效果下操作，并开启VoiceOver验证遍历、错误反馈与焦点恢复。

iOS18、真机签名/通知/App Group/锁屏隐私、iOS↔macOS文件选择器双向、完整VoiceOver与设备性能均未完成。未合并、推送、打标签或发布；不能把本检查点描述为整个计划已验收完成。
