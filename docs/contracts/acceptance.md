# 跨端契约执行与设备验收

执行顺序：共用测试底座 → 差异修复 → 严格导入导出 → 合并与回滚门禁 → 真机验收 → 性能与其他遗留项。

## 代码与自动测试

- Android JUnit、macOS Swift Testing、HarmonyOS 主机测试读取 `fixtures/` 同一份文件；参考 Ajv 校验器检查其 Schema 和语义期望。
- `fixtures/cases.json` 是正反例清单。`generate-cases.cjs --check` 检查生成结果是否与提交样例一致。
- 共用负例包括重要性、emoji、数组输入上限、元信息、未知字段/分区、布尔数字、非法日期、年份下溢、未知偏移、命名时区、混合 due、重复 ID、任务时间先后。
- `valid-boundaries.json` 覆盖 200 UTF-16 单元标题、亚毫秒截断后比较和大偏移；`valid-time-zones.json` 覆盖 UTC、上海、纽约、柏林与 Etc/GMT+1。
- `merge-local.json`、`merge-incoming.json` 是两个初始快照；`merge-expected.json`、`overwrite-expected.json` 是预期结果。比较时忽略记录顺序、元信息、缺省与 null 的差别。
- 合并样例覆盖：日志同 ID 文件胜出、不同 ID 内容相同仍保留、情绪空分区合并保留/覆盖清空、任务本机较新/文件较新/时间相同/各端独有。
- macOS 使用实际 SwiftData 内存容器；Android instrumentation 使用实际 Room/SQLite 内存数据库与失败触发器，并在 Android 系统 JSON 实现上执行全部共用样例。HarmonyOS Store 测试使用显式 RDB 替身，不能替代原生 RDB 验收。
- Android 提醒重建检测系统通知与提醒频道是否启用；有待恢复提醒但权限不可用时抛错，由导入界面报告“数据已导入，提醒恢复失败”。权限测试注入不可用状态，不修改设备通知设置。

## 正式入口

- 标准文件导入和局域网接收调用 `parseStrict`，只接受合格 v2 完整快照；失败不进入写库。
- “恢复损坏或旧版备份”独立调用 `parseRecovery`，允许旧 v1、缺失旧元信息，跳过非法/重复记录和输入上限以外记录，显示跳过数量。它不修复无法解析的 JSON 语法；原文件不修改。
- 恢复也拒绝未知字段、未知分区和版本，不猜测其语义。需要升级客户端处理的文件不能靠恢复流程静默丢弃信息。
- 三端正式导出先验证数据，所有时刻统一 UTC 毫秒；macOS 正式入口使用 `exportStrictJSON`。不能生成本端标准入口无法导入的备份。
- 用户仍需预览并选择合并/覆盖。数据提交失败保持数据库原状；提醒重建失败单独报告数据已提交但提醒恢复失败。
- 三端严格入口统一拒绝 JSON 对象重复键；Android 标准入口还额外拒绝 org.json 宽松接受的非 JSON 语法。

## CI

`.github/workflows/backup-contract.yml` 定义 Schema/HarmonyOS 主机测试、Android 单元测试与测试包构建、Android 模拟器原生数据库测试、macOS 测试四个 job。

仓库管理员还需在分支保护中将这些检查设为 required，才会阻止绕过失败检查合入。本地新增工作流不等于远端工作流已运行或分支保护已开启。HarmonyOS 原生 HAP 构建目前使用本机 DevEco SDK；未配置对应 CI runner。

## 本地验证记录（2026-09-05）

- Node 参考契约与 HarmonyOS 主机测试：109 项通过；随后新增的 4 项合并黄金文档 Schema 检查也通过（共 113 项）。
- macOS：最新 Xcode 测试汇总 74 项通过、0 失败（参数化用例按汇总口径计数）。
- HarmonyOS：DevEco 原生 ArkTS 检查与未签名 HAP 构建通过。
- Android：38 项 JVM 测试通过；补齐 `AndroidJUnitRunner` 依赖后，API 36 模拟器上的 7 项原生测试全部通过，覆盖共用样例、合并/覆盖、失败回滚、数据库迁移与通知权限失败。模拟器是只读临时会话，测试结束后已关闭。
- 当前没有 Android 真机连接，且用户无 HarmonyOS 真机。只读模拟器临时会话用于自动测试，不计作真机互传。

## 设备前置条件与证据

只使用测试安装和以下虚构样例，避免覆盖日常数据。先保存当前测试安装的备份；不要对日常数据库执行故障注入。

每次记录：应用 commit/构建时间、设备型号、系统版本、时区、传输方向、文件 SHA-256、操作、预期、实际、截图/日志位置。原始备份含正文时不进入公开 CI 日志。

| 方向 | 文件/分享 | 局域网 | 合并/覆盖 | 回滚 | 提醒重建 |
| --- | --- | --- | --- | --- | --- |
| Android → macOS | 待验收 | 待验收 | 待验收 | 待验收 | 待验收 |
| macOS → Android | 待验收 | 待验收 | 待验收 | 待验收 | 待验收 |
| Android ↔ HarmonyOS | 缺设备 | 缺设备 | 缺设备 | 缺设备 | 缺设备 |
| macOS ↔ HarmonyOS | 缺设备 | 缺设备 | 缺设备 | 缺设备 | 缺设备 |

用户目前只有 Android 手机，没有 HarmonyOS 设备。首次 ADB 检查无已连接设备；待连接并在手机授权 USB 调试。macOS 本机测试已运行，但不能据此填写端到端互传通过。

## 逐项操作

1. 接收端用 `merge-local.json` 初始化测试安装；发送端用 `merge-incoming.json` 初始化，再从发送端正式导出。
2. 文件或系统分享传入接收端，标准导入预览，选择合并。再导出并与 `merge-expected.json` 逐字段语义比较。
3. 重置接收端测试数据，重复操作并选择覆盖；结果应等于 `overwrite-expected.json`。
4. 在另一方向重复 1–3，再用局域网接收重复；覆盖前核对将删除的本机独有记录。
5. 接收 `invalid-importance-range.json`、`invalid-unknown-section.json`、`invalid-array-cap.json`：标准导入必须失败，导出快照保持不变。恢复重要性负例应明确跳过一条日志；未知分区恢复也必须失败。
6. 测试安装中运行原生事务失败注入：在前面分区已更新后令任务写入失败；数据库应完全回滚，随后成功写入不携带失败操作残留。Android 使用 `BackupContractRepositoryTest`；macOS 使用 `failedMutationsRollbackAndNeverLeakIntoLaterSave`。
7. 创建未来 5–10 分钟的定时任务再导出（不要依赖历史样例的提醒日期）；验证导入后提醒重建、覆盖后旧提醒移除、完成任务不重复提醒。撤销通知权限再导入，应提示“数据已导入、提醒恢复失败”，数据仍可查询。
8. 切换设备时区重试：全天日期不漂移，绝对时刻保持不变，通知按绝对时刻触发；纽约夏令时回拨时刻使用明确偏移。
9. 传输取消、错误 PIN、过期 PIN、传输中断后重试；未通过校验或未提交的内容不得出现在数据库。

## 后续顺序

真机验收完成后，再处理 HarmonyOS 原生设备级测试、查询索引/日期窗口和搜索性能：先记录 1k/10k/100k 数据下的查询耗时、主线程阻塞与内存，再按瓶颈修改，避免在契约验收期间同时改变持久化与读路径。

局域网加密握手、独立 `flash-sync-v1` 尚未启动，不属于本轮备份契约实现。支持不可信网络或自动同步前必须单独设计和验收。
