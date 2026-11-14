# Flash Paper 1.0 Alpha 1 验收报告

**结论：不通过。** 四端命名已按所有者批准映射到 Paper 第一个 Alpha，确认的缺陷已修复并完成当前环境可执行的回归；默认备份格式跨端不对称、macOS 无签名测试宿主的旧库兼容线索、Android Release APK 和真机／签名系统集成仍未完成，不能授予四端完整 Alpha 验收。本次未发布、未打 tag、未上传、未改签名、未合并 main。

## 1. 基线与审查范围

审查起点：`feat/paper-writing`，HEAD `c3eaf53c61549e598afc75476d5d0c30fd37edd0`。工作区含大量既有未提交功能、图标、应用锁、加密及文档改动。修改前保存了 871 个源文件／资源的逐文件 SHA256、原状态、tracked patch 和完整源码副本，未覆盖或丢弃既有工作。

既有工作单独冻结为 `f6b7e53bc11aa4aa8cfc35bd6a3a47c895e46d58`（Aero 最后 Beta 源码基线）；这是归档原有工作的大提交，不混称为本轮修复。后续修复、性能、质量、CI、版本和验收文档分开提交。逐文件清单见 [文件清单](paper-alpha1-files-20261114.md)，完整提交与证据索引在工作区 `outputs/paper-alpha1-audit-20261114/`。

已阅读 README、AGENTS、现有审查／加固交接、备份契约、开发／设备品质／CI／发布文档；未找到独立 CONTRIBUTING 或 Paper 数字版本规则。发现 Aero Alpha／Pulse 正式版旧命名冲突后先报告，取得所有者确认再更新，规则归档在 [versioning.md](../release/versioning.md)。

范围包括 iOS、macOS、Android、HarmonyOS、共享 FlashKit、持久化、备份与加密、应用锁、通知／提醒、小组件、Share Extension、Spotlight、deep link、测试和 CI。采用风险面追踪和合成复现，没有声称逐行审完全部 871 个文件。安全扫描覆盖为部分；没有将测试通过等同于不存在缺陷。未发现可确认的当前源代码凭据泄露；未尝试使用任何凭据，也没有验证完整 Git 历史。

LAN v2 在当前源码中**未实现**；生产入口是停用桩，不启动发现、监听或连接。旧协议代码保留在测试夹具内，没有关闭认证检查、放宽解析、删除断言、引入密码学协议或静默降级。

## 2. 确认问题、修复与验证

| 问题与触发条件 | 根因／影响范围 | 修复位置 | 验证结果及限制 |
| --- | --- | --- | --- |
| iOS 锁定页打开快速记录读到私人草稿；取消／保存可能改写旧草稿 | 锁定入口复用普通 capture，构造 store 并无条件加载、写入或清除 | `ios/Flash/UI/Theme/AppLockWindow.swift`、`UI/QuickCapture/QuickCaptureSheet.swift` | 不可变临时会话完全不构造私人 store；真实 UIKit 字段检查、旧文件／旧格式不迁移不破坏、正常会话恢复均通过；iOS 全套 36 项通过。实际锁定输入保存、Face ID 和后台截屏未验收 |
| Android 锁定 capture 显示既有草稿，或锁定后保留旧 Compose 文本 | 全局 draft 与 rememberSaveable 会话不随锁定隔离 | `ui/capture/CaptureSession.kt`、`QuickCaptureSheet.kt`、`ui/navigation/FlashApp.kt` | 草稿读取惰性且仅 owner 会话可用；锁定更换会话 ID，过时回调不能写／清除草稿，解锁不提升临时会话权限；能力策略单测通过。生物识别 UI／前后台完整循环未真机验收 |
| macOS 已打开的私密编辑 sheet 高于锁定遮罩 | 主窗口 overlay 无法遮住独立 sheet NSWindow | `macos/Flash/FlashApp.swift`、`App/AppLockSheetShield.swift` | 屏蔽主窗口 sheet 子树、原 toolbar、旧焦点／无障碍及底层快捷键；同层遮挡不卸载编辑器，解锁恢复草稿与原状态。真实合成 AppKit／SwiftUI 测试通过（含嵌套晚到弹窗、替换 contentView、拒绝交出焦点时 fail closed）；2 项新宿主测试及全套 15 项通过。未验证物理认证和系统截屏 |
| Android 旧 UI 快照收藏覆盖新正文或复活已删条目 | upsert 整条旧对象 | `data/db/Daos.kt`、`data/FlashRepository.kt` | 改为按 ID 窄字段 UPDATE，真实 Room 回归验证新正文保留、取消收藏、删除不复活；模拟器通过，不改数据库 schema |
| Android 情绪／任务写失败后输入丢失、编辑器提前关闭；通知失败诱发重复保存 | fire-and-forget 保存与 UI 清理不等待持久化结果 | `ui/emotion/*`、`ui/calendar/TaskEditorDialog.kt`、`CalendarViewModel.kt`、`ui/navigation/FlashApp.kt` | 保存过程防重入，数据库成功才清理／关闭；提醒失败单独报告“已保存”。真实 Room 拒绝写入／重试回归通过。suspend 回调调整是修复保存时序所必需，非 schema 变更 |
| Android 旧任务编辑／通知动作覆盖完成状态或复活已删任务 | 对 caller 快照整体更新，读取与写入分离 | `FlashRepository.kt`、`data/reminder/TaskReminderScheduler.kt` | 事务内取当前记录，编辑保留完成时间／来源，完成／延后操作按当前行更新，删除后拒绝更新；并发回归通过 |
| Apple 新任务保存成功、提醒拒绝后重试产生第二条任务 | 每次 makeTask 生成新 UUID／createdAt | `FlashDesign/Features/Calendar/TaskEditorView.swift` | 每个编辑会话持有稳定身份；新测试验证两次保存只有一行、独立编辑器身份不同；FlashDesign 11 项通过 |
| Apple 搬库时主库移动失败，WAL 已被移走，回退读旧库丢最近提交 | 先 move 伴随文件再 move 主库 | `FlashCore/Data/FlashStoreLocation.swift` | 经所有者批准，先 copy 伴随文件，主库成功后才清理旧伴随文件。真实合成 crash-WAL：原实现已提交 `[1,2]` 回退只见 `[1]`，继续写入并重试后成 `[1,3]`；修复失败／重试均保留 `[1,2]`，并清理旧目录；共享原生回归通过。不改 schema／位置 |
| Harmony 旧迁移隔离失败／超限仍删除原 Preferences，短写被当作成功 | 源删除不依赖成功归档，忽略 UTF-8 完整字节数 | `harmonyos/.../data/FlashStore.ets` | 经所有者批准，保留未归档源键，恢复导出可读原始值；临时文件完整写入后 rename。合成旧源 3 失败／1 通过，修复 4／4 通过；主机全套及原生 Debug／Release 通过。不保证断电 fsync 耐久性 |
| Harmony 无法隔离坏 RDB 行时普通 merge 会重写表、消除唯一恢复副本 | 恢复失败仅警告，合并继续破坏性替换 | 同一 FlashStore | 未保全原始数据时阻止普通 merge；保留明确覆盖／清空操作原语义；合成回归通过，不改格式、存储位置或迁移 schema |
| Harmony 提醒频率修改未替换原计划，启停并发可重复发布或留下晚到提醒 | 并发同步无序、只判断存在 | `IdeaReminderScheduler.ets`、`AppController.ets` | 串行队列与代次控制，设置更改显式重排，停用清理晚到发布，合并重复意图；合并／提醒共新增 7 项回归，旧源 3 项红用例；主机 271 项、原生编译通过，真实系统提醒行为未验收 |
| iOS 分享 provider 同时提供 URL 和文本时丢文本 | else-if 互斥 | `ios/FlashShare/ShareViewController.swift` | 独立加载表示，并在 URL 读取阶段维持 http(s) 限制；Debug／Release 扩展编译通过，未做实际 provider 端到端验收 |
| Android 包装 Context 拿不到 Activity，日历切月绘制重复状态 | 强转 Activity；AnimatedContent 忽略目标 state | `ui/lock/AppLockScreen.kt`、`ui/calendar/CalendarScreen.kt` | 用现有 LocalActivity、以目标 CalendarUiState 绘制并以月份作 contentKey；编译与 lint 通过，实际动画／最低 API 交互未验证 |
| macOS 备份错误直接 print 详情 | 绕过共享隐私日志入口 | `macos/Flash/UI/Settings/SettingsView.swift` | 6 处改用现有 FlashLog private 详情；Debug／Release 编译通过，未采集真实敏感日志 |

## 3. 性能：同环境串行 Release 对比

已确认热点是保存筛选在每条记录内重新扫描全部标签。`LibraryFilter.apply` 现在每次查询先计算匹配标签 ID 和必选标签集合，保留标题／标签 OR、标签 AND／OR、任务状态、收藏、Unicode 规范等语义；新增业务边界回归通过。

| 合成数据（标签数均 1,000） | 修改前中位数 | 修改后中位数 |
| --- | --- | --- |
| 1,000 条记录 | 73.992 ms | 2.498 ms |
| 10,000 条记录 | 759.074 ms | 15.421 ms |

环境：同一台 arm64 Mac、macOS 27.3 (26C5035r)、Xcode 27.2 (27B52)，独立的 before／after Release 构建；每组 2 次预热、7 次采样，串行执行，无其他测试／构建并发，thermalState=0。两组数据 SHA256 和结果 sink 一致；精确数据、源码与日志见 `filter-{before,after}.jsonl`、`filter-benchmark.swift`、对应 build log。1,000 条集摘要 `7d22cf04861d0caafea9537535c10a7476884100d342a949b5713abd51387747`，10,000 条集摘要 `99072e73d4d912a0d5b0decad7909e90c5be92627aa930091873383aa3e9f757`。

这是**主机内存纯值计算**结果，不是 iPhone／Android／Harmony、模拟器帧率或用户启动／滚动性能。启动、数据库大规模访问、备份、图片、通知重建、后台和 LAN 无新的可对照设备测量；其他结构修正不宣称性能提升。此前任务的数据不计为本轮优化成果。

## 4. 结构整理与删除

窄字段 DAO 与事务保存集中在仓储；capture 会话权限独立为不可变策略；SheetShield 保留 AppKit 内容身份与原生命周期；恢复逻辑留在既有 Store，平台 API 不搬到跨端公共协议层。只清理日历完全相同的重复 import、等价 BOM 字符转义、过时默认值注释及生成缓存，无大范围重写、UI redesign、新功能、schema／权限／密码依赖变更。

**未删除任何 Git 源文件／资源／迁移／样本。** 删除的只有本轮 Python 工具生成的 `tools/i18n/__pycache__/generate.cpython-313.pyc` 与 `collect.cpython-313.pyc`；确认未被源码、配置、脚本、文档、测试或资源引用，保留生成它们的 `.py`，并在 `.gitignore` 排除后续缓存。逐项依据见 `deleted-files.json`。没有清理用户数据、真实备份、密钥、签名配置或未知用途文件。

CI 增加 LAN 静态隔离、FlashKit 测试和通用 iOS 模拟器编译入口；未新增发布、上传、凭据或权限步骤。远端 CI 与既有 `xcode-27` runner 标签未验证。本机没有 `/Applications/Xcode-beta.app`，使用现有 `/Applications/Xcode.app` 27.2，而不是系统 CLT。

## 5. 构建与回归结果

各平台构建与测试命令串行执行，性能测量另行串行。均使用合成数据。模拟器与物理设备结果不混用。

| 检查 | 原始基线 | 最终结果 |
| --- | --- | --- |
| FlashKit | Core 305＋Design 9＝314 通过 | Core 307＋Design 11＝318 通过 |
| iOS iPhone 模拟器测试 | 35 通过 | 36 通过；App／Share／Widget 编译通过 |
| macOS 宿主测试 | 13 通过 | 15 通过；额外原生合成窗口夹具通过 |
| Android 单元／Debug APK | 单元及 Debug 构建成功，lint 整体 exit1 | Debug 134＋Release 134 单元通过；Debug App／androidTest APK 构建通过 |
| Android lintDebug | 5 errors／51 warnings | 0 errors／51 warnings（最终测试源修正后再跑通过） |
| Android API36 ARM64 模拟器仪器 | 基线未运行 | 19 通过、1 专用探针按设计跳过（最终 XML 共 20 个 testcase；Gradle 进度日志的 21 个事件不计作测试数）；随后 Apple／Harmony 各 write、force-stop、read 四阶段均通过 |
| Harmony 主机 | 260 通过 | 271 通过 |
| Harmony 原生 | unsigned Debug HAP 通过 | unsigned Debug、Release HAP 均通过；非模拟器／真机运行证明 |
| 备份契约 | 120 通过 | 120 通过 |
| 本地化／夹具／LAN 隔离／diff | 保留原源码基线 | 938 条翻译、明文／加密夹具一致性、LAN 静态隔离、diff 检查通过 |
| iOS／macOS Release | 本轮未完整测原始 Release 构建 | 两端 Release 构建通过，CODE_SIGNING_ALLOWED=NO；iOS 为通用模拟器而非设备 archive |
| Android assembleRelease | 未执行 | **失败／未验证产物**：原签名守卫要求 FLASH_RELEASE_* 环境，未提供；未关闭检查或改签名 |
| 物理设备、安装签名能力、远端 CI、格式化／全仓静态分析 | 未完成 | **未验证**；现有 lint／编译检查不替代这些项目 |

命令与日志位于证据目录：`baseline-*.log`、`flashkit-final.log`、`ios-final.log`、`macos-final-retry.log`、`{ios,macos}-release.log`、`android-final.log`、`android-instrumentation-corrected.log`、`android-process-*-installed.log`、`harmony-*-complete.log`、`harmony-native-final.log`、`harmony-release.log`、`remaining-checks.json`。构建缓存按正常工具策略使用，没有把缓存任务计为新的独立测试数量。

原始 lint 5 项分别是低版本磁贴 API、Context 强转 Activity、动画目标未使用、品牌翻译声明、字面 BOM。前述代码问题直接处理；磁贴已经 API34+ 使用 PendingIntent，只有低版本走 Intent，按所有者明确批准仅对这个 guarded 调用标注精确 lint 误报，不删除 SDK guard、不改全局 lint 规则。品牌不翻译设置及等价 `\uFEFF` 仍保留严格解析语义。

中途失败同样保留：macOS 新测试最初 2 个断言失败，原因是默认按钮没有挂入窗口；补全夹具、不删断言后全套通过。Android 仪器首次 XML 20 项中 2 项失败、1 项跳过，原因是旧测试硬编码中文而环境是英文；一次重跑命令因路径错误未实际改到测试，重复同样失败；随后改为完整本地化预期（LAN 同时保留 IDLE／空 PIN／空设备断言）后通过。专用跨进程探针首次因 Gradle 结束后卸载 APK 而无法启动，重新安装已编译 APK 后四阶段通过。不存在通过删除断言或放宽安全语义掩盖失败。

早先自动审批额度曾拒绝 iOS／部分委派执行，额度恢复后已重试通过；这已不再是 iOS 验证或提交的当前阻断，不将旧“尚未运行”说明冒充最终状态。Android Release 签名守卫和下节部署限制仍在。

## 6. 版本与归档记录

本次身份 **Flash Paper 1.0 Alpha 1**，四端数字 `1.0`／build `1`；tag 格式 `v1.0-alpha.1` 只记载。两端 Xcode 项目、Android Gradle、Harmony AppScope、关于页、应用／扩展本地化、四端 README 和路线图已同步。系统 App 名为 Flash Paper，关于页附 Alpha 序号。稳定 bundle ID、数据库路径、备份前缀、历史协议测试和历史发布物名称保留，避免破坏用户数据及兼容契约。

上一版明确记为 **Flash Aero 最后一个 Beta**：审查前工作区源码归档 `Flash-Aero-final-Beta-source-20261114.tar.gz`、`aero-final-beta.json` 和 `baseline-files.json` 绑定初始 HEAD 加 dirty 内容，现另有精确基线提交 `f6b7e53`。旧编号 iOS／Android／Harmony 0.1.0(1)、macOS 0.1.0(2) 不重编号；不是把旧 macOS Beta2 二进制当成本次上一版。正式版为 Flash Paper 1.0.0，遵循所有者三段版本语义。

## 7. 尚未解决及 Alpha 结论

1. **跨端完整备份不互读。** Apple 当前默认 `BackupImportCoordinator → LibraryBackup.export` 导出 v4；Android／Harmony 只接受 v1/v2。现有 schema2 的双向语义和 Android 跨重启探针通过，不能证明 Apple 默认 v4 文件可导入其他两端。差异已存在于冻结基线。本轮不擅加 schema、不静默丢弃标签／回收站数据；须单独确定兼容交付范围并批准方案。
2. **macOS 旧库兼容仍需隔离复现。** 无签名宿主启动日志观察到默认 Application Support/default.store “Cannot use staged migration with an unknown model version”并回退内存。新合成存储／已知版本迁移测试通过，不能证明该默认库可安全升级；也不能仅凭无签名测试环境认定签名 App 同样失败。未读取真实日记、删除库或尝试重置。需在可确认来源的旧发布库合成副本／签名环境验证；任何新增迁移先申请批准。
3. Android Release APK 未完成；Harmony HAP 和 Apple 构建未签名，未验证设备认证、App Group、Share Extension 安装隔离、系统文件选择器、通知／Widget／Spotlight、最低 OS、VoiceOver／TalkBack／RTL 长文本和真实设备性能。AFM 真机生成未验证。
4. LAN v2 未实现，不能作为本 Alpha 已交付功能；旧协议停用，不恢复不安全回退。macOS 驻留 Quick Capture／菜单栏按既有产品政策在主窗口应用锁之外，不能声称全 App 所有入口都只写不读。Harmony 认证／偏好 API 失败时的既有 fail-open 产品策略尚需确认，未建立攻击前提，不凭猜测改安全／权限实现。
5. 保留 51 条 Android lint 警告、Swift 现有并发／未使用返回值告警、Harmony SemVer／无签名警告；没有通过全局禁用检查消除。全仓格式化工具、远端 CI 与设备矩阵均未运行完成。

**结论仍为不通过，保留“Flash Paper 第一个 Alpha 候选”身份，不称已验收或可分发。** 后续先解决默认备份互读范围与旧库升级证据，再在经批准的签名／设备环境复验。当前已确认、获准且可安全验证的修复已完成；未把新功能、数据库／备份 schema 变更夹带进本轮。

安全扫描 `90631f43-2a99-43b9-95c8-dbd403df5aec` 记录 3 个中等严重度的基线应用锁问题及候选修复，覆盖为部分；其报告不表示全仓无漏洞或完整产品验收通过。安全产物若保留早期 quota／WAL 待验证问题，以最终验证记录的已解决说明为准，不重复视作当前阻断。

## 8. 交付索引与提交纪律

- [逐文件清单](paper-alpha1-files-20261114.md)：本轮相对于冻结工作区的文件级范围，不与原 HEAD 的大量历史差异混称。
- `outputs/paper-alpha1-audit-20261114/changed-files.json`、`audit-only.patch`：精确逐文件摘要及完整候选补丁；`commits.txt`／`commits.json` 保存完整实际提交列表，最终验收文档提交自身 hash 由 Git 生成后写入该外部清单，避免自引用 hash。
- `baseline-commit.json`、`fix-commits.json`、`remaining-checks.json`、`android-process-results.json`、`deleted-files.json` 和原始日志可追溯证据。
- 根工作区、releases、outputs 不在 app Git；按 AGENTS 强制写入 `/Users/haydenjiang/Documents/flash-Alpha/CHANGELOG.md`。本轮没有 amend、rebase、force-push、tag、上传或 main 合并。
