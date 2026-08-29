# Flash Aero · Android

Android 端原生实现。Kotlin + Jetpack Compose，严格遵循 Material Design 3。

当前发布身份为 **Flash Aero v0.1.0**；`Aero` 为 v0 Alpha 阶段的版本代号。
首个正式版将统一命名为 **Flash Pulse v1.0.0**。

- applicationId：发布前改回 `com.flash.app`
- minSdk 26 / targetSdk 36

## 技术栈

- Kotlin 2.2 + Jetpack Compose（BOM 2025.06）+ Material 3
- Room 2.7，数据库名 `flash-db`
- MVVM + StateFlow，单 Activity
- Gradle 8.14.3 / AGP 8.11 / JDK 17+（本机用 Temurin 21 亦可）

## 设计规范

- 遵循 Material Design 3：Color Roles、State Layers、离散 Slider、
  FilterChip、OutlinedTextField（设计文档暂未随仓库公开）
- 应用使用静态 MD3 主题，品牌 Seed 为 `#4D96FF`，通过 `material-color-utilities`
  离线生成 light/dark 两组 Tonal Palette（与 Material Theme Builder 同算法）
- 界面风格支持 MD3 与 GLASS（玻璃拟态）两种模式，由 `SettingsStore` 中的 `UiStyle` 控制
- 换 Seed 重新生成配色：`pip install material-color-utilities` 后用
  `theme_from_argb_color(SEED)` 导出 light/dark 两组 roles，替换 `ui/theme/Theme.kt`
- 数据模型与统计算法和 macOS 端一一对应（`domain/EmotionStats.kt` ↔
  `macos/Flash/Domain/EmotionStats.swift`），保证两端算出来一样

## 常用命令

```bash
./gradlew :app:assembleDebug     # 构建 debug APK
./gradlew :app:installDebug      # 安装到已连接设备/模拟器
./gradlew test                   # 单元测试
```

APK 输出：`app/build/outputs/apk/debug/app-debug.apk`

## 目录结构

```
app/src/main/java/com/flash/app/
├── FlashApplication.kt      # Room 初始化、仓库与设置注入
├── MainActivity.kt          # 单 Activity 入口，主题模式应用
├── data/
│   ├── model/Models.kt      # ColorTag/Category/EmotionLevel/SubEmotion/LogItem/EmotionRecord
│   ├── db/                  # Entities / DAOs / FlashDatabase（Room）
│   ├── FlashRepository.kt   # 仓储，含合并/覆盖导入
│   ├── Backup.kt            # JSON 备份导出/导入，与 macOS 端互通
│   └── SettingsStore.kt     # 主题模式/界面风格/Welcome 状态（SharedPreferences）
├── domain/EmotionStats.kt   # 情绪统计算法
└── ui/
    ├── theme/               # MD3 ColorScheme / Typography / FlashTheme
    │   └── glass/           # GLASS 风格背景与主题扩展
    ├── navigation/          # Routes + FlashApp（NavigationBar + NavHost）
    ├── components/          # LogCard / hexToColor 等共享组件
    ├── home/                # Home Tab：今日概览与快速记录
    ├── explore/             # Explore Tab：灵感与日志发现
    ├── logflow/             # 日志管理：搜索/筛选/排序/编辑/删除
    ├── calendar/            # 日历 Tab：日志与情绪按日聚合
    ├── emotion/             # 情绪 Tab：滑块/子情绪/统计图表/历史
    ├── stats/               # 统计 Tab：情绪趋势与分布
    ├── welcome/             # 首次启动引导页
    └── settings/            # 设置：外观/备份导入导出/清空/关于
```

## 发布签名 / Release Signing

- `*.keystore` 与 `release-signing.env` 已加入 `.gitignore`，**严禁入库**。
- 本地准备发布密钥：
  ```bash
  keytool -genkey -v -keystore flash-release.keystore -alias flash -keyalg RSA -keysize 2048 -validity 10000
  ```
- 将 `flash-release.keystore` 放在仓库外安全位置，并创建 `release-signing.env`：
  ```
  STORE_FILE=/absolute/path/to/flash-release.keystore
  STORE_PASSWORD=your_store_password
  KEY_PASSWORD=your_key_password
  KEY_ALIAS=flash
  ```
- 在 `app/build.gradle.kts` 中读取 `release-signing.env` 并配置 `signingConfigs.release`，再让 `buildTypes.release` 引用该 signing config：
  ```kotlin
  val signingEnv = rootProject.file("release-signing.env")
  signingConfigs {
      create("release") {
          if (signingEnv.exists()) {
              val props = java.util.Properties().apply { load(signingEnv.inputStream()) }
              storeFile = file(props.getProperty("STORE_FILE"))
              storePassword = props.getProperty("STORE_PASSWORD")
              keyAlias = props.getProperty("KEY_ALIAS")
              keyPassword = props.getProperty("KEY_PASSWORD")
          }
      }
  }
  buildTypes {
      release {
          isMinifyEnabled = true
          proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
          signingConfig = signingConfigs.getByName("release")
      }
  }
  ```
- 打包：`./gradlew :app:assembleRelease`，输出 `app/build/outputs/apk/release/app-release.apk`。

## 注意

- `AndroidManifest.xml` 中 `android:allowBackup="false"` 为有意设置，避免本地数据通过 Android 云备份泄漏；本地备份请使用应用内加密的 JSON 导出功能（`data/Backup.kt`）。
- `settings.gradle.kts` 配置了阿里云镜像优先（国内直连 Maven Central 易 TLS 中断），
  海外环境可删除。
- 首次同步若提示 SDK 路径，新建 `local.properties` 写入 `sdk.dir=<本机 SDK 路径>`
  （已 gitignore）。
