# Unified main · 2026-11-15

按所有者授权整合本地和 GitHub，并在验证后更新 main；不是正式发布或完整产品验收。

## 输入与取舍

| 输入 | 固定提交 | 处理 |
| --- | --- | --- |
| 本地 Paper Alpha | ebe9b7dbeabc184d1301c840ec1f0a9480ae55d2 | 产品基线，包含原工作树归档及近期安全/存储修复 |
| 远程 main | 65c9212864584c0544bcf80caddb06323801fc8e | 合入历史，保留已确认的 Standard Icon |
| 备份 followups | ad31e057a72187da9fe69970a4ce81df8ccb1301 | 协调重复实现，补严格 UUID/日期结束校验、时区出口别名、Harmony 混淆及 merge upsert |
| PR #5 UI | 3b4d71ef349c964c346a275f9427cc59b62aafee | 适配对齐、四端新引导和辅助功能；保留当前 Paper 设计、版本、图标和锁定/资料库，不恢复已删除的旧浮动 UI |
| PR #6 文档 | e679dfbbc08cbd010222bd61d5f8489fffa665ec | 保留历史报告和标准草案，未激活根级代理指令 |
| 本地 LAN v2 | e942d9af8616e6b2438dd3adab91b6e9f1f16e8a | Rust/原生桥/四端接线纳入，所有生产开关 false；旧 PIN wire 禁用 |

其他本地 hardening、wip、Warm-Crafted、iOS native 及历史 PR #1/#2/#3/#4 已通过上述历史包含；不重复恢复旧实现。各来源为 merge parent 或祖先，可用 git merge-base --is-ancestor 核对。整合期间建立 archive/pre-unify-20261115，保留原分支，不改写提交历史。

## 验证

- Android：Gradle test（Debug/Release）和 assembleDebug 通过。
- Apple 共享包：315 项全套测试通过；新增引导重看不清除锁定/辅助功能偏好回归后 SettingsStore 11 项通过。
- iOS：generic Simulator build-for-testing，主应用/Share/Widget 编译通过。
- macOS：xcodebuild test 通过，保留应用锁 sheet 宿主回归。
- HarmonyOS：300 项主机测试中 296 通过、4 项 native 场景按设计跳过；unsigned Debug HAP 原生构建通过。
- 备份契约 120 项通过；既有 938 条本地化生成一致性、旧 LAN 隔离和 diff 检查通过。
- 本机未安装 Xcode-beta，使用已安装的 Xcode.app。LAN 忽略目录里的原生产物从既有候选工作树复制前校验核心源码指纹和 manifest 的 188 个产物/notice 摘要；原生二进制未入库。新 checkout 仍需按 shared/FlashLAN/README.md 生成产物，不能把构建成功视为设备互通。
- 日志保存在工作区 outputs/unified-main-20261115；早期失败日志与最终通过日志分开保留。GitHub CI 以推送后的实际运行状态为准，不以本地结果冒充。

## 持续限制

此前 Paper Alpha 的默认 v4 与 Android/Harmony v2 完整备份不对称、旧 macOS 库兼容线索、Android Release 签名/真机与系统集成验收仍需后续工作；本次没有改成降级丢元数据，也没有发布安装包或创建 tag。新增引导/辅助功能和 LAN 候选文案仍需完整语言及读屏/真机体验复核，938 条生成检查只覆盖既有目录，不能代表新增文案全部完成翻译。LAN 真机矩阵未满足，生产门控不得开启。

旧审查报告中的“分支未合入 main/尚无 LAN 候选接线/CI 未含 iOS 编译”等描述属于其固定日期基线，当前状态以本文件和 main 源码为准。标准草案仅为建议，采用和激活另行决定。
