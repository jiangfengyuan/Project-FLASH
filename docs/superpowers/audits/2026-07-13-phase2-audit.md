# Phase 2 合并后项目审计报告

审计时间：2026-07-13
范围：`app/` 前端源码、Capacitor 原生配置、构建产物与测试覆盖
执行命令：

```bash
npm run lint          # ✅ 通过
npm run format:check  # ✅ 通过
npx tsc -b --noEmit   # ✅ 通过
npm run test:run      # ✅ 114 tests passed
npm run build         # ✅ 成功
npm audit             # ✅ 0 vulnerabilities
npm run test:coverage # ✅ 67% statements / 62% branches
```

---

## 1. 确认的高优先级 Bug / 风险

### 1.1 `InputArea` 语音录制 `onend` 闭包捕获过期 `mode`（Bug + 内存泄漏）

- **位置**：`src/pages/LogStream/InputArea.tsx:165-173`
- **表现**：
  - `recognition.onend` 里读取的 `mode` 是 `startRecording` 被调用那一刻的过期值（通常是 `'idle'`），导致语音识别自然结束时无法正确切到 preview。
  - `setTimeout` 没有在组件卸载或停止录制时清理，可能产生内存泄漏和在已卸载组件上调用 `onModeChange` 的警告。
- **根因**：事件处理器闭包捕获了 React state，且没有使用 ref 或回调来读取最新状态。
- **修复方向**：使用 `useRef` 跟踪是否应在识别结束时切到 preview；在 `stopRecording` 中清理 pending timeout。

### 1.2 `Settings` 导入文件大小硬编码 10 MB

- **位置**：`src/pages/Settings/index.tsx:67`
- **表现**：与 `src/lib/backup.ts` 中已定义的 `MAX_BACKUP_SIZE_BYTES` 常量不同步，未来修改备份限制时容易遗漏。
- **修复方向**：统一使用 `MAX_BACKUP_SIZE_BYTES`。

### 1.3 `exportBackup` 中 `appVersion` 硬编码

- **位置**：`src/lib/backup.ts:40`
- **表现**：备份文件里的 `appVersion` 永远写死为 `'0.1.0'`，与 `package.json` 不同步。
- **修复方向**：从 `package.json` 或 `import.meta.env.PACKAGE_VERSION` 读取真实版本。

### 1.4 Android 原生配置 `allowBackup="true"`

- **位置**：`android/app/src/main/AndroidManifest.xml:5`
- **表现**：用户日志与情绪等本地敏感数据可能被自动备份到 Google 云端，存在隐私风险。
- **修复方向**：设置为 `android:allowBackup="false"`（或结合 `android:fullBackupContent` 精确排除）。

### 1.5 `FilterDrawer` 快捷日期按钮使用时区错误的 UTC 日期

- **位置**：`src/pages/LogFlow/FilterDrawer.tsx:131-135`
- **表现**：`new Date().toISOString().slice(0, 10)` 取的是 UTC 日期，非用户本地日期；在负时区晚间会选中“明天”，与 `getTodayStr()` 等本地日期逻辑不一致。
- **修复方向**：统一使用 `getTodayStr()`。

---

## 2. 中优先级性能 / 可维护性问题

### 2.1 `FilterDrawer` 使用无选择器的 `useLogStore()` 订阅

- **位置**：`src/pages/LogFlow/FilterDrawer.tsx:13-22`
- **表现**：抽屉打开时，日志、搜索、过滤等任何状态变化都会触发整个 `FilterDrawer` 重渲染。
- **修复方向**：改用细粒度 selector，如 `useLogStore((s) => s.startDate)` 等。

### 2.2 `LogFlow` 每次渲染都会重新计算过滤结果

- **位置**：`src/pages/LogFlow/index.tsx:169`
- **表现**：`useShallow((state) => state.getFilteredLogs())` 能避免无意义重渲染，但 `getFilteredLogs()` 内部每次都会创建新数组并排序，CPU 开销随日志量增加。
- **修复方向**：在 store 或组件内使用 `useMemo`，并仅在选择输入变化时重算。

### 2.3 `CurrentEmotion` 代码块过大（406 KB gzip）

- **表现**：构建产物 `CurrentEmotion-*.js` 达到 406 KB，包含 `recharts` 等仅在“统计”页签使用的库。首页加载受影响。
- **修复方向**：将 `StatsPanel` 改为 lazy load，`recharts` 将拆到独立 chunk。

### 2.4 `index.html` 缺少移动端/PWA 元标签

- **表现**：`lang="en"` 不正确；无 `theme-color`、`apple-mobile-web-app-capable`、`viewport-fit=cover` 等 Capacitor 应用常用标签。
- **修复方向**：更新 `index.html` 元信息。

### 2.5 多个页面订阅整个 `logs` / `emotions` 数组

- **位置**：`Calendar`、`IdeaFlow`、`LogFlow`、`StreamList` 等
- **表现**：任何单条记录的增删改都会触发依赖整个数组的组件重渲染。
- **修复方向**：按需要拆分为更细粒度 selector 或派生状态；长期可考虑 zustand 的 `derive`/`subscribeWithSelector`。

---

## 3. 低优先级 / 需要产品决策

### 3.1 iOS 支持横屏

- **位置**：`ios/App/App/Info.plist:35-47`
- **表现**：iPhone 支持横屏，iPad 支持四个方向。若希望保持移动应用竖屏体验，需要调整。
- **建议**：Phase 3 移动端适配时确认是否需要限制为 portrait。

### 3.2 无 CSP（Content Security Policy）

- **位置**：`index.html`
- **表现**：本地 Capacitor 应用风险较低，但发布到 Web/PWA 时建议添加 CSP。
- **建议**：Phase 3 发布准备时评估。

### 3.3 备份数据校验可更严格

- **位置**：`src/lib/backup.ts:isValidLog / isValidEmotion`
- **表现**：未校验 `colorTag` 是否在允许集合、`category` 是否合法、`importance` 是否存在。导入异常备份后可能在 UI 渲染时产生不可预期行为。
- **建议**：增加枚举值校验和默认值回退。

### 3.4 Demo 数据仅在 dev 注入

- **位置**：`src/main.tsx:11-43`
- **表现**：开发模式下如果用户清空数据，刷新页面会重新注入 demo 数据，可能造成困扰。
- **建议**：改为通过显式入口（如设置页“加载示例数据”）注入，而非自动注入。

---

## 4. 测试覆盖缺口

| 模块 | 语句覆盖 | 主要未覆盖区域 |
|------|----------|----------------|
| `src/lib/fileIO.ts` | 24% | Capacitor 原生路径未测试 |
| `src/pages/Settings/index.tsx` | 51% | 导入成功/失败、导出路径 |
| `src/pages/LogFlow/index.tsx` | 57% | 菜单、编辑、删除、Virtuoso 路径 |
| `src/pages/LogStream/index.tsx` | 50% | 详情、编辑、分类选择 |
| `src/pages/CurrentEmotion/StatsPanel.tsx` | 7% | 图表渲染、日期切换 |
| `src/components/ErrorBoundary.tsx` | 0% | 错误回退 UI |

---

## 5. 建议的修复顺序

1. **立即修复**：1.1、1.2、1.3、1.4、1.5（真实 Bug + 安全风险）
2. **本轮优化**：2.1、2.2、2.4（性能 + 元信息）
3. **后续 Phase 3**：2.3、3.1、3.2、3.3、3.4、测试补全


---

## 6. 已实施的修复（同一次提交）

| 问题 | 修复位置 | 验证 |
|------|----------|------|
| `InputArea` 语音 `onend` 过期 `mode` 闭包 + timeout 泄漏 | `src/pages/LogStream/InputArea.tsx` | 新增测试通过 |
| `Settings` 导入文件大小硬编码 | `src/pages/Settings/index.tsx` | 使用 `MAX_BACKUP_SIZE_BYTES` 并新增测试 |
| `exportBackup` `appVersion` 硬编码 | `src/lib/backup.ts` | 从 `package.json` 读取，测试同步更新 |
| Android `allowBackup="true"` | `android/app/src/main/AndroidManifest.xml` | 改为 `false` |
| `FilterDrawer` 快捷日期 UTC 时区错误 | `src/pages/LogFlow/FilterDrawer.tsx` | 统一使用 `getTodayStr()` |
| `FilterDrawer` 开始/结束日期可倒置 | `src/pages/LogFlow/FilterDrawer.tsx` | 自动校正，新增测试 |
| `FilterDrawer` 无选择器订阅 | `src/pages/LogFlow/FilterDrawer.tsx` | 改为细粒度 selector |
| `index.html` 语言与移动端元标签 | `index.html` | `lang="zh-CN"`，增加 viewport-fit/theme-color 等 |
| `coverage` 被 lint/format | `.prettierignore` / `eslint.config.js` / `.gitignore` | 忽略 coverage 目录 |
| `tsconfig.app.json` 支持 JSON import | `tsconfig.app.json` | 增加 `resolveJsonModule` |

最终验证：

```bash
npm run lint          # ✅
npm run format:check  # ✅
npx tsc -b --noEmit   # ✅
npm run test:run      # ✅ 117 tests passed
npm run build         # ✅
npm audit             # ✅ 0 vulnerabilities
```
