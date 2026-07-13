# Flash 一闪

> 闪过即留，一目了然 —— 一款轻量级的移动端灵感/日志/情绪记录应用。

Flash 一闪是一款面向个人用户的本地优先笔记应用，支持快速记录日志、收藏灵感、查看日历聚合以及记录每日情绪。数据完全存储在本地（`localStorage`），无需后端，并可通过 Capacitor 打包为 Android APK。

---

## 功能特性

- **Log Stream**：首页快捷输入，支持键盘输入与语音转写（Web Speech API），一键保存为日志或灵感。
- **Log Flow**：搜索、筛选、管理所有日志记录，支持编辑、删除、转移至 Idea Flow。
- **Idea Flow**：按时间分组展示灵感记录，提供重要性标记与快速操作。
- **Calendar**：日历视图聚合日志与情绪记录，按日期查看当日内容。
- **Current Emotion**：拖拽式情绪等级选择，支持子情绪标签、状态与备注，保存后触发彩带动画。
- **本地持久化**：所有数据通过 Zustand `persist` 中间件保存到 `localStorage`。
- **动画与无障碍**：Framer Motion 页面切换与列表动画，支持 `prefers-reduced-motion` 降级，关键按钮均配备 `aria-label`。
- **触感反馈**：关键操作调用 `navigator.vibrate` 提供轻微震动反馈（设备支持时）。

---

## 技术栈

- **框架**：React 19
- **语言**：TypeScript 5.9（启用 `strict` 模式）
- **构建工具**：Vite 8
- **样式**：Tailwind CSS 3 + 自定义玻璃拟态工具类
- **动画**：Framer Motion
- **状态管理**：Zustand（含 `persist` 持久化）
- **移动端打包**：Capacitor 8（Android）
- **测试**：Vitest 4 + jsdom + React Testing Library
- **代码规范**：ESLint 9 + TypeScript ESLint

---

## 安装与启动

### 环境要求

- Node.js 20+
- npm 10+ -（可选）Android Studio + JDK 17，用于构建 Android APK

### 安装依赖

```bash
npm install
```

### 开发模式

```bash
npm run dev
```

默认启动在 `http://localhost:3000`，支持热更新。

### 生产构建

```bash
npm run build
```

产物输出到 `dist/` 目录。

### 代码检查

```bash
npm run lint          # ESLint
npx tsc --noEmit      # TypeScript 类型检查
```

### 运行测试

```bash
npm run test:run      # 单次运行
npm run test          # 监听模式
npm run test:coverage # 生成覆盖率报告
```

---

## 构建 Android APK

项目已集成 Capacitor，可将 Web 产物打包为 Android 应用。

### 前置准备

1. 安装 Android Studio。
2. 配置 `JAVA_HOME` 指向 JDK 17（或 Android Studio 自带的 JDK）。
3. 安装 Android SDK 与命令行工具。

### 构建步骤

```bash
# 1. 构建 Web 产物
npm run build

# 2. 同步 Web 资源到 Android 项目
npx cap sync android

# 3. 打开 Android Studio 进行构建/签名/发布
npx cap open android
```

在 Android Studio 中：

1. 选择 **Build > Generate Signed Bundle / APK...**
2. 选择 **APK**，配置或创建签名密钥（keystore）。
3. 选择 `release` 构建类型，完成打包。

> 发布前建议启用代码压缩：在 `android/app/build.gradle` 中将 `minifyEnabled` 设为 `true` 并配置 ProGuard 规则。

---

## 构建 iOS 应用

项目已集成 Capacitor iOS 平台，可将 Web 产物打包为 iOS 应用。

### 前置准备

1. 使用 macOS 系统。
2. 安装 Xcode（建议 15 及以上版本）。
3. 安装 CocoaPods：`sudo gem install cocoapods`。
4. 已安装 `@capacitor/ios`（`npm install` 时已包含在 `devDependencies` 中）。

### 构建步骤

```bash
# 1. 构建 Web 产物
npm run build

# 2. 同步 Web 资源到 iOS 项目
npx cap sync ios

# 3. 打开 Xcode 进行构建/签名/发布
npx cap open ios
```

在 Xcode 中：

1. 选择 `ios/App/App.xcodeproj` 或 `App.xcworkspace`。
2. 配置 **Signing & Capabilities**：选择 Team 与 Bundle Identifier。
3. 选择目标设备或模拟器，点击 **Run** 运行。
4. 发布时选择 **Product > Archive**，按流程导出或上传 App Store Connect。

---

## 项目目录

```
src/
├── main.tsx                 # React 挂载入口
├── App.tsx                  # 根组件：布局 + 页面切换 + 全局动效
├── index.css                # 全局样式 / Tailwind / 玻璃拟态工具类
├── lib/
│   ├── utils.ts             # cn() 工具函数
│   ├── constants.ts         # 颜色、标签、情绪等级等共享常量
│   ├── haptics.ts           # 触感反馈 helper
│   └── motion.ts            # 减少动画偏好 hook 与过渡预设
├── hooks/
│   └── useClickOutside.ts   # 点击外部关闭 hook
├── components/              # 共享 UI 组件
├── pages/                   # 页面级组件
├── stores/                  # Zustand 全局状态
└── test/                    # 测试配置

docs/                        # 架构说明、审计报告等文档
data/                        # Demo 数据（开发环境使用）
android/                     # Capacitor Android 工程
ios/                         # Capacitor iOS 工程
```

---

## 贡献与开发建议

- 提交前请确保 `npm run lint`、`npx tsc --noEmit` 与 `npm run test:run` 全部通过。
- 新增组件建议补充对应单元测试。
- 动画实现请统一通过 `useReducedMotion` 支持用户的减少动画偏好。

---

## 许可证

MIT
