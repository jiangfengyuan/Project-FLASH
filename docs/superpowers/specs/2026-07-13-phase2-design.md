# Flash 一闪 — Phase 2 设计文档

> 版本：Alpha v6 Phase 2
> 更新日期：2026-07-13
> 范围：P0 数据导入/导出 + P1 搜索与筛选增强 + P1 情绪趋势统计

---

## 1. 总体范围与架构

### 1.1 本次交付范围

| 功能 | 优先级 | 交付内容 |
|------|--------|----------|
| 数据导入 / 导出 | P0 | Settings 页 + 备份 JSON 格式 + Web/移动端双端导出导入 |
| 搜索与筛选增强 | P1 | Log Flow 日期范围、标签、关键词联合筛选 + 排序 |
| 情绪趋势统计 | P1 | CurrentEmotion 页内「记录 / 统计」Tab + 近 7/30 天折线图 + 子情绪分布 |

### 1.2 新增依赖

- `recharts`：情绪折线与分布图。
- `@capacitor/filesystem`：移动端本地文件写入/读取。
- `@capacitor/share`：移动端导出后调用系统分享。

### 1.3 架构原则

1. **本地优先**：备份 JSON 完全离线生成，不经过任何服务器。
2. **版本化备份**：JSON 头部带 `version` 与 `exportedAt`，未来做 migration 时兼容。
3. **Store 作为唯一数据源**：导入后通过 Zustand actions 写入，persist 自动落盘；不需要手动操作 localStorage。
4. **平台适配隔离**：把 Web/移动端文件 IO 封装到 `src/lib/fileIO.ts`，UI 层不直接判断平台。
5. **安全默认**：导入严格校验、白名单解析、文件大小限制、错误信息脱敏。

---

## 2. 数据导入 / 导出

### 2.1 备份 JSON 格式

文件名：`flash-backup-YYYYMMDD-HHmmss.json`

```json
{
  "version": "flash-backup-v1",
  "exportedAt": "2026-07-13T12:34:56.789Z",
  "appVersion": "0.1.0",
  "notes": "",
  "logs": [ { ...LogItem... } ],
  "emotions": [ { ...EmotionRecord... } ]
}
```

- `version`：用于未来 migration。
- `exportedAt`：便于用户识别备份时效。
- `appVersion`：便于排查兼容问题。
- `notes`：可选备注，导出时可由用户填写（如「换机前备份」），导入成功后可回显。

### 2.2 平台 IO 适配

封装 `src/lib/fileIO.ts`：

- **Web 导出**：`Blob` + `URL.createObjectURL` + 程序化点击 `<a download>`，用后立即 `URL.revokeObjectURL`。
- **Web 导入**：隐藏 `<input type="file" accept=".json,application/json">` + `FileReader.readAsText`。
- **移动端导出**：`@capacitor/filesystem` 写入应用沙盒 `Documents` 目录，然后 `@capacitor/share` 调用系统分享。
- **移动端导入**：同样使用 `<input type="file">`（Capacitor WebView 会唤起系统文件选择器），无需引入文件选择插件。

### 2.3 导出流程（三步确认）

1. **点击导出** → 弹出「导出数据」抽屉：
   - 显示当前数据概况：「你即将导出 **128 条日志** 和 **45 条情绪记录**」。
   - 提供备注输入框（placeholder：给这份备份写个备注…）。
   - 两个按钮：「取消」「生成备份文件」。

2. **生成文件** → 根据平台自动处理：
   - **Web**：浏览器自动下载 JSON，Toast 提示「备份已下载到浏览器下载文件夹」。
   - **移动端**：文件写入本地后自动唤起系统分享面板，Toast 提示「备份已生成，请选择保存位置」。

3. **导出失败** → 明确提示原因：
   - 无数据时：「当前没有可导出的记录，先去记点什么吧～」。
   - 移动端写入失败：「无法写入本地文件，请检查存储权限」。

### 2.4 导入流程（先预览再写入）

1. **选择文件**：解析 JSON。
2. **预览备份信息**：弹出「确认导入」抽屉，展示：
   - 导出时间、应用版本、备份备注
   - 内容预览：**128 条日志 + 45 条情绪记录**
3. **选择导入方式**：
   - **合并导入（推荐）**：保留现有记录，备份中的重复记录会覆盖旧版本。
   - **覆盖导入**：用备份完全替换当前数据，现有记录将被清空。
4. **执行导入**：
   - 完成后 Toast：「已成功导入 128 条日志和 45 条情绪记录」。
   - 若存在异常，抽屉不关闭，列出具体问题。

### 2.5 导入结果反馈

```ts
interface ImportResult {
  success: boolean;
  importedLogs: number;
  importedEmotions: number;
  skippedLogs: number;
  skippedEmotions: number;
  specificIssues: string[]; // 如「3 条日志缺少 recordDate 已跳过」
}
```

---

## 3. 搜索与筛选增强（Log Flow）

### 3.1 筛选维度

| 维度 | 交互 | 说明 |
|------|------|------|
| 日期范围 | 开始 / 结束日期选择器 + 快捷选项 | 默认不限制，可选近 7 天 / 30 天 / 本月 |
| colorTag 标签 | 标签多选 | 现有标签筛选升级为多选 |
| 关键词 | 搜索框 | 内容全文搜索，保留现有交互 |
| 排序 | 下拉选择 | 默认时间倒序，可选时间正序、按 colorTag 分组 |

### 3.2 筛选面板交互

- 点击「筛选」按钮展开底部抽屉，避免顶部拥挤。
- 抽屉内分块：日期范围、标签多选、排序方式。
- 底部固定操作栏：「重置筛选」「应用（显示结果数）」。
- 应用后返回列表，顶部显示当前激活的筛选标签胶囊，可逐个删除。

### 3.3 性能保证

- 筛选逻辑放在 `useLogStore` 的 `getFilteredLogs` 中，组件层使用 `useMemo` 缓存。
- 列表已使用 `react-virtuoso`，1000 条日志内不会明显卡顿。

### 3.4 空状态

- 无匹配结果时显示：「没有找到符合条件的记录」+「清除筛选」按钮。

---

## 4. 情绪趋势统计

### 4.1 入口设计

在 `CurrentEmotion` 页面顶部增加「记录 / 统计」Tab：

- **记录**：现有滑块、子情绪、历史列表。
- **统计**：新增图表视图。

切换动画使用 `framer-motion` 淡入淡出。

### 4.2 图表内容

默认展示「近 7 天」，可切换「近 30 天」：

1. **情绪等级折线图**
   - X 轴：日期（如 07-07 ~ 07-13）。
   - Y 轴：情绪等级 `-3 ~ 3`。
   - 同一天多条记录取平均等级。
   - 折线颜色使用 `LEVEL_COLORS` 渐变。
   - 无数据时显示占位提示。

2. **子情绪分布图**
   - 横向条形图展示「伤心 / 生气 / 难受」出现次数。
   - 仅统计等级为负且选了子情绪的数据。

### 4.3 数据聚合

新增 `src/lib/emotionStats.ts`：

```ts
export function getDailyAverages(emotions: EmotionRecord[], days: number);
export function getSubEmotionDistribution(emotions: EmotionRecord[], days: number);
```

- 纯函数，便于单元测试。
- 组件内使用 `useMemo` 缓存。

### 4.4 图表动效

- 初次加载使用透明度淡入。
- 折线绘制与柱形升起可保留 300~500ms 进入动画。
- 禁用复杂的悬浮/交互动效，保持克制。

---

## 5. UI/UX 统一原则

1. **一页一主任务**
   - Log Flow 列表页只负责浏览，筛选、编辑、详情全部用抽屉承载。
   - Settings 页按「数据管理 / 关于」分组。

2. **操作反馈即时且口语化**
   - 不用「操作成功」，改用「备份已生成」「已导入 128 条记录」。
   - 空状态、错误状态用「下一步可以做什么」引导。

3. **减少输入与决策负担**
   - 日期范围提供快捷选项。
   - 导入默认推荐「合并导入」。
   - 危险操作需要二次确认并高亮后果。

4. **视觉一致性**
   - 复用 `LiquidGlassCard` / `liquid-glass-*` 样式。
   - 图表颜色使用 `LEVEL_COLORS` 和 `TAG_COLORS`。
   - 图标统一使用 `lucide-react`。

5. **动效克制**
   - 列表、抽屉、Tab 切换沿用现有动效。
   - 统计图表进入动画控制在 500ms 内。

---

## 6. 文件与模块变更清单

### 新增文件

| 路径 | 用途 |
|------|------|
| `src/pages/Settings/index.tsx` | 设置页 |
| `src/pages/LogFlow/FilterDrawer.tsx` | Log Flow 筛选抽屉 |
| `src/pages/CurrentEmotion/StatsPanel.tsx` | 情绪统计图表面板 |
| `src/lib/backup.ts` | 备份 JSON 序列化、校验、合并/覆盖逻辑 |
| `src/lib/fileIO.ts` | Web / 移动端文件 IO 封装 |
| `src/lib/emotionStats.ts` | 情绪数据聚合计算 |

### 修改文件

| 路径 | 修改内容 |
|------|----------|
| `src/App.tsx` | 增加 `Settings` 页面分支 |
| `src/stores/logStore.ts` | 增加导入/覆盖 actions；扩展筛选状态 |
| `src/stores/emotionStore.ts` | 增加导入/覆盖 actions |
| `src/pages/LogFlow/index.tsx` | 接入 `FilterDrawer` 与增强筛选 |
| `src/pages/CurrentEmotion/index.tsx` | 增加 Tab 与 `StatsPanel` |
| `src/pages/LogStream/index.tsx` | 右上角增加设置入口 |
| `package.json` | 新增 `recharts`、`@capacitor/filesystem`、`@capacitor/share` |

### 复用而非新增

- 导入/导出确认、清除数据二次确认：复用现有 `ConfirmDrawer`。
- 设置页分组卡片：复用现有 `LiquidGlassCard`。

---

## 7. 测试策略

### 7.1 单元测试

- `src/lib/backup.test.ts`：序列化、校验、合并/覆盖、异常跳过。
- `src/lib/emotionStats.test.ts`：近 7/30 天平均、子情绪分布。

### 7.2 集成测试

- `src/pages/Settings/Settings.test.tsx`：导出/导入基础交互、清除数据二次确认。
- `src/pages/LogFlow/LogFlow.test.tsx`：筛选抽屉、多维度筛选结果。

### 7.3 验证命令

```bash
npm run lint
npm run format:check
npx tsc -b --noEmit
npm run test:run
npm run build
```

---

## 8. 安全与隐私加固

### 8.1 用户数据安全

| 措施 | 说明 |
|------|------|
| 严格输入校验 | 白名单解析，拒绝未知字段 |
| 结构级拒绝 | 必填字段缺失、版本不匹配、超大文件直接拒绝 |
| ID / 日期消毒 | 验证 UUID 与有效 ISO 日期 |
| 内容转义 | 纯文本渲染，不执行 HTML/JS |
| 文件大小限制 | 导入文件超过 10 MB 拒绝 |
| 不收集设备标识 | 备份不含设备 ID、位置等 |
| 安全导出 | Web 使用一次性 Blob URL，移动端写入应用沙盒 |

### 8.2 工程安全

| 措施 | 说明 |
|------|------|
| 无密钥入仓 | keystore、API key、私钥不提交 |
| 依赖最小化 | 仅引入官方维护库并锁定 lockfile |
| 无动态执行 | 不使用 `eval` / `new Function` |
| 错误信息脱敏 | 用户提示口语化，不暴露堆栈 |
| 回滚与容错 | 导入异常可回滚，危险操作二次确认 |

---

## 9. 风险与回退

| 风险 | 影响 | 应对 |
|------|------|------|
| 导入时用户误覆盖数据 | 高 | 默认合并导入；覆盖导入二次确认 |
| 移动端文件权限被拒绝 | 中 | 明确提示；导入用 `<input type="file">` 绕过读取权限 |
| `recharts` 包体积增加 | 中 | 按需引入；超预算可降级为 SVG |
| 1000+ 日志筛选卡顿 | 中 | 已有虚拟列表；必要时再引入分页 |
| 新依赖与 Capacitor 版本冲突 | 低 | 安装后执行 `npx cap sync` 并双端构建验证 |

**回退策略**：所有变更在独立 commit 中进行，单个功能可独立 revert。
