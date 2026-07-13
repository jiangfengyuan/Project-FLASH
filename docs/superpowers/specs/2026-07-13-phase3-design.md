# Phase 3 设计文档：移动端发布准备

> 方案：A（Android 发布优先 + iOS 基线）
> 决策：竖屏 Portrait、生成内测 keystore、iOS 仅做工程基线不配置签名
> 日期：2026-07-13

---

## 1. 目标与范围

完成 Android 发布所需的签名、压缩、版本号配置，添加 iOS 工程基线，处理双端平台适配（状态栏、安全区、返回键/手势、键盘），并补齐深色模式剩余缺口。为 Google Play / 内测 APK 与后续 iOS 签名上架奠定工程基础。

**本次纳入范围：**
- Android release 签名与构建配置
- Android minify / ProGuard / shrinkResources
- versionName / versionCode 与 package.json 版本联动
- iOS 平台添加与基础 Info.plist / 图标 / 启动图
- 状态栏与安全区适配
- Android 物理返回键与 iOS 侧滑返回行为
- 键盘弹起时输入区域可见性
- 深色模式全局检查与修复

**本次不纳入范围：**
- iOS 签名团队、上架截图、隐私政策文案
- 本地推送、相机、图片附件（Phase 4）
- 数据同步 / 云备份
- 多语言

---

## 2. Android 发布配置

### 2.1 Release 签名

- 使用 `keytool` 生成一个内测/开发用 keystore：
  - 路径：`android/app/flash-release.keystore`
  - 别名：`flash-release`
  - 有效期：30 年
  - 密码通过本地 `local.properties` 或环境变量注入，**不写入仓库**。
- 在 `android/app/build.gradle` 中配置：
  ```gradle
  signingConfigs {
    release {
      storeFile file(String.valueOf(System.getenv('FLASH_RELEASE_STORE_FILE') ?: 'flash-release.keystore'))
      storePassword System.getenv('FLASH_RELEASE_STORE_PASSWORD')
      keyAlias System.getenv('FLASH_RELEASE_KEY_ALIAS')
      keyPassword System.getenv('FLASH_RELEASE_KEY_PASSWORD')
    }
  }
  ```
- 提供 `android/release-signing.env.example` 模板，说明如何设置环境变量。

### 2.2 版本号自动化

- `versionName` 从 `package.json` 读取（已通过 `src/lib/backup.ts` 引入，复用同一机制）。
- `versionCode` 使用 `package.json` 版本号计算：`major * 10000 + minor * 100 + patch`，例如 `0.1.0 => 100`。
- 未来每次发版只需更新 `package.json` 的 `version`，Android 与 iOS 版本自动跟随。

### 2.3 代码与资源压缩

- 在 `android/app/build.gradle` 的 `buildTypes.release` 中启用：
  - `minifyEnabled true`
  - `shrinkResources true`
  - `proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'`
- 新建/更新 `android/app/proguard-rules.pro`，保留：
  - Capacitor 核心类
  - WebView 相关反射类
  - `androidx.core.content.FileProvider`
  - `@Keep` 注解类

### 2.4 构建验证

- 本地执行：
  ```bash
  npm run build
  npx cap sync android
  cd android && ./gradlew assembleRelease && ./gradlew bundleRelease
  ```
- 产物路径：
  - APK：`android/app/build/outputs/apk/release/app-release.apk`
  - AAB：`android/app/build/outputs/bundle/release/app-release.aab`

---

## 3. iOS 基线配置

### 3.1 添加平台

- 执行 `npx cap add ios`。
- 同步 web 产物：`npx cap sync ios`。
- 将 `ios/` 纳入 git 管理（已存在 `.gitignore` 排除 build/Pods/xcuserdata）。

### 3.2 Info.plist 与 Capacitor 配置

- `capacitor.config.ts` 增加 `ios.scheme` 与背景色（与 Android 统一）。
- `ios/App/App/Info.plist`：
  - 限制方向为竖屏
  - 设置 `UIViewControllerBasedStatusBarAppearance` 为 `true`
  - 保留 `CFBundleDisplayName` = "一闪"
  - Bundle Identifier 初始为 `com.flash.app`

### 3.3 图标与启动图

- 应用图标：由于当前无正式设计稿，先创建一组占位图标：
  - 生成一张 1024×1024 纯色背景（`#0a0e1a`）PNG，中央放置白色文字“闪”。
  - 使用脚本或手动按比例缩放生成 iOS App Icon Set 所需的全尺寸（20pt/29pt/40pt/60pt @2x/@3x）。
  - 放入 `ios/App/App/Assets.xcassets/AppIcon.appiconset` 并更新 `Contents.json`。
- 启动图：直接修改 `LaunchScreen.storyboard`，设置根视图背景色为 `#0a0e1a`，中央添加一个白色“闪” Label（占位）。
- 说明：图标与启动图均为占位资源，后续上架前替换为正式设计稿即可。

### 3.4 签名占位

- 不配置 Development Team。
- Xcode 打开后默认使用个人团队或待手动填写。
- 在 spec 中备注：拿到 Apple Developer 账号后，在 Xcode → Signing & Capabilities 中选择 Team，并更新 Bundle Identifier 与 App Icon。

---

## 4. 平台 UI 适配

### 4.1 状态栏

- 引入 `@capacitor/status-bar`。
- 在 `src/main.tsx` 或 `App.tsx` 初始化后设置：
  ```ts
  import { StatusBar, Style } from '@capacitor/status-bar';
  await StatusBar.setStyle({ style: Style.Dark });
  await StatusBar.setBackgroundColor({ color: '#0a0e1a' });
  ```
- 若 StatusBar 插件不可用（Web 预览），静默降级。

### 4.2 安全区

- 根布局增加安全区 padding：
  ```css
  padding-top: env(safe-area-inset-top);
  padding-bottom: env(safe-area-inset-bottom);
  ```
- `BottomNav` 固定在底部，确保 `padding-bottom` 包含安全区高度。
- `InputArea` 固定在 `bottom-16` 基础上叠加安全区，避免被底部手势条遮挡。

### 4.3 Android 返回键

- 引入 `@capacitor/app`。
- 在 `App.tsx` 监听 `backButton` 事件：
  - 当前在 tab 首页（`log`/`idea`/`calendar`/`emotion`）时：弹出退出确认或最小化应用。
  - 当前在非 tab 页（`logFlow`/`settings`）时：调用 `navigateTo(activeTab)` 返回。
- 防止 Drawer/Sheet 打开时直接退出：若相关 drawer 打开，先关闭 drawer。

### 4.4 iOS 侧滑返回

- iOS 侧滑由系统处理，无需额外代码。
- 确保自定义 Drawer/Sheet 不拦截边缘滑动手势：抽屉内容避免贴边全屏，保留边缘响应区域。

### 4.5 键盘适配

- 引入 `@capacitor/keyboard`。
- 应用启动后设置：
  ```ts
  import { Keyboard, KeyboardResize } from '@capacitor/keyboard';
  await Keyboard.setResizeMode({ mode: KeyboardResize.Ionic });
  ```
- 该模式会让 WebView 随键盘高度 resize，确保 `InputArea` 在键盘弹起时仍可见。
- Web 预览环境下 Keyboard 插件不可用，通过 try/catch 静默降级。

---

## 5. 深色模式完整适配

- 全局搜索硬编码颜色值（`#FFFFFF`、`#000000` 等），替换为 Tailwind 语义类或 CSS 变量。
- 检查以下页面/组件：
  - `Calendar`：日期数字、周末标记、选中态
  - `LogFlow`：搜索框、FilterDrawer 背景、空态图标
  - `Settings`：输入框、radio 选中态、drawer 背景
  - `CurrentEmotion`：滑块、子情绪标签、StatsPanel 图表 tooltip
- 设置页新增“主题模式”选项：跟随系统 / 始终深色 / 始终浅色。
  - 新增 `themeStore` 或复用 `navigationStore` 持久化用户选择。
  - 在 `App.tsx` 中监听系统 `prefers-color-scheme` 变化；当选择“跟随系统”时自动切换。
  - 当前应用仅深色主题，因此“浅色”模式可先作为结构预留，默认强制深色，待 Phase 4 再补齐浅色样式。

---

## 6. 测试与验证

### 6.1 单元测试

- 新增 `src/hooks/__tests__/useBackButton.test.tsx`：验证返回键行为映射。
- 新增 `src/lib/__tests__/version.test.ts`：验证 versionCode 计算。
- 补充深色模式相关组件快照或类名断言（可选）。

### 6.2 构建验证

- `npm run build` 通过。
- `npx cap sync android && npx cap sync ios` 无错误。
- `./gradlew assembleRelease` 产出 signed APK。
- `./gradlew bundleRelease` 产出 signed AAB。

### 6.3 真机/模拟器 Smoke Test

- 安装 release APK，验证启动、Splash 隐藏、底部导航、记录日志、导出备份。
- 验证 Android 返回键：从 LogFlow 返回 Log Stream，在首页弹出退出确认。
- 验证深色模式切换后无明显视觉问题。

---

## 7. 风险与应对

| 风险 | 影响 | 应对 |
|------|------|------|
| ProGuard 误删 Capacitor 类导致崩溃 | 高 | 在 `proguard-rules.pro` 中显式 keep Capacitor、FileProvider、WebView 相关类；构建后真机验证 |
| iOS 工程因未签名无法在模拟器运行 | 中 | 使用个人团队或仅验证工程结构；spec 中明确签名步骤待后续完成 |
| 安全区/键盘适配在不同机型表现差异 | 中 | 在常见刘海屏/手势条机型上真机验证，必要时启用 Keyboard 插件 |
| 深色模式遗漏页面 | 低 | 全局颜色扫描 + 手动逐页检查 |

---

## 8. 验收标准

- [ ] `android/app/build.gradle` 配置完整 release 签名、minify、shrinkResources、versionCode/versionName。
- [ ] `./gradlew assembleRelease` 与 `./gradlew bundleRelease` 成功产出签名产物。
- [ ] `npx cap add ios` 完成，`ios/` 目录结构正确，Info.plist 限制竖屏，含基础图标与启动图。
- [ ] 状态栏颜色与深色主题一致，安全区不遮挡 BottomNav / InputArea。
- [ ] Android 返回键行为符合平台习惯（非首页返回，首页退出确认）。
- [ ] 深色模式切换可用，所有页面无明显视觉回归。
- [ ] 全量测试通过：`npm run lint && npm run format:check && npx tsc -b --noEmit && npm run test:run && npm run build`。
