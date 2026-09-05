# Flash 首版跨端数据契约

> 契约修订：0.1.0（草案）｜日期：2026-09-05<br>
> 范围：Android / macOS / HarmonyOS 的完整备份快照<br>
> 状态：三端已接入共用样例、严格标准导入/导出与独立恢复入口；设备互传与远端 CI 仍待验收。详见 [执行与验收记录](acceptance.md)。

给非技术读者的说明见 [经理版协议说明](../flash-backup-protocol-for-managers.md)。已有格式背景见 [backup v2](../flash-backup-v2.md)。本目录是面向工程实现与验收的首版规范。

## 1. 版本和边界

- 继续使用现有文件版本 `flash-backup-v2`，三个分区仍为 `logs:1 / emotions:1 / tasks:1`。`0.1.0` 是本次契约草案修订号，不是新的文件版本，也不是客户端版本。
- [flash-backup-v2.schema.json](flash-backup-v2.schema.json) 使用 JSON Schema Draft 2020-12；`$id` 是标识符，不是需要联网获取的地址。
- 文件是完整快照，不是增量消息；支持文件、系统分享和现有可信局域网传输，不规定各端 UI、数据库表、Socket 握手或通知 API。
- 本次不定义账号、云端 API、自动同步、加密或删除传播。`flash-sync-v1` 仍只是预留设计，不能交给本 Schema 校验或现有备份导入器处理。
- 此 Schema 定义“严格互通文件”，不是现有“跳过坏记录、尽量恢复”的导入算法。不能直接用它替换旧解析器而不评估兼容性与交互变化。

## 2. 文件结构

```json
{
  "version": "flash-backup-v2",
  "exportedAt": "2026-09-05T00:00:00.000Z",
  "appVersion": "0.1.0",
  "notes": "",
  "schemas": { "logs": 1, "emotions": 1, "tasks": 1 },
  "data": { "logs": [], "emotions": [], "tasks": [] }
}
```

六个顶层字段全部必填；`appVersion` 只作来源说明，不用它决定兼容性。`notes` 为文件备注，可以为空。三个数据数组即使没有记录也必须存在。文件不能包含系统通知 ID、权限、数据库主键序号、配对 PIN 或本机文件路径等本地实现状态。

所有对象都禁止未声明字段。特别是未知分区不能读取后悄悄丢弃。此限制是本次提出的严格契约，正式标准入口执行此限制；恢复入口也拒绝未知内容。

## 3. 记录字段

以下“可选”表示字段可缺省或为 `null`；空字符串仍是有值文本，不能自动等同于缺省。

| 分区 | 必填字段 | 可选字段 |
| --- | --- | --- |
| 日志/灵感 `logs` | `id`、`content`、`colorTag`、`category`、`importance`、`createdAt`、`recordDate` | 无 |
| 情绪 `emotions` | `id`、`level`、`createdAt`、`recordDate` | `subEmotion`、`note`、`status` |
| 任务 `tasks` | `id`、`title`、`colorTag`、`importance`、`due`、`createdAt`、`updatedAt` | `notes`、`reminderAt`、`completedAt` |

取值规则：

- `id` 沿用三端现有 UUID 字符串外形，不额外限制 UUID 版本位。唯一性范围为单个分区，按大小写敏感字符串比较；新建 UUID 建议小写，但导入时不能擅自小写化已有 ID，否则可能改变记录身份。
- `colorTag`：`urgent / inspiration / daily / memo / emotion / idea`；`category`：`log / idea`。不额外绑定颜色与分类。
- `importance`：整数 0–4，越界不自动截断；`level`：整数 -3–3；`subEmotion`：`sad / angry / uncomfortable` 或空。沿用当前模型，不追加“只有负面情绪才能有子情绪”的限制。
- 任务标题去除首尾空白后不能为空；原始长度不超过 200 个 UTF-16 单元。正文、备注、情绪状态和文件备注不超过 100,000 个 UTF-16 单元。此处采用 Android/ArkTS 的计数口径，emoji 通常占两个单元，不等于用户看到的字数。
- Schema 的 `maxLength` 按 Unicode 码点计数，不能单独落实 UTF-16 上限；参考校验器补充该检查。这是 JSON Schema 的标准行为，而非平台选项。[标准说明](https://json-schema.org/draft/2020-12/json-schema-validation)

### 日期、时刻和时区

- `recordDate` 和全天任务 `due.date` 是公历日期 `YYYY-MM-DD`，必须真实存在，限定 0001–9999 年。不能转成“零点 UTC”再随设备时区漂移。
- 时刻必须有时区：允许大写 `T`、`Z`，或显式 `±HH:MM` 偏移；秒后可无小数或有 1–9 位小数。小时 0–23、分/秒 0–59；偏移小时 0–23、分钟 0–59。拒绝闰秒、未知偏移 `-00:00` 和无时区文本；转 UTC 后年份也须处于 0001–9999。
- 规范化输出统一为 UTC、固定毫秒，例如 `2026-09-05T00:00:00.000Z`；超过三位的小数截去、不四舍五入。比较任务时间必须先按此精度规范化，不能比较带不同偏移的原始字符串。
- `updatedAt >= createdAt`。不强制提醒早于截止、不强制完成时间晚于创建；这些是产品操作规则，不能在首版协议里新增限制导致既有数据失效。
- 定时任务同时保存绝对时刻与命名时区；后者应是三端都支持的 IANA 标识（包括 `UTC`）。本地参考校验器只能证明当前 Node/ICU 支持，不能证明三端时区库一致；跨端时区样例仍须补齐。

```json
{ "kind": "allDay", "date": "2026-09-07" }
```

```json
{ "kind": "dateTime", "at": "2026-09-06T01:00:00.000Z", "timeZone": "Asia/Shanghai" }
```

`due` 必须且只能是其中一种形态。可选空字段在语义比较时将缺省与 `null` 视作等价；规范化导出建议省略空字段。不比较 JSON 缩进、对象键顺序或记录数组顺序。

## 4. 三层校验与失败处理

| 层级 | 检查内容 | 处理原则 |
| --- | --- | --- |
| 文件层 | UTF-8、无 BOM、合法 JSON、总字节数 ≤ 52,428,800（50 MiB） | 读取时限流；失败不进入写库阶段 |
| Schema 层 | 版本、必填项、字段类型、枚举、范围、数组输入数每分区 ≤ 100,000、禁止额外字段 | 严格文件任一项失败即不合格 |
| 语义层 | 真实日期、规范化时间先后、UTF-16 长度、同分区重复 ID、时区支持 | 返回字段路径和原因，不静默更改或删除数据 |

必须开启并正确实现 `format` 校验。标准中 `format` 默认可能只是注解；只载入 Schema 不代表日期已经验证。`uniqueItems` 比较的是整个元素，不能替代按 `id` 查重，所以本 Schema 没有用它冒充记录唯一性校验。[JSON Schema 校验规范](https://json-schema.org/draft/2020-12/json-schema-validation)

严格校验通过不等于获得写库授权。正式导入仍须预览、让用户选择合并/覆盖，在持久化成功后发布状态。提醒重建是后续系统副作用；提醒失败应说明“数据已导入、提醒未全部恢复”，不能误报数据提交失败或完全成功。

兼容/修复导入应保留为独立流程：当前三端会跳过非法记录及后续重复 ID，并报告跳过数量。后续收紧时，建议把此行为明确标记为“部分恢复”，提供失败原因与原文件保留路径；涉及覆盖时必须突出将清空的本地数据。未知版本/分区不得走静默丢弃路径。独立恢复入口已实施，实际设备交互仍须按验收清单核对。

JSON 对象不得包含重复键。三端严格入口与参考文件校验器都会先扫描原始 JSON，并按解码后的键名拒绝重复（例如 `"notes"` 与 `"\u006eotes"` 也视为同名）；共享负例 `invalid-duplicate-key.json` 覆盖该规则。`validateDocument()` 接收的是已解析对象，无法补做此检查，也不检查文件编码/大小；文件入口必须用 `validateBytes()` 或相应流式实现。

## 5. 合并、覆盖和旧文件

| 情况 | 合并 | 覆盖 |
| --- | --- | --- |
| 本机独有记录 | 保留 | 删除 |
| 文件独有记录 | 加入 | 写入 |
| 同 ID 日志/情绪 | 文件版本胜出，无修改时间可比较 | 文件版本胜出 |
| 同 ID 任务 | 规范化后 `updatedAt` 较新者胜出；相同时文件胜出 | 文件版本胜出，即使更旧 |
| 某分区为空 | 不删除该分区本地记录 | 清空该分区 |

合并不是自动去重：不同 ID 即使内容相同也保留。备份没有删除标记，因此合并不能把另一台设备的删除操作同步过来。任务的“较新”依赖设备时钟，不代表已经具备服务器级冲突解决。

旧 `flash-backup-v1` 由独立兼容入口读取顶层 `logs/emotions`，映射出空 `tasks`，再做记录规范化；原始 v1 文件不应通过 v2 Schema。覆盖导入 v1 会清空现有任务；合并 v1 则保留任务。未知文件版本或已知分区的未知版本应拒绝。旧文件缺少的元信息属于迁移策略，不可伪造为已知的原始导出时间。

新增字段、枚举值或分区都需要版本协商，不能因“只是加字段”就直接投放：当前严格对象不接受额外字段。记录结构变化升级对应分区版本；新增分区/改变信封语义升级文件版本；发布前定义旧客户端的拒绝提示与迁移路线。

## 6. 样例和运行方式

- [valid-minimal.json](fixtures/valid-minimal.json)：空的完整 v2 文件。
- [valid-full.json](fixtures/valid-full.json)：三分区、全天/定时任务、可选空值，内容全部虚构。
- [legacy-v1.json](fixtures/legacy-v1.json)：旧版兼容样例；严格 v2 校验应失败。
- [contract.test.cjs](../../scripts/backup-contract/contract.test.cjs)：从有效样例变异产生非法日期、枚举、重复 ID、超限、版本和时间冲突等测试输入。负例同时落在 `fixtures/cases.json` 清单与独立 JSON 文件中，由三端共同消费。
- [HarmonyOS codec 测试](../../harmonyos/tests/backup-contract.test.cjs)：使用实际 `.ets` 编解码源文件，平台能力由主机替身提供。

需要 Node.js 20+ 和 Ajv 8.18.0（开发依赖，不进入客户端运行包）。在仓库 `app/` 下：

```sh
npm install --prefix scripts/backup-contract
npm test --prefix scripts/backup-contract
node scripts/backup-contract/validate.cjs docs/contracts/fixtures/valid-full.json
node --test harmonyos/tests/backup-contract.test.cjs
```

HarmonyOS 主机测试还需 TypeScript；加载规则见 `harmonyos/tests/ets-loader.cjs`，可用 `FLASH_TYPESCRIPT_PATH` 指定已安装模块目录。无需安装第二份 Ajv 时可用 `FLASH_AJV_PATH` 指定现有 Ajv 模块目录。校验命令退出码：0 合格、1 不合格、2 使用方式或文件读取错误。脚本不写入备份、不访问数据库、不上传内容；输出路径和错误，不输出记录正文。

当前运行结果和设备限制见 [执行与验收记录](acceptance.md)。Android/macOS 原生测试已接入；HarmonyOS 主机测试与 HAP 构建不能代替真机互传。

## 7. 落地状态

| 项目 | 当前实现 |
| --- | --- |
| 重要性 | 三端拒绝越界，恢复时跳过，不截断 |
| 文本与空白 | 三端按 UTF-16 上限及 ECMAScript trim 口径 |
| 数组 | 标准入口按输入数限制；恢复只检查前 100,000 个输入，余下计为跳过 |
| 元信息、未知字段 | 标准入口要求完整元信息；标准与恢复均不静默丢弃未知内容 |
| 数字 | 整数值允许 1.0，布尔值不能冒充整数 |
| 日期、时间 | 真实公历 0001–9999、明确偏移、UTC 毫秒截断后比较；时区需运行端支持 |
| 导出 | 正式入口校验，全部时刻规范化 |
| 合并与回滚 | 共用结果样例及原生/主机事务测试，见验收记录 |
| CI、真机 | 工作流已添加，远端运行和分支保护待确认；缺 HarmonyOS 真机 |

后续顺序：完成 CI 与可用设备验收 → HarmonyOS 原生设备验证 → 查询/日期窗口与搜索性能。未完成设备验收前不能宣布“三端全面互通”。
