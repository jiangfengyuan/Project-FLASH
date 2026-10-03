# HarmonyOS 7（API 26）适配矩阵

本文档汇总 HarmonyOS 7（API 26）主要特性及 Flash Aero（`app/harmonyos`）的适配情况。
工程 `compatibleSdkVersion` 为 5.0.0（API 12），`targetSdkVersion` 为 26.0.0；
所有 API 级别高于 12 的调用均通过 `canIUse` 或运行时能力判断保护，低版本设备优雅降级。

## 适配矩阵

| 特性 | 官方能力 | 本工程适配点与文件 | 状态 | 降级策略 |
| --- | --- | --- | --- | --- |
| ArkUI 沉浸光感材质与 V2 组件 | ArkUI 新版材质与组件状态管理 V2 体系 | 各页面/组件在保持 V1（`@Observed` + `@State`/`@ObjectLink`）架构不变的前提下做视觉精修：`entry/src/main/ets/pages/Index.ets`、`entry/src/main/ets/components/` | 本次落地（视觉精修部分）；V2 组件未整体迁移 | 材质与视觉效果按系统版本自动回落，不阻塞 V1 状态管理 |
| Ability Kit ModularObjectExtensionAbility | Ability Kit 模块化对象扩展能力（本机 API 26 SDK d.ts 中未见声明） | 未使用；本工程为单 UIAbility + 单路由架构 | 未使用 | 不需要 |
| Core File Kit 沙箱共享系统级可见 | `api/@ohos.fileshare.d.ts`（`SystemCapability.FileManagement.AppFileService.FolderAuthorization`，部分接口 since 11/20） | 备份导出经 Core File Kit 将 `flash-backup-v2` JSON 分享/导出为系统级可见文件；数据格式不变：`entry/src/main/ets/data/BackupFiles.ets`、`entry/src/main/ets/data/BackupService.ets` | 本次落地 | 不支持时回退为沙箱内导出 + 文件选择器另存，契约行为不变 |
| Notification Kit 半模态通知设置 | `api/@ohos.notificationManager.d.ts`：`requestEnableNotification(context)`（since 10，带 context 版本弹出半模态授权框） | 任务提醒前引导开启通知，渠道化提醒设置：`entry/src/main/ets/data/TaskReminderScheduler.ets` | 本次落地 | 授权被拒或弹框已展示时仅提示并保持原提醒开关状态 |
| 平行视界 EasyGo 与应用内分屏 | 折叠屏/平板双栏显示（本机 API 26 SDK d.ts 中未见 EasyGo 声明） | 单路由架构下以 `600vp`/`840vp` 断点 + 宽屏布局承接等效体验：`entry/src/main/ets/pages/Index.ets` | 仅检测（以断点布局承接） | 窄屏保持单列底部导航布局 |
| 服务卡片 | `kits/@kit.FormKit.d.ts`：`FormExtensionAbility`、`formProvider`、`formBindingData` | 「今日概览」卡片展示今日灵感/情绪/任务摘要 | 本次落地 | 不支持卡片形态的设备仅应用内今日概览 |
| 实况窗 | Live View Kit（本机 API 26 SDK kits 目录未见 LiveViewKit 声明；`notificationManager` 提及实况通知模板 since 26.0.0） | 「鸿蒙体验」页检测系统支持状态：`entry/src/main/ets/data/HarmonyCapabilities.ets` | 仅检测；正式创建需签名上架与场景准入 | 未获准入时不创建实况窗，提醒走普通通知 |
| 星闪（NearLink） | `api/@ohos.nearlink.*.d.ts`（advertising/scan/dataTransfer/ssap 等） | 「鸿蒙体验」页检测硬件支持；数据传输继续使用跨平台局域网协议 | 仅检测 | 无星闪硬件时使用 `_flashbackup._tcp` 局域网传输回退 |
| 系统深浅色 | `api/@ohos.app.ability.ConfigurationConstant.d.ts`：`ColorMode`；`Configuration.colorMode` | `EntryAbility` 监听配置变化并跟随系统深浅色：`entry/src/main/ets/entryability/EntryAbility.ets` | 本次落地 | 无法读取配置时保持浅色默认主题 |
| 沉浸式窗口 | `api/@ohos.window.d.ts`：`setWindowLayoutFullScreen`、`setSpecificSystemBarEnabled` | 主窗口沉浸布局 + 避让状态栏/导航条：`entry/src/main/ets/entryability/EntryAbility.ets`、`entry/src/main/ets/pages/Index.ets` | 本次落地 | 接口不可用时保持非沉浸默认窗口 |
| 折叠屏 | `api/@ohos.display.d.ts`：`isFoldable`、`getFoldStatus`、`on('foldStatusChange')` | 折叠态变化监听并联动响应式布局：`entry/src/main/ets/pages/Index.ets` | 本次落地 | 无折叠能力时仅按窗口断点布局 |
| 双语资源 | Localization Kit 资源目录限定词（`en_US`） | 应用名双语：`AppScope/resources/en_US/element/string.json`（`app_name = "Flash Aero"`）；页面文案仍为硬编码中文 | 本次落地（应用名）；页面文案多语言资源化为后续工作 | 无匹配语言资源时回落 base 目录 |
| 碰一碰 | Share Kit + App Linking | 未接入 | 需签名上架与平台配置 | 继续使用局域网互传 |
| 小艺意图（Harmony Intelligence） | 意图框架 + 小艺开放平台 | 「快速记录」适合作为意图入口，未接入 | 需签名上架与意图审核 | 应用内快速创建浮动按钮 |

## 备注

- API 26 SDK 采用语义化版本标注（接口 `@since` 标记如 `26.0.0`），本文档中
  「since 26.0.0」类标注即以本机 SDK 声明为准。
- targetSdk 26 的 Agent Framework Kit 变更对本工程无影响：本工程未使用
  Agent Framework Kit（本机 API 26 SDK kits 目录亦无对应声明文件），
  不依赖其任何能力。
- 实况窗、碰一碰、小艺意图等受限能力在未取得签名、AGC 上架与对应场景准入前，
  只保留检测路径，不提供虚假入口。
