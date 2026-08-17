# Flash 一闪 · Android

Android 端原生实现。Kotlin + Jetpack Compose，严格遵循 Material Design 3。

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
- Android 12+ 默认启用 Material You 动态取色；静态回退为品牌 Seed `#4D96FF`
  的 Tonal Palette（material-color-utilities 离线生成，与 Material Theme Builder 同算法）
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
├── MainActivity.kt          # 单 Activity 入口，主题模式/动态取色应用
├── data/
│   ├── model/Models.kt      # ColorTag/Category/EmotionLevel/SubEmotion/LogItem/EmotionRecord
│   ├── db/                  # Entities / DAOs / FlashDatabase（Room）
│   ├── FlashRepository.kt   # 仓储，含合并/覆盖导入
│   ├── Backup.kt            # JSON 备份导出/导入，与 macOS 端互通
│   └── SettingsStore.kt     # 主题模式/动态取色（SharedPreferences）
├── domain/EmotionStats.kt   # 情绪统计算法
└── ui/
    ├── theme/               # MD3 ColorScheme / Typography / FlashTheme
    ├── navigation/          # Routes + FlashApp（NavigationBar + NavHost）
    ├── components/          # LogCard / hexToColor 等共享组件
    ├── logstream/           # Log Tab：快速输入 + 最近日志流
    ├── logflow/             # 日志管理：搜索/筛选/排序/编辑/删除
    ├── idea/                # Idea Tab：灵感池，按日期分组
    ├── calendar/            # 日历 Tab：日志与情绪按日聚合
    ├── emotion/             # 情绪 Tab：滑块/子情绪/统计图表/历史
    └── settings/            # 设置：外观/备份导入导出/清空/关于
```

## 注意

- `settings.gradle.kts` 配置了阿里云镜像优先（国内直连 Maven Central 易 TLS 中断），
  海外环境可删除。
- 首次同步若提示 SDK 路径，新建 `local.properties` 写入 `sdk.dir=<本机 SDK 路径>`
  （已 gitignore）。
- 签名密钥 `*.keystore` 与 `release-signing.env` 均已 gitignore，严禁入库。
