# Flash Aero · Android

Android 端原生实现。Kotlin + Jetpack Compose，严格遵循 Material Design 3。

当前发布身份为 **Flash Aero v0.1.0**；`Aero` 为 v0 Alpha 阶段的版本代号。
首个正式版将统一命名为 **Flash Pulse v1.0.0**。

- applicationId：Release 为 `com.flash.app`；Debug 使用 `.native` 后缀（`com.flash.app.native`）
- minSdk 26 / targetSdk 36

## 技术栈

- Kotlin 2.2 + Jetpack Compose（BOM 2025.06）+ Material 3
- Room 2.7，数据库名 `flash-db`
- MVVM + StateFlow，单 Activity
- Gradle 8.14.3 / AGP 8.11 / JDK 17+（本机用 Temurin 21 亦可）

## 设计规范

- 遵循 Material Design 3：Color Roles、State Layers、FilterChip、
  OutlinedTextField 等（情绪等级为七档 emoji 选择器而非滑块；设计文档暂未随仓库公开）
- 应用使用静态 MD3 主题，品牌 Seed 为 `#4D96FF`，通过 `material-color-utilities`
  离线生成 light/dark 两组 Tonal Palette（与 Material Theme Builder 同算法）
- 界面风格支持 MD3 与 GLASS（玻璃拟态）两种模式，由 `SettingsStore` 中的 `UiStyle` 控制
- 换 Seed 重新生成配色：`pip install material-color-utilities` 后用
  `theme_from_argb_color(SEED)` 导出 light/dark 两组 roles，替换 `ui/theme/Theme.kt`
- 数据模型与统计算法和 macOS 端一一对应（`domain/EmotionStats.kt` ↔
  `macos/Flash/Domain/EmotionStats.swift`），保证两端算出来一样
- 首页、探索、日历和日志流中的记录可进入统一详情页，支持完整内容查看、编辑、
  标签与重要度调整、日志/灵感分类迁移、分享和删除
- 探索页支持按内容或标签搜索；日历聚合采用一次分组计算，避免数据量增长后逐日重复扫描
- Idea Reminder 会在至少三条灵感从未打开时显示导航角标、首页提示与“待梳理”标记；
  阅读状态存于 Room 本地辅助表，不进入跨平台备份
- 日志管理删除后提供 Snackbar 撤销入口
- Calendar 支持全天/定时任务、截止时间、完成状态与 WorkManager 本地提醒；Android 13+
  在用户设置提醒时按需申请通知权限
- `flash-backup-v2` 以分区 schema 携带日志、情绪和任务，继续兼容导入 v1，并为未来
  独立的自动同步协议保留稳定数据模型

## 常用命令

```bash
./gradlew :app:assembleDebug     # 构建 debug APK
./gradlew :app:installDebug      # 安装到已连接设备/模拟器
./gradlew test                   # 单元测试
```

APK 输出：`app/build/outputs/apk/debug/app-debug.apk`

## 跨设备备份传输

设置页的「传输到其他设备」会在缓存目录生成一次性 JSON 副本，通过受限
`FileProvider` URI 调用 Android 系统分享面板。可选择附近分享、邮件、聊天应用或
云盘。

「局域网发送 / 接收」使用 Android NSD 自动发现同一网络内的 Android 或 macOS
设备。发送方随机生成六位 PIN；PIN 60 秒失效、最多尝试五次，正确配对并完成
一次传输后服务立即关闭。App 仅申请局域网发现与连接所需权限，不连接 Flash
服务器；接收内容会执行格式校验并分析新增、修改、相同与仅本机数据，再选择差异
合并或覆盖。
建议只在可信的家庭或办公局域网使用。

## 目录结构

```
app/src/main/java/com/flash/app/
├── FlashApplication.kt      # Room 初始化、仓库与设置注入
├── MainActivity.kt          # 单 Activity 入口，主题模式应用
├── data/
│   ├── model/Models.kt      # 日志、情绪与 TaskItem 跨端模型
│   ├── db/                  # Entities / DAOs / FlashDatabase（Room）
│   ├── reminder/            # WorkManager 任务提醒调度与通知
│   ├── FlashRepository.kt   # 仓储，含合并/覆盖导入
│   ├── Backup.kt            # JSON 备份导出/导入，与 macOS 端互通
│   └── SettingsStore.kt     # 主题模式/界面风格/Welcome 状态（SharedPreferences）
├── domain/                  # 情绪统计算法、Idea Reminder 触发规则
└── ui/
    ├── theme/               # MD3 ColorScheme / Typography / FlashTheme
    │   └── glass/           # GLASS 风格背景与主题扩展
    ├── navigation/          # Routes + FlashApp（NavigationBar + NavHost）
    ├── components/          # LogCard / hexToColor 等共享组件
    ├── detail/              # 日志/灵感统一详情、编辑、分享与删除
    ├── home/                # Home Tab：今日概览与快速记录
    ├── explore/             # Explore Tab：灵感与日志发现
    ├── logflow/             # 日志管理：搜索/筛选/排序/编辑/删除
    ├── calendar/            # 日历页（非底部 Tab，首页等入口进入）：日志/情绪/任务聚合与任务编辑
    ├── emotion/             # 情绪页（非底部 Tab）：emoji 选择/子情绪/统计图表/历史
    ├── stats/               # 统计 Tab：情绪趋势与分布
    ├── welcome/             # 首次启动引导页
    └── settings/            # 设置：外观/备份分享与局域网传输/导入导出/清空/关于
```

## 发布签名 / Release Signing

- `*.keystore` 与 `release-signing.env` 已加入 `.gitignore`，**严禁入库**。
- 旧 Git 历史中的开发 keystore 已公开，**禁止再用于任何发布**。新密钥必须放在仓库外。
- **作废声明（2026-09-05）**：历史提交 `4c78c55` 入库的 `flash-release.keystore`（密码曾见于 `release-signing.env.example`）经决策**声明作废、保留历史**。它从未用于任何已分发的安装包（已分发的 `Flash-Alpha010.apk` 是 debug 证书签名的 debug 构建）。正式签名一律使用仓库外的新生密钥。
- 本地准备发布密钥（环境变量不要写入仓库）：
  ```bash
  export FLASH_RELEASE_STORE_FILE=/absolute/path/outside/repository/flash-release.keystore
  export FLASH_RELEASE_STORE_PASSWORD='use-a-password-manager-generated-secret'
  export FLASH_RELEASE_KEY_PASSWORD='use-another-password-manager-generated-secret'
  export FLASH_RELEASE_KEY_ALIAS=flash-release
  ../scripts/generate-android-keystore.sh
  ```
- `app/build.gradle.kts` 已强制读取上述四个变量；缺少任一变量时 Release 构建会直接失败，避免误发 unsigned APK。
- 打包：`./gradlew :app:bundleRelease`（商店 AAB）或 `./gradlew :app:assembleRelease`（测试 APK）。

## 注意

- `AndroidManifest.xml` 中 `android:allowBackup="false"` 为有意设置，避免本地数据通过 Android 云备份泄漏；应用内导出的 JSON 当前是明文文件，请只保存到可信位置并通过可信渠道传输。
- `settings.gradle.kts` 配置了阿里云镜像优先（国内直连 Maven Central 易 TLS 中断），
  海外环境可删除。
- 首次同步若提示 SDK 路径，新建 `local.properties` 写入 `sdk.dir=<本机 SDK 路径>`
  （已 gitignore）。

## 验收与发布状态（2026-09-26）

设备品质结果与未验项目见 [品质矩阵](../docs/quality/device-matrix.md)，跨端互传状态见 [契约验收](../docs/contracts/acceptance.md)。局域网使用 [握手 v1.1](../docs/contracts/lan-handshake-v1.1.md)：六位 PIN、挑战应答与 payload HMAC；内容未做端到端加密。历史明文 PIN 首包不兼容，双方需使用同代构建，旧数据经 JSON 文件迁移。
