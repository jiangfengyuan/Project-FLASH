> 2026-11-15：此文保留原固定基线的历史记录；最新整合和验证状态见 [统一记录](../integration/unified-main-20261115.md)。

# 安全 LAN v2 候选验收记录 · 2026-11-06

状态：**适配候选已接线，正式启用未完成**。旧 LAN 永久停用，无降级。
用户指定“你自行审查”，协议组合按 Codex 自审处理，不声称外部独立审计。

## 已实现与验证

共享 Rust 状态机、C ABI、JNI、N-API 与四端候选适配已接入。双端主动核对三组十进制码；双方确认 MAC 前不会调用快照提供者。接收端验证认证结束帧并通过既有严格解析后发送认证 ACK，结果进入既有导入预览，提交时仍重校验和事务回滚。传输与导入分别呈现，未增加数据库或备份格式。

平台适配使用单调时钟、120 秒开启窗口、10 秒连接/网络空闲、60 秒人工核对及独立 120 秒传输上限。每次开启最多三次失败、一个活跃会话；重试建立全新密钥，代次隔离旧回调。后台、取消和结束清理连接、发现和 native handle。Harmony 分片同步喂入有界核心，避免异步队列积压正文。

| 检查 | 结果与边界 |
| --- | --- |
| 11 个架构原生最终链接 | 全通过，源码指纹一致；Apple 5、Android 4、Harmony 2；不代表真机运行 |
| FlashLAN Rust | 31 项通过；含独立固定向量、重放/反射/篡改/乱序/超限/截断、单方确认、UTF-8/BOM、计数器耗尽和 ACK 丢失 |
| FlashKit macOS 宿主 | 247 项通过，2026-11-06 复跑；含实际 C ABI/套接字双确认、严格拒绝及取消 |
| iOS 应用 | Xcode-beta build-for-testing 通过，2026-11-06 复跑 |
| iOS 模拟器运行 | 未取得成功回执；共享包测试启动等待并被中断，独立 iOS ABI 冒烟运行日志为空。保留待验，不能以 macOS 冒烟替代 |
| macOS 应用 | Xcode-beta xcodebuild test 通过（2026-11-01），后续共享控制器修复由最新 FlashKit 全量测试覆盖 |
| Android | test、assembleDebug、connectedDebugAndroidTest 通过；专用 Android 16 空白模拟器 16 项中 15 通过、1 项跨进程对端材料不足跳过；含真实 JNI/Socket 双确认测试 |
| HarmonyOS | hvigor 未签名 HAP 构建通过；主机 223 项中 219 通过、4 项 native 场景默认跳过 |
| Harmony 适配实际 N-API | 独立 Node 加载真实 C N-API + Rust 核心，4 场景通过：分片/双确认、严格拒绝、丢 ACK、核对时取消；不代表 HarmonyOS 运行时 |
| 解析器 fuzz | NDK libFuzzer 在专用 Android 模拟器完成 100000 次、max_len=4096、seed=1；无崩溃/断言失败，有限运行不构成安全证明 |
| 备份契约 | npm test 通过；未修改导入、合并、覆盖及回滚契约 |
| 权限/原生库打包 | 构建 Info.plist、解码 APK manifest 和 HAP module.json 通过旧协议禁止/v2 最小声明检查；APK 4 ABI 与原产物逐字节一致，HAP 2 ABI 经 SDK llvm-strip --strip-all 后逐字节一致 |
| 依赖记录 | Cargo.lock 79 个归档校验；完整许可证随 generated artifacts 归档；源码签名未独立验证的事实保留 |

修复并回归了 ACK 写入完成回调与发送方关闭的竞态：EOF 不产生成功，接收端等待写入结果或超时。修复 Android 清理时误调用 CoroutineScope.cancel 导致成功结果取消的问题。AppKit 专用色彩测试仅在可导入 AppKit 的平台编译，生产主题未改。

## 剩余正式门槛

四端真机两两双向 12 个方向及各端同平台互传全部待验。必须补齐最低支持系统、权限拒绝、锁屏/后台、重试、大文件、安装包签名后实际权限与运行时行为证据。HarmonyOS 设备上的 N-API 随机源、销毁和错误传递亦须实测。没有这些证据，不得更改三个平台的 disabled 常量或标记改造完成。故障回退仅停用 v2。

设备清单与原始日志保留在工作区 outputs，不提交个人设备名称或 UDID。2026-11-01 清单中 Apple 实机 unavailable、Android 仅专用模拟器、Harmony 为空；2026-11-06 刷新仍无可用 Apple 实机，adb 无设备、hdc 为空；结果另存 outputs/lan-v2-20261106。无完成的真机矩阵证据。

## 证据与复现

[原生及安装包摘要](evidence/lan-v2/native-provenance-20261106.json)记录核心源码指纹、11 个构建报告及 APK/HAP 原生库摘要；[构建说明](../../shared/FlashLAN/README.md)包含固定依赖、全架构构建与许可证打包步骤。

原始日志：工作区 `outputs/lan-v2-continuation-20261101/`。最新复核日志归档到 `outputs/lan-v2-20261106/`。这些是本地证据，不是 CI、签名发布或真实设备互传凭证。既有 ios-c5/c6 截图和截图脚本修改保留，不纳入本批提交。
