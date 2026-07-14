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
- **Task 10** 主题模式：`src/stores/themeStore.ts` 持久化主题状态；Settings 页提供 system/dark/light 切换。
- **Task 11** 深色模式审计：修复全局/Calendar/LogFlow/FilterDrawer/Settings/StatsPanel 的暗色样式；`resolvedTheme` 正确驱动 `<html>` 的 `dark` 类。
- **Task 12** 最终集成：前端质量门禁（lint/format/typecheck/test/build）全绿，132 个测试通过；`npx cap sync ios` 成功；`ROADMAP.md` 已更新。

## 仍需本地完成的步骤

本环境缺少 JDK，因此以下步骤未在当前会话执行，需你在装有 JDK 17+ 的机器上完成：

1. 生成 Android release keystore：
   ```bash
   ./scripts/generate-android-keystore.sh
   ```
2. 构建并验证 Android release：
   ```bash
   npm run build
   npx cap sync android
   cd android && ./gradlew assembleRelease && ./gradlew bundleRelease
   ```
3. 用 `apksigner verify android/app/build/outputs/apk/release/app-release.apk` 确认签名。
4. 在 Android 模拟器/真机与 iOS Simulator 上做最终 smoke test。

## 质量门禁结果

```text
npm run lint         ✅
npm run format:check ✅
npx tsc -b --noEmit  ✅
npm run test:run     ✅ 132 tests passed
npm run build        ✅
npx cap sync ios     ✅
```
