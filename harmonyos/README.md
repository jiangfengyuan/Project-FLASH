# Flash Aero for HarmonyOS

Flash Aero v0.1.0 的 HarmonyOS 原生版本，使用 ArkTS、ArkUI 与 Preferences 构建，
不依赖 Android 兼容层。

## 已对齐功能

- 首页快速记录、灵感流、搜索、编辑与删除；
- 七级情绪、负面子情绪、备注与最近记录；
- 日历聚合、近七日情绪和记录构成统计；
- `flash-backup-v1` JSON 导入/导出，导入前分析差异，可选择合并或覆盖；
- 与 Android/macOS 共用 `_flashbackup._tcp` 局域网协议：mDNS 自动发现、随机四位 PIN、
  60 秒有效、最多五次尝试，成功后立即关闭发送服务；
- 本地优先存储、欢迎页和 Flash Aero v0.1.0 品牌信息。
- 与 Android 对齐的四模块首页、今日概览、快速创建浮动按钮、页面淡入/位移转场；
- 响应式窗口断点：手机使用底部导航，展开折叠屏/平板使用宽屏布局，`840vp` 起切换侧边导航；
- “鸿蒙体验”页实时检测星闪、实况窗与闪控球的系统支持状态。

## 稳定性与安全加固

- 局域网接收采用按声明长度分配的定长缓冲区，响应头限制为 64 字节，备份上限为 50 MB；
- 四位 PIN 使用系统密码学随机数生成，拒绝取模偏差，仍保持 60 秒有效和五次尝试限制；
- 备份导入校验 UUID、日期、字段长度和重复 ID，单类记录最多接收 100,000 条；
- 本地日志与情绪数据分别校验，单类损坏不会清空另一类正常数据；
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
