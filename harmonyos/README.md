# Flash Aero for HarmonyOS

Flash Aero v0.1.0 的 HarmonyOS 原生版本，使用 ArkTS、ArkUI、加密 RDB 与 Preferences 设置存储构建，
不依赖 Android 兼容层。

## 已对齐功能

- 首页醒目搜索入口、关键词/标签搜索、灵感流、编辑与删除；
- 七级情绪、负面子情绪、备注与最近记录；
- 日历聚合、近七日情绪和记录构成统计；
- `flash-backup-v2` 分区 JSON 导入/导出（兼容 v1），持久化 Calendar 任务并在导入前
  分析日志、情绪和任务差异，可选择合并或覆盖；
- 与 Android/macOS 共用 `_flashbackup._tcp` 局域网协议：mDNS 自动发现、随机四位 PIN、
  60 秒有效、最多五次尝试，成功后立即关闭发送服务；
- 本地优先存储、欢迎页和 Flash Aero v0.1.0 品牌信息。
- 与 Android 对齐的四模块首页、明确命名的“搜索”导航、今日概览、快速创建浮动按钮、
  页面淡入/位移转场；
- 响应式窗口断点：手机使用底部导航，展开折叠屏/平板使用宽屏布局，`840vp` 起切换侧边导航；
- “鸿蒙体验”页实时检测星闪、实况窗与闪控球的系统支持状态。

## 稳定性与安全加固

- 局域网接收采用按声明长度分配的定长缓冲区，响应头限制为 64 字节，备份上限为 50 MB；
- 四位 PIN 使用系统密码学随机数生成，拒绝取模偏差，仍保持 60 秒有效和五次尝试限制；
- 备份导入校验 UUID、日期、字段长度和重复 ID，单类记录最多接收 100,000 条；
- 本地日志与情绪数据分别校验，单类损坏不会清空另一类正常数据；
- 无法解析的异常记录隔离到应用沙箱 `quarantine/` 文件（不再写入 Preferences，规避其单值约 8 KB 上限），
  隔离写入失败只告警、绝不阻塞启动，旧版本写在 Preferences 的隔离键会在首次启动时一次性搬移；
- 任务编辑保存前对日期做 round-trip 校验，`2026-02-30` 等不存在的日期和越界年份会被拒绝并提示，
  避免保存成功却在重启后被协议校验隔离；
- 搜索采用短防抖并按 50 条分页渲染；日历按日期预分组并按 30 天分页，降低大量记录时的重绘和扫描开销；
- 删除记录、删除情绪和清空数据均要求二次确认，写入操作带防重复提交保护。

## HarmonyOS 系统能力接入状态

| 能力 | 当前状态 | 说明 |
| --- | --- | --- |
| 多设备适配 | 已接入 | 使用 `600vp`、`840vp` 响应式断点，覆盖手机、折叠屏和平板。 |
| 星闪 | 已接入能力检测 | API 23 起调用 NearLink Kit 检测硬件支持；数据传输继续使用跨平台局域网协议作为通用回退。 |
| 实况窗 | 已接入可用性检测 | 正式创建实况窗仍需满足时效性场景并通过 Live View Kit 准入，模拟器不能完成端到端验收。 |
| 闪控球/闪控窗 | 已接入可用性检测 | 不申请 `USE_FLOAT_BALL` 受限权限；Flash 当前笔记场景不在官方开放范围内。 |
| 碰一碰 | 待签名与平台配置 | 需要 Share Kit、App Linking、手动签名及真机验证，当前模拟器不支持。 |
| Harmony Intelligence | 待意图审核 | “快速记录”适合作为小艺意图；正式上线需要 AGC 上架及小艺开放平台审核。 |

受限能力不会使用虚假入口或在未获授权时调用。后续取得签名、AGC 应用和对应场景准入后，
再启用实况窗、碰一碰和小艺意图的正式执行路径。

## 页面与状态边界

- `pages/Index.ets` 负责应用装配、响应式布局、导航与转场；首页、搜索、统计、我的、
  情绪、日历、记录管理、设置和能力展示均为独立组件。
- `components/` 保存共享展示组件和快速记录、日志编辑、任务编辑、删除确认、欢迎弹层。
- `state/FeatureStates.ets` 按功能定义 `@Observed` 状态；页面通过 `@ObjectLink` 接收状态，
  通过 `PageActions` 调用控制器，不直接调用数据库、文件、Socket 或提醒接口。
- `state/AppController.ets` 负责初始化、生命周期、Store 订阅与应用级操作；日志、情绪、
  任务和备份控制器分别接收自己的状态及可注入仓储。
- `state/FeatureProjection.ets` 在成功提交后只重建受影响分区的只读数据和日历索引；
  单条任务写入不会复制日志/情绪数组或重新运行日志搜索。编辑草稿保存在功能状态中。
- `data/FlashStore.ets` 串行化写操作，事务成功后发布 `StorePartition` 通知；失败不发布，
  下一次操作仍可执行。页面退出会解除订阅、取消搜索定时器和局域网会话。

这次结构拆分保留现有数据库 schema 和备份格式。RDB 查询列正规化、日期窗口查询、
更大规模性能基准仍是后续独立工作。

## 结构回归测试

```bash
cd harmonyos
node --test tests/feature-refactoring.test.cjs
```

测试加载实际 `.ets` 控制器、投影与 Store 源码，使用显式平台替身验证分区隔离、并发写入
顺序、保存失败、事务失败、草稿保留、防重复提交、导入重试、生命周期/旧传输回调隔离，
以及异常记录隔离落沙箱文件、隔离写入失败降级和非法日期拒绝。
默认使用本机 TypeScript 或 DevEco Studio 随附版本；其他环境可设置 `FLASH_TYPESCRIPT_PATH`
指向 TypeScript 模块目录。

这些是主机逻辑测试，不模拟 ArkUI 响应式运行时或原生 RDB。HAP 构建用于验证 ArkTS 和
组件接线；设备上仍需验证主题切换、导航返回、编辑/删除、导入预览以及 LAN 取消行为。

## 构建

推荐使用 DevEco Studio 6.0.2 或兼容版本，安装 HarmonyOS SDK API 26 或更高版本。
用 DevEco Studio 打开本目录，等待依赖同步后运行 `entry`。

命令行调试构建（DevEco Studio 默认安装路径）：

```bash
cd harmonyos
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
PATH=/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
assembleHap --mode module -p product=default -p module=entry@default \
-p buildMode=debug --no-daemon
```

未签名产物位于 `entry/build/default/outputs/default/entry-default-unsigned.hap`。
真机安装和正式发布前，需要在 DevEco Studio 中配置华为开发者证书与发布签名。

## 兼容性与验证

- Bundle ID：`com.flash.app.harmonyos`
- 兼容版本：HarmonyOS 5.0.0（API 12）起
- 目标版本：HarmonyOS 7.0.0（API 26）
- 设备类型：手机（包含折叠屏）、平板

局域网传输依赖设备支持 mDNS、TCP 网络能力，跨平台互传需在真实设备且同一可信局域网内验收。
