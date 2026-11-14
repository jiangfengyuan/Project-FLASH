# Flash Paper 版本规则

2026-11-14 经项目所有者确认；取代当前版本仍称 Aero Alpha、首个正式版称 Pulse 的旧规划。历史归档文件与报告保留原名。

- 正式版显示 `Flash Paper 1.0.0`：第一段为大版本，第二段为大版本更新，第三段为安全／质量维护更新。
- 测试版显示 `Flash Paper 1.0 Alpha 1` 或 `Flash Paper 1.0 Beta 1`，阶段与测试序号分开。
- 本轮四端数字版本统一 `1.0`、build number `1`；应用关于页显示 `Flash Paper 1.0 Alpha 1`。系统应用名称为 `Flash Paper`，稳定 bundle ID 不变。
- 本轮约定 tag 格式 `v1.0-alpha.1`；只记录格式，不创建 tag。未来 build 递增、其他阶段／正式版 tag 规则尚未进一步规定，不从本轮自行推导。
- 上一版指本轮审查前冻结的工作树，记录为 **Flash Aero 最后一个 Beta 测试版**，保留原数字编号：iOS／Android／HarmonyOS `0.1.0 (1)`，macOS `0.1.0 (2)`。源码基线提交 `f6b7e53bc11aa4aa8cfc35bd6a3a47c895e46d58`，其父提交为 `c3eaf53c61549e598afc75476d5d0c30fd37edd0`。

版本身份与质量验收分开。当前为 Paper 的第一个 Alpha 候选，是否获准验收、分发以 [验收报告](../acceptance/paper-alpha1-20261114.md) 为准；不得仅凭版本字符串推断已验收或发布。不得自行打 tag、上传、改签名、合并 main 或发布。
