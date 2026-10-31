# 旧工作树未提交内容审查 · 2026-11-01

审查对象：`/Users/haydenjiang/Documents/Codex/2026-10-24/harden-flash-across-ios-macos-android/work/flash-hardening`，HEAD `4d28844`。只读审查其4份已跟踪修改和2份未跟踪文档；没有提交、清空、覆盖或删除原件，没有启动该旧版本网络服务。

## 结论与处置

**没有发现需要再次移入统一候选的独有代码修改。** 四份代码/测试在统一候选已有对应版本；两份文档已有更新版本。旧工作树保留原状，不能把其中仍带网络实现的生产文件直接覆盖统一候选的停用控制器。

| 旧文件 | 核对结果 | 处置 |
| --- | --- | --- |
| Android生产LocalBackupTransfer.kt | 取消唤醒、单调总截止时限、长度格式/边界等修改，与候选 `android/app/src/test/java/com/flash/app/data/LegacyLocalBackupTransfer.kt` 在归档注释/对象重命名后逐字一致 | 已归档，仅测试；不重新引入src/main |
| Android LocalBackupTransferTest.kt | 取消退避、慢速输入总时限、前导零长度等新增测试；对协议对象引用作整体重命名后，与候选测试逐字一致 | 已保留，不重复合并 |
| Harmony生产LocalBackupTransfer.ets | 长度/错误处理修改；去除候选归档注释后，与 `harmonyos/tests/fixtures/LegacyLocalBackupTransfer.ets` 逐字一致 | 已归档，仅测试；不重新启用生产实现 |
| Harmony security-audit.test.cjs | 新增长度检查回归已在候选；唯一接线差异为loader显式 `legacyLan: true`，经该转换后逐字一致 | 候选接线正确指向历史fixture，不改回生产路径 |
| 未跟踪lan-v2-decision.md | 旧提案称当前wire仍为v1.1；候选同名文档已补停用决策、复现边界及2026-10-31新重建方案入口 | 保留历史原件，不覆盖当前状态文档 |
| 未跟踪next-beta-ui-plan.md | 旧架构/视觉准备提案；候选同名文档已补独立审查与最终验收责任、分平台截图证据及缺项 | 保留历史原件，不回退现有证据记录 |

旧版生命周期/长度维护不能解决未认证接收方获取明文、离线猜PIN或明文传输问题。直接合回生产目录会撤销已批准的停用处置，故不是候选遗漏。未来恢复LAN只能走独立安全重建，不能通过回滚这些文件实现。

## 独立于旧工作树的两笔遗漏提交

- `7741e0c` 删除的formatter、updateEmotion、flashCardTitle和Android公开月份属性，在候选源码/测试无调用者；保留被内部使用的私有月份状态。合并后通过编译/相关套件验证，不引入数据迁移。
- `7ebb0d0` 为存储装配增加默认nil的测试storeURL，生产调用仍使用原路径；新增损坏库、不可访问目录、临时会话副作用拒绝及恢复原库测试。合并保留加固分支的私密诊断/取消/严格解析，未把旧实现覆盖回来。
- 通过双父提交 `df3bded` 整合，原始提交ID仍为祖先。权限为000的目录只模拟文件访问失败，不是实际iPhone锁屏数据保护证明。

## 证据与边界

逐文件SHA-256和归档转换比较结果见 `evidence/candidate-push-20261101/`。原始diff及日志只存本地交付目录 `outputs/candidate-push-20261101/`，不把旧脆弱运行时代码重新加入生产目录。复核结束前再次检查原件哈希，确保审查未修改旧工作树。

当前统一候选工作树另有此前截图脚本修改与ios-c5/ios-c6未跟踪证据：它们是用户保留的验证材料，不属于本次遗漏提交，也不纳入推送。脚本diff与开始时一致。没有声称这些截图构成完整UI或无障碍验收。

此审查是未提交增量的静态去重/整合核对，不是旧版本完整安全审计；没有重测旧网络服务，也没有授予新LAN、真机或正式发布验收。
