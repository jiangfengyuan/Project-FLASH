# Phase 3 移动端发布准备 — 完成说明

## 已交付内容

- **Task 1** Android release 签名配置：`android/app/build.gradle` 已配置 release signing、ProGuard、版本号自动化；`scripts/generate-android-keystore.sh` 提供 keystore 生成脚本；`android/release-signing.env.example` 提供环境变量模板。
- **Task 2** Android 版本号自动化：`scripts/android-version.mjs` 从 `package.json` 计算 `versionCode`；`src/lib/__tests__/version.test.ts` 覆盖计算逻辑。
- **Task 3** Android ProGuard 规则：`android/app/proguard-rules.pro` 已创建，覆盖 Capacitor、插件、FileProvider、Keep 注解与 JS Bridge。
- **Task 4** iOS 基线：`npx cap add ios` 完成，`capacitor.config.ts` 已配置 iOS scheme/背景色/状态栏/键盘，`Info.plist` 限制竖屏，`LaunchScreen.storyboard` 背景色一致。
- **Task 5** 平台视觉适配：`src/lib/platform.ts` 实现平台检测与 UA fallback；`src/index.css` 提供 Material 3 / Liquid Glass token；核心组件已应用 token。
- **Task 6** 状态栏插件：`@capacitor/status-bar` 集成，`initNativePlugins()` 安全初始化。
- **Task 7** 安全区适配：`useSafeArea()` hook 注入 CSS 变量并应用到布局、BottomNav、InputArea。
- **Task 8** Android 返回键：`@capacitor/app` 集成，`useBackButton()` 处理物理返回键。
- **Task 9** 键盘插件：`@capacitor/keyboard` 集成，设置 `resize: 'ionic'`。
- **Task 10** 主题模式：`src/stores/themeStore.ts` 持久化主题状态；Settings 页提供 system/dark 切换。浅色模式因组件层尚未完成适配，暂不提供，留待后续完善。
- **Task 11** 深色模式审计：修复全局/Calendar/LogFlow/FilterDrawer/Settings/StatsPanel 的暗色样式；`resolvedTheme` 正确驱动 `<html>` 的 `dark` 类。
- **Task 12** 最终集成：前端质量门禁（lint/format/typecheck/test/build）全绿；`npx cap sync ios` 成功；Android release APK/AAB 构建并签名验证通过。

## Android Release 构建结果

在当前环境（Temurin JDK 21 + Android Studio SDK）完成：

```bash
cd android
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
export FLASH_RELEASE_STORE_PASSWORD=flashdev
export FLASH_RELEASE_KEY_PASSWORD=flashdev
./gradlew clean assembleRelease bundleRelease
```

产出：

- `android/app/build/outputs/apk/release/app-release.apk` — 1.4 MB，已签名
- `android/app/build/outputs/bundle/release/app-release.aab` — 1.9 MB，已签名

签名验证：

```bash
/Users/haydenjiang/Library/Android/sdk/build-tools/37.0.0/apksigner verify \
  android/app/build/outputs/apk/release/app-release.apk
# => APK signature verified
```

> 说明：当前使用开发 keystore（`android/app/flash-release.keystore`），密码为示例值 `flashdev`。正式发布前务必替换为私有生产证书，并通过 CI 密钥库或环境变量注入，切勿提交真实密码。

## 已知问题与后续建议

1. **浅色模式**：已暂时移除入口。组件层仍存在硬编码 `text-white`/`bg-white/5` 等 token，需全局审计后才能重新开放。
2. **iOS 真机验证**：Xcode 项目已基线化，但未在真机或 Simulator 上运行 smoke test。
3. **Android 安装验证**：APK 已签名生成，但未在模拟器/真机上安装启动验证。
4. **Gradle 分发版**：`gradle-wrapper.properties` 已改为 `gradle-8.14.3-bin.zip`（更小更快），不影响功能。
5. **清单版本号**：`AndroidManifest.xml` 中 `android:versionCode`/`android:versionName` 为硬编码，需与 `package.json` 保持一致；后续可考虑在构建前通过脚本自动同步。

## 质量门禁结果

```text
npm run lint         ✅
npm run format:check ✅
npx tsc -b --noEmit  ✅
npm run test:run     ✅
npm run build        ✅
npx cap sync ios     ✅
Android assembleRelease / bundleRelease / apksigner verify ✅
```
