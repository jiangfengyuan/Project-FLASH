# flash-backup-v4 · 本地资料库完整备份

v4 保持 v3 的正文 `data`、分区 `schemas` 和 `personalLibrary`，新增三个必填字段：

- `preferences`：`taggingMode` 为 `suggest` / `existing` / `organize`；`retentionDays` 为整数 0–365，0 表示用户明确选择永不清理。
- `automaticTags`：记录键到自动来源标签 ID 的映射；必须是同一记录 `personalLibrary.links` 的非空、无重复子集。未列出的关联视为手动选择。
- `trash`：独立 UUID、`deletedAt`、可选 `expiresAt`、`tags`、`automaticTagIDs`，以及 `log` / `emotion` / `task` 三选一的完整正文值；可选 `reminder` 仅引用归档的灵感。

`deletedAt` / `expiresAt` 使用 Swift Codable 默认 Date 编码：自 **2001-01-01T00:00:00Z** 起的秒数，允许小数。正文原有 ISO 时间与日期保持原格式。归档任务值使用 `dueKind`、`dueDate` 或 `dueAt` + `timeZone`（不同于正文分区的 `due` 对象）。可选字段缺省时省略，归档不接受显式 null。结构与限制以 [JSON Schema](flash-backup-v4.schema.json) 为准。

归档 ID 不要求与活动正文 ID 不同，允许合并备份后保留冲突供用户决定；默认恢复遇到活动正文同 ID 时整个恢复事务回滚，用户可另选“恢复为副本”。副本生成新 UUID；收藏、正文与日期保留，已过期条目不导入、不导出。导入不会重算原始删除/过期时间，也不会把已过期内容复活。恢复的灵感周期提醒保留设置但暂停，需用户重新确认。任务提醒按恢复后的任务重建。

v1/v2/v3 导入继续支持。覆盖旧格式会清除本机回收站与本地智能设置，预览显示提示；合并旧格式保留它们。v4 合并按归档 ID 去重，标签按规范名称合并，并保持手动标签优先于自动来源。覆盖导入与正文、元数据、归档一起提交，失败全部回滚。

外层 `flash-backup-enc-v1` 不变，解密后再识别 v4。2026-11-21 起，本次 Android 与 Mac 候选的文件导出和系统分享默认写 v4。兼容格式选项显式导出 v2 正文，适用于仍读 v2 的旧版 Android 或 HarmonyOS。Android Room 6 将资料库扩展字段与正文一起持久化，标准导入支持 v2/v3/v4，v1 沿用恢复入口。

参考检查器：`npm test --prefix scripts/backup-contract`。`fixtures/valid-library-v4.json` 是原生 Swift 导出样本，不含真实用户内容。
