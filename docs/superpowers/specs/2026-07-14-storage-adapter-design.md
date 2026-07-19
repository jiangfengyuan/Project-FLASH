# Flash 数据持久化升级设计

> 日期：2026-07-14  
> 范围：本地存储升级（localStorage → SQLite/IndexedDB）+ JSON 导出/导入 + 自动迁移  
> 不涉及：Supabase 云端同步、端到端加密

---

## 1. 背景与目标

当前 `logStore` 与 `emotionStore` 使用 Zustand 的 `persist` 中间件将数据序列化后存入 `localStorage`。存在以下问题：

- 容量受限（通常 5–10 MB），图片/大量日志场景下容易触顶
- Capacitor 原生端没有真正利用 SQLite，数据可靠性不如原生数据库
- 不支持结构化查询、批量操作和事务
- 已有 `src/lib/backup.ts` 实现了备份格式校验，但缺少文件级导出/导入入口

本次升级目标：

1. Native 端（Capacitor Android/iOS）使用 `@capacitor-community/sqlite` 存储日志与情绪数据
2. Web 端使用 IndexedDB 作为等价存储
3. 业务层通过统一 `StorageAdapter` 接口访问，不感知底层差异
4. 首次启动自动将旧 `localStorage` 数据迁移到新存储
5. 提供 JSON 文件导出/导入（合并 + 覆盖两种模式）
6. 保持现有 `LogItem` / `EmotionRecord` 数据模型不变

---

## 2. 架构设计

### 2.1 模块位置

```
src/lib/storage/
├── types.ts                   # StorageAdapter 接口与类型
├── index.ts                   # createStorageAdapter() 工厂
├── sqliteAdapter.ts           # Capacitor SQLite 实现
├── indexedDBAdapter.ts        # Web IndexedDB 实现
├── memoryAdapter.ts           # 内存实现（测试 / 降级）
├── migrateFromLocalStorage.ts # 一次性迁移逻辑
└── exportImport.ts            # JSON 导出导入的平台封装
```

### 2.2 接口定义

```ts
export interface StorageAdapter {
  /** 初始化数据库/表，应用启动时调用一次 */
  init(): Promise<void>;

  /** Logs */
  getLogs(): Promise<LogItem[]>;
  saveLog(log: LogItem): Promise<void>;
  saveLogs(logs: LogItem[]): Promise<void>;
  deleteLog(id: string): Promise<void>;

  /** Emotions */
  getEmotions(): Promise<EmotionRecord[]>;
  saveEmotion(emotion: EmotionRecord): Promise<void>;
  saveEmotions(emotions: EmotionRecord[]): Promise<void>;
  deleteEmotion(id: string): Promise<void>;

  /** 危险操作：清空全部数据 */
  clearAll(): Promise<void>;
}
```

业务层（Zustand store）只依赖 `StorageAdapter`，不直接引用具体实现。

### 2.3 平台选择

```ts
export function createStorageAdapter(): StorageAdapter {
  if (Capacitor.isNativePlatform()) {
    return new SQLiteStorageAdapter();
  }
  return new IndexedDBStorageAdapter();
}
```

如果初始化失败，降级到 `MemoryStorageAdapter` 并弹 Toast 提示用户。

---

## 3. 数据模型

### 3.1 SQLite Schema

```sql
CREATE TABLE IF NOT EXISTS logs (
  id TEXT PRIMARY KEY,
  content TEXT NOT NULL,
  colorTag TEXT NOT NULL,
  category TEXT NOT NULL,
  importance INTEGER NOT NULL,
  createdAt TEXT NOT NULL,
  recordDate TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS emotions (
  id TEXT PRIMARY KEY,
  level INTEGER NOT NULL,
  subEmotion TEXT,
  status TEXT,
  note TEXT,
  recordDate TEXT NOT NULL,
  createdAt TEXT NOT NULL
);
```

### 3.2 IndexedDB Schema

- 数据库名：`flash-db`
- 版本：`1`
- Object stores：
  - `logs`：keyPath `id`
  - `emotions`：keyPath `id`

---

## 4. Zustand 集成

### 4.1 移除 persist 中间件

`logStore.ts` 与 `emotionStore.ts` 不再使用 `zustand/middleware` 的 `persist`。

### 4.2 启动加载

在 `App.tsx` 或 `src/main.tsx` 中增加一次性初始化逻辑：

```ts
const storage = createStorageAdapter();
await storage.init();
await migrateFromLocalStorage(storage);
const logs = await storage.getLogs();
const emotions = await storage.getEmotions();
useLogStore.getState().overwriteLogs(logs);
useEmotionStore.getState().overwriteEmotions(emotions);
```

### 4.3 Action 改造

以 `addLog` 为例：

```ts
addLog: async (content, colorTag, category = 'log') => {
  const newLog: LogItem = { ... };
  set((state) => ({ logs: [newLog, ...state.logs] }));
  await storage.saveLog(newLog);
}
```

删除、更新同理：先改 UI 状态，再异步持久化。失败时回滚状态并提示。

---

## 5. 迁移策略

### 5.1 触发条件

`migrateFromLocalStorage(storage)` 在 `storage.init()` 之后执行：

1. 读取 `localStorage` 中的 `flash-logs` 与 `flash-emotions`
2. 如果新存储为空且旧数据存在，则解析并写入
3. 迁移成功后删除旧 key，并设置 `flash-storage-migrated-v1` flag
4. 迁移失败则保留旧数据，下次启动重试，不阻塞 App

### 5.2 数据兼容性

旧 `localStorage` 中存储的是 Zustand persist 包装后的对象，结构为：

```json
{
  "state": { "logs": [...] },
  "version": 1
}
```

迁移逻辑只取 `state.logs` / `state.emotions`，忽略 `version` 等元数据。

---

## 6. 导出/导入

### 6.1 导出

复用 `src/lib/backup.ts` 中的 `exportBackup()`。

- **Web**：生成 JSON Blob，创建临时 `<a>` 触发下载，文件名为 `flash-backup-YYYY-MM-DD.json`
- **Native**：使用 `@capacitor/filesystem` 写入 `Documents/flash-backup-YYYY-MM-DD.json`，再用 `@capacitor/share` 分享/保存

### 6.2 导入

Web 与 Native 均使用 `<input type="file" accept=".json">` 选择文件。

流程：

1. 读取文件内容
2. `validateBackup()` 校验版本与字段
3. `sanitizeBackup()` 清洗并统计有效/跳过记录
4. 用户选择「合并」或「覆盖」
5. 合并：按 `id` 去重，新数据覆盖旧数据
6. 覆盖：清空现有数据后写入备份
7. 成功后刷新 store 并提示结果

---

## 7. 错误处理

| 场景 | 策略 | 用户感知 |
| --- | --- | --- |
| 存储初始化失败 | 降级到 `MemoryStorageAdapter` | Toast："本地存储初始化失败，数据仅保留在内存中" |
| 写入失败 | 回滚 store 状态 | Toast："保存失败，请重试" |
| 迁移失败 | 保留旧数据，下次重试 | 静默记录错误，首次启动不弹打扰 |
| 导入版本不兼容 | 拒绝并返回错误 | Toast："备份版本不兼容" |
| 导入部分记录异常 | 跳过异常记录，保留有效记录 | Toast："成功导入 X 条，跳过 Y 条" |

---

## 8. 测试策略

- **Unit tests**
  - `memoryAdapter.test.ts`：验证 StorageAdapter 接口全部行为
  - `migrateFromLocalStorage.test.ts`：模拟旧 localStorage 数据，验证迁移结果
  - `exportImport.test.ts`：验证导出 JSON 格式与导入合并/覆盖逻辑
- **Integration tests**
  - 在 Web 测试环境中使用 IndexedDB adapter（jsdom 不支持 IndexedDB，需用 fake-indexeddb）
  - Capacitor SQLite adapter 主要依赖真机/模拟器手动验证
- **E2E（未来）**
  - 导出 → 清空 → 导入 → 数据完整性的端到端验证

---

## 9. 依赖变更

新增依赖：

```bash
npm install @capacitor-community/sqlite
npm install -D fake-indexeddb
```

可选依赖（导出分享）：

```bash
npm install @capacitor/filesystem @capacitor/share
```

`@capacitor/filesystem` 与 `@capacitor/share` 当前项目已依赖（通过 `@capacitor/filesystem@8.1.2`、`@capacitor/share@8.0.1`）。

---

## 10. 验收标准

- [ ] Native 端（Android/iOS）数据写入 SQLite，App 杀进程重启后数据不丢失
- [ ] Web 端数据写入 IndexedDB，刷新页面后数据不丢失
- [ ] 首次启动时旧 localStorage 数据自动迁移到新存储
- [ ] 设置页可导出 JSON 备份文件
- [ ] 设置页可导入 JSON 备份文件，支持合并/覆盖
- [ ] 导入时异常记录被跳过并正确统计
- [ ] 现有 133 个单测全部通过，新增 StorageAdapter 相关测试
- [ ] `npm run lint`、`npm run format:check`、`npx tsc --noEmit`、`npm run build` 全绿

---

## 11. 未来扩展点

- 云端同步：可在 `StorageAdapter` 之上增加 `SyncEngine`，在 SQLite/IndexedDB 与 Supabase 之间双向同步
- 端到端加密：在写入 storage 前对敏感字段加密
- 数据迁移版本化：为 `StorageAdapter` 增加 `version` 与 `migrate()` 方法，支持未来表结构变更
