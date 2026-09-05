import { common } from '@kit.AbilityKit';
import { preferences, relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import {
  BackupData, Category, ColorTag, EmotionRecord, importanceFromContent, LogItem, TaskItem
} from '../models/Models';
import { BackupService } from './BackupService';
import { dayString, isoNow } from './DateUtils';
import { StoreChanges, StorePartition } from './StoreChanges';

const STORE_NAME = 'flash-aero-data';
const DATABASE_NAME = 'flash-aero-data.db';
const LOGS_KEY = 'logs-json';
const EMOTIONS_KEY = 'emotions-json';
const TASKS_KEY = 'tasks-json';
const WELCOMED_KEY = 'welcomed';
const THEME_MODE_KEY = 'theme-mode';
const RDB_MIGRATED_KEY = 'rdb-migrated-v1';
const QUARANTINE_LOGS_KEY = 'recovery-legacy-logs-json';
const QUARANTINE_EMOTIONS_KEY = 'recovery-legacy-emotions-json';
const QUARANTINE_TASKS_KEY = 'recovery-legacy-tasks-json';
const QUARANTINE_RDB_KEY = 'recovery-rdb-payloads-json';
// Quarantine copies live in sandbox files, not Preferences: a Preferences value
// caps near 8 KB while one payload can reach ~300 KB, and plaintext quarantine
// must not outlive the encrypted database it was recovered from.
const QUARANTINE_LOGS_FILE = 'legacy-logs.json';
const QUARANTINE_EMOTIONS_FILE = 'legacy-emotions.json';
const QUARANTINE_TASKS_FILE = 'legacy-tasks.json';
const QUARANTINE_RDB_FILE = 'rdb-payloads.json';
const LOGS_TABLE = 'logs';
const EMOTIONS_TABLE = 'emotions';
const TASKS_TABLE = 'tasks';

interface RecoveryRaw {
  logs: string;
  emotions: string;
  tasks: string;
}

interface RecoveryArchive {
  version: string;
  exportedAt: string;
  warning: string;
  raw: RecoveryRaw;
  databaseRaw: string;
}

interface RawPayloadRow {
  id: string;
  payload: string;
}

interface DatabaseRecoveryEntry {
  table: string;
  id: string;
  raw: string;
  reason: string;
  capturedAt: string;
}

export class FlashStore {
  static readonly instance: FlashStore = new FlashStore();
  readonly changes: StoreChanges = new StoreChanges();
  private writes: Promise<void> = Promise.resolve();

  /** Serialize write transactions now that independent feature actions may run
   * concurrently. A failed write does not poison the queue for the next one. */
  private enqueue(write: () => Promise<void>): Promise<void> {
    const operation = this.writes.then(async () => {
      if (!this.initialized) throw new Error('本地数据尚未加载完成，请稍后重试');
      await write();
    });
    this.writes = operation.catch(() => {});
    return operation;
  }

  logs: LogItem[] = [];
  emotions: EmotionRecord[] = [];
  tasks: TaskItem[] = [];
  welcomed: boolean = false;
  themeMode: string = 'light';
  recoveryWarning: string = '';
  hasRecoveryData: boolean = false;
  private settings?: preferences.Preferences;
  private database?: relationalStore.RdbStore;
  private initializing?: Promise<void>;
  private initialized: boolean = false;
  private filesDir: string = '';

  /** True only after initialize() completed successfully. Read paths that
   * produce user-facing exports must refuse to run before this, otherwise a
   * failed RDB load would masquerade as a legitimate empty backup. */
  get ready(): boolean {
    return this.initialized;
  }

  async initialize(context: common.Context): Promise<void> {
    if (this.initialized) return;
    if (this.initializing) return this.initializing;
    this.initializing = this.load(context);
    try {
      await this.initializing;
      this.initialized = true;
    } catch (error) {
      // `database` is assigned before schema creation and migration. Do not use
      // it as the success flag: a transient failure must remain retryable.
      this.database = undefined;
      throw error as Error;
    } finally {
      this.initializing = undefined;
    }
  }

  private async load(context: common.Context): Promise<void> {
    this.filesDir = context.filesDir;
    this.settings = await preferences.getPreferences(context, STORE_NAME);
    this.welcomed = await this.settings.get(WELCOMED_KEY, false) as boolean;
    const storedTheme = await this.settings.get(THEME_MODE_KEY, 'light') as string;
    this.themeMode = storedTheme === 'dark' ? 'dark' : 'light';
    this.database = await relationalStore.getRdbStore(context, {
      name: DATABASE_NAME,
      securityLevel: relationalStore.SecurityLevel.S1,
      encrypt: true
    });
    await this.createSchema();
    await this.migratePreferencesData();
    await this.migratePreferencesQuarantine();
    this.loadRecoveryState();
    await this.loadBusinessData();
  }

  private async createSchema(): Promise<void> {
    const database = this.requiredDatabase();
    await database.executeSql(`CREATE TABLE IF NOT EXISTS ${LOGS_TABLE} (` +
      'id TEXT PRIMARY KEY, sort_key TEXT NOT NULL, payload TEXT NOT NULL)');
    await database.executeSql(`CREATE TABLE IF NOT EXISTS ${EMOTIONS_TABLE} (` +
      'id TEXT PRIMARY KEY, sort_key TEXT NOT NULL, payload TEXT NOT NULL)');
    await database.executeSql(`CREATE TABLE IF NOT EXISTS ${TASKS_TABLE} (` +
      'id TEXT PRIMARY KEY, sort_key TEXT NOT NULL, payload TEXT NOT NULL)');
  }

  /** One-time, lossless migration from the former full-array Preferences storage. */
  private async migratePreferencesData(): Promise<void> {
    const settings = this.settings;
    if (!settings || await settings.get(RDB_MIGRATED_KEY, false) as boolean) return;
    const logsJson = await settings.get(LOGS_KEY, '[]') as string;
    const emotionsJson = await settings.get(EMOTIONS_KEY, '[]') as string;
    const tasksJson = await settings.get(TASKS_KEY, '[]') as string;
    let migratedLogs: LogItem[] = [];
    let migratedEmotions: EmotionRecord[] = [];
    let migratedTasks: TaskItem[] = [];
    this.recoveryWarning = '';
    try {
      const document = `{"version":"${BackupService.LEGACY_VERSION}","exportedAt":"${isoNow()}",` +
        `"appVersion":"0.1.0","notes":"migration","logs":${logsJson},"emotions":[]}`;
      const parsed = BackupService.parse(document);
      migratedLogs = parsed.logs;
      if (parsed.skippedLogs > 0) {
        this.keepLegacyRaw(QUARANTINE_LOGS_FILE, logsJson, '旧版日志有异常项目');
      }
    } catch (_) {
      this.keepLegacyRaw(QUARANTINE_LOGS_FILE, logsJson, '旧版日志数据损坏');
    }
    try {
      const document = `{"version":"${BackupService.LEGACY_VERSION}","exportedAt":"${isoNow()}",` +
        `"appVersion":"0.1.0","notes":"migration","logs":[],"emotions":${emotionsJson}}`;
      const parsed = BackupService.parse(document);
      migratedEmotions = parsed.emotions;
      if (parsed.skippedEmotions > 0) {
        this.keepLegacyRaw(QUARANTINE_EMOTIONS_FILE, emotionsJson, '旧版情绪有异常项目');
      }
    } catch (_) {
      this.keepLegacyRaw(QUARANTINE_EMOTIONS_FILE, emotionsJson, '旧版情绪数据损坏');
    }
    try {
      const document = `{"version":"${BackupService.VERSION}","exportedAt":"${isoNow()}",` +
        '"appVersion":"0.1.0","notes":"migration","schemas":{"logs":1,"emotions":1,"tasks":1},' +
        `"data":{"logs":[],"emotions":[],"tasks":${tasksJson}}}`;
      const parsed = BackupService.parse(document);
      migratedTasks = parsed.tasks;
      if (parsed.skippedTasks > 0) {
        this.keepLegacyRaw(QUARANTINE_TASKS_FILE, tasksJson, '旧版任务有异常项目');
      }
    } catch (_) {
      this.keepLegacyRaw(QUARANTINE_TASKS_FILE, tasksJson, '旧版任务数据损坏');
    }
    await this.replaceDatabase(migratedLogs, migratedEmotions, migratedTasks);
    await settings.put(RDB_MIGRATED_KEY, true);
    await settings.delete(LOGS_KEY);
    await settings.delete(EMOTIONS_KEY);
    await settings.delete(TASKS_KEY);
    await settings.flush();
  }

  private async loadBusinessData(): Promise<void> {
    const logValues = await this.readPayloads(LOGS_TABLE);
    const emotionValues = await this.readPayloads(EMOTIONS_TABLE);
    const taskValues = await this.readPayloads(TASKS_TABLE);
    const logs: LogItem[] = [];
    const emotions: EmotionRecord[] = [];
    const tasks: TaskItem[] = [];
    const rejected: DatabaseRecoveryEntry[] = [];
    for (const row of logValues) {
      try {
        JSON.parse(row.payload);
        const parsed = BackupService.parse(this.singlePayloadDocument(LOGS_TABLE, row.payload));
        if (parsed.logs.length === 1) logs.push(parsed.logs[0]);
        else rejected.push(this.recoveryEntry(LOGS_TABLE, row, 'validation-rejected'));
      } catch (_) {
        rejected.push(this.recoveryEntry(LOGS_TABLE, row, 'malformed-json'));
      }
    }
    for (const row of emotionValues) {
      try {
        JSON.parse(row.payload);
        const parsed = BackupService.parse(this.singlePayloadDocument(EMOTIONS_TABLE, row.payload));
        if (parsed.emotions.length === 1) emotions.push(parsed.emotions[0]);
        else rejected.push(this.recoveryEntry(EMOTIONS_TABLE, row, 'validation-rejected'));
      } catch (_) {
        rejected.push(this.recoveryEntry(EMOTIONS_TABLE, row, 'malformed-json'));
      }
    }
    for (const row of taskValues) {
      try {
        JSON.parse(row.payload);
        const parsed = BackupService.parse(this.singlePayloadDocument(TASKS_TABLE, row.payload));
        if (parsed.tasks.length === 1) tasks.push(parsed.tasks[0]);
        else rejected.push(this.recoveryEntry(TASKS_TABLE, row, 'validation-rejected'));
      } catch (_) {
        rejected.push(this.recoveryEntry(TASKS_TABLE, row, 'malformed-json'));
      }
    }
    // Persist the exact rejected bytes before hiding them from the normal view.
    // Quarantine persistence is best-effort: the originals stay in the database,
    // so a failed copy downgrades to a warning and must never fail initialization.
    const quarantined = this.persistDatabaseRecovery(rejected);
    this.logs = logs;
    this.emotions = emotions;
    this.tasks = tasks;
    this.sortAll();
    if (rejected.length > 0) {
      this.hasRecoveryData = true;
      this.appendRecoveryWarning(quarantined ?
        '数据库中有异常记录，原始内容已隔离并可导出' :
        '数据库中有异常记录，但隔离副本写入失败，原始内容仍保留在数据库中');
    }
  }

  private loadRecoveryState(): void {
    const logs = this.readQuarantineFile(QUARANTINE_LOGS_FILE);
    const emotions = this.readQuarantineFile(QUARANTINE_EMOTIONS_FILE);
    const tasks = this.readQuarantineFile(QUARANTINE_TASKS_FILE);
    const databaseRaw = this.readQuarantineFile(QUARANTINE_RDB_FILE);
    this.hasRecoveryData = this.hasRecoveryData ||
      logs.length > 0 || emotions.length > 0 || tasks.length > 0 || databaseRaw.length > 0;
    if (this.hasRecoveryData && !this.recoveryWarning) {
      this.recoveryWarning = '检测到已保留的旧版异常原始数据，可在设置中导出恢复文件';
    }
  }

  /** One-time move of quarantine payloads written to Preferences by older
   * versions. Idempotent: each key is deleted right after its file copy lands,
   * and a copy failure simply retries on the next launch. */
  private async migratePreferencesQuarantine(): Promise<void> {
    const settings = this.settings;
    if (!settings) return;
    try {
      let dirty = await this.moveLegacyQuarantine(settings, QUARANTINE_LOGS_KEY, QUARANTINE_LOGS_FILE);
      dirty = await this.moveLegacyQuarantine(settings, QUARANTINE_EMOTIONS_KEY, QUARANTINE_EMOTIONS_FILE) || dirty;
      dirty = await this.moveLegacyQuarantine(settings, QUARANTINE_TASKS_KEY, QUARANTINE_TASKS_FILE) || dirty;
      dirty = await this.moveLegacyQuarantine(settings, QUARANTINE_RDB_KEY, QUARANTINE_RDB_FILE) || dirty;
      if (dirty) await settings.flush();
    } catch (error) {
      console.error(`Flash quarantine migration failed: ${(error as Error).message}`);
    }
  }

  private async moveLegacyQuarantine(settings: preferences.Preferences, key: string, file: string): Promise<boolean> {
    const value = await settings.get(key, '') as string;
    if (!value) return false;
    if (!this.writeQuarantineFile(file, value)) return false;
    await settings.delete(key);
    return true;
  }

  /** A failed quarantine copy degrades to a warning. Losing the copy is
   * acceptable; blocking startup over it is not. */
  private keepLegacyRaw(file: string, content: string, warning: string): void {
    this.hasRecoveryData = true;
    if (this.writeQuarantineFile(file, content)) {
      this.appendRecoveryWarning(`${warning}，原始数据已保留用于恢复`);
    } else {
      this.appendRecoveryWarning(`${warning}，但恢复副本写入失败，原始数据未能保留`);
    }
  }

  private writeQuarantineFile(name: string, content: string): boolean {
    if (!this.filesDir) return false;
    try {
      const dir = `${this.filesDir}/quarantine`;
      try {
        if (!fileIo.accessSync(dir)) fileIo.mkdirSync(dir, true);
      } catch (_) {
        fileIo.mkdirSync(dir, true);
      }
      const file = fileIo.openSync(`${dir}/${name}`,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, content, { encoding: 'utf-8' });
      } finally {
        fileIo.closeSync(file);
      }
      return true;
    } catch (error) {
      console.error(`Flash quarantine write failed: ${(error as Error).message}`);
      return false;
    }
  }

  private readQuarantineFile(name: string): string {
    if (!this.filesDir) return '';
    try {
      const path = `${this.filesDir}/quarantine/${name}`;
      if (!fileIo.accessSync(path)) return '';
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      try {
        const size = fileIo.statSync(file.fd).size;
        if (size < 1) return '';
        const buffer = new ArrayBuffer(size);
        fileIo.readSync(file.fd, buffer, { length: size });
        const decoder = util.TextDecoder.create('utf-8', { fatal: false, ignoreBOM: true });
        return decoder.decodeToString(new Uint8Array(buffer));
      } finally {
        fileIo.closeSync(file);
      }
    } catch (_) {
      return '';
    }
  }

  private async readPayloads(table: string): Promise<RawPayloadRow[]> {
    const result = await this.requiredDatabase().querySql(`SELECT id, payload FROM ${table} ORDER BY sort_key DESC`);
    const values: RawPayloadRow[] = [];
    try {
      while (result.goToNextRow()) values.push({ id: result.getString(0), payload: result.getString(1) });
    } finally {
      result.close();
    }
    return values;
  }

  private singlePayloadDocument(table: string, raw: string): string {
    const logs = table === LOGS_TABLE ? `[${raw}]` : '[]';
    const emotions = table === EMOTIONS_TABLE ? `[${raw}]` : '[]';
    const tasks = table === TASKS_TABLE ? `[${raw}]` : '[]';
    return `{"version":"${BackupService.VERSION}","exportedAt":"${isoNow()}",` +
      '"appVersion":"0.1.0","notes":"local-rdb-validation",' +
      '"schemas":{"logs":1,"emotions":1,"tasks":1},' +
      `"data":{"logs":${logs},"emotions":${emotions},"tasks":${tasks}}}`;
  }

  private recoveryEntry(table: string, row: RawPayloadRow, reason: string): DatabaseRecoveryEntry {
    return { table: table, id: row.id, raw: row.payload, reason: reason, capturedAt: isoNow() };
  }

  private persistDatabaseRecovery(incoming: DatabaseRecoveryEntry[]): boolean {
    if (incoming.length === 0) return true;
    const stored = this.readQuarantineFile(QUARANTINE_RDB_FILE) || '[]';
    let entries: DatabaseRecoveryEntry[] = [];
    try {
      const parsed = JSON.parse(stored) as DatabaseRecoveryEntry[];
      if (Array.isArray(parsed)) entries = parsed;
    } catch (_) {
      entries.push({ table: 'recovery', id: 'corrupt-index', raw: stored,
        reason: 'quarantine-index-malformed', capturedAt: isoNow() });
    }
    for (const candidate of incoming) {
      const exists = entries.some((entry: DatabaseRecoveryEntry) =>
        entry.table === candidate.table && entry.id === candidate.id && entry.raw === candidate.raw);
      if (!exists) entries.push(candidate);
    }
    return this.writeQuarantineFile(QUARANTINE_RDB_FILE, JSON.stringify(entries));
  }

  private sortAll(): void {
    this.logs.sort((left: LogItem, right: LogItem) => right.createdAt.localeCompare(left.createdAt));
    this.emotions.sort((left: EmotionRecord, right: EmotionRecord) => right.createdAt.localeCompare(left.createdAt));
    this.tasks.sort((left: TaskItem, right: TaskItem) => right.updatedAt.localeCompare(left.updatedAt));
  }

  private appendRecoveryWarning(message: string): void {
    this.recoveryWarning = this.recoveryWarning ? `${this.recoveryWarning}；${message}` : message;
  }

  /**
   * Return all portable sections from one synchronous in-memory turn. Callers
   * must not assemble a backup from page-owned arrays that can lag behind RDB.
   */
  snapshot(): BackupData {
    return {
      logs: this.logs.slice(),
      emotions: this.emotions.slice(),
      tasks: this.tasks.slice()
    };
  }

  async recoveryArchive(): Promise<string | undefined> {
    if (!this.hasRecoveryData) return undefined;
    const logs = this.readQuarantineFile(QUARANTINE_LOGS_FILE);
    const emotions = this.readQuarantineFile(QUARANTINE_EMOTIONS_FILE);
    const tasks = this.readQuarantineFile(QUARANTINE_TASKS_FILE);
    const databaseRaw = this.readQuarantineFile(QUARANTINE_RDB_FILE) || '[]';
    const raw: RecoveryRaw = { logs: logs, emotions: emotions, tasks: tasks };
    const archive: RecoveryArchive = {
      version: 'flash-recovery-v1',
      exportedAt: isoNow(),
      warning: this.recoveryWarning,
      raw: raw,
      databaseRaw: databaseRaw
    };
    return JSON.stringify(archive);
  }

  async setWelcomed(): Promise<void> {
    const settings = this.settings;
    if (!settings) return;
    await settings.put(WELCOMED_KEY, true);
    await settings.flush();
    this.welcomed = true;
  }

  async setThemeMode(mode: string): Promise<void> {
    const settings = this.settings;
    if (!settings) return;
    const normalized = mode === 'dark' ? 'dark' : 'light';
    await settings.put(THEME_MODE_KEY, normalized);
    await settings.flush();
    this.themeMode = normalized;
  }

  async addLog(content: string, category: string = Category.LOG, colorTag?: string): Promise<void> {
    return this.enqueue(async () => {
      const trimmed = content.trim().slice(0, 10000);
      if (!trimmed) return;
      const item: LogItem = {
        id: util.generateRandomUUID(true), content: trimmed,
        colorTag: colorTag ?? (category === Category.IDEA ? ColorTag.IDEA : ColorTag.DAILY),
        category: category, importance: importanceFromContent(trimmed), createdAt: isoNow(), recordDate: dayString()
      };
      await this.upsert(LOGS_TABLE, item.id, item.createdAt, JSON.stringify(item));
      this.logs.unshift(item);
      this.changes.publish(StorePartition.LOGS);
    });
  }

  async deleteLog(id: string): Promise<void> {
    return this.enqueue(async () => {
      await this.requiredDatabase().executeSql(`DELETE FROM ${LOGS_TABLE} WHERE id = ?`, [id]);
      this.logs = this.logs.filter((item: LogItem) => item.id !== id);
      this.changes.publish(StorePartition.LOGS);
    });
  }

  async updateLog(id: string, content: string): Promise<void> {
    return this.enqueue(async () => {
      const trimmed = content.trim().slice(0, 10000);
      if (!trimmed) return;
      const existing = this.logs.find((item: LogItem) => item.id === id);
      if (!existing) return;
      // Editing updates the body only: importance/colorTag/category may carry
      // metadata set on another device and must survive a local text edit.
      // The `!!` importance syntax is parsed at creation time only.
      const updated: LogItem = {
        id: existing.id, content: trimmed, colorTag: existing.colorTag, category: existing.category,
        importance: existing.importance, createdAt: existing.createdAt, recordDate: existing.recordDate
      };
      await this.upsert(LOGS_TABLE, updated.id, updated.createdAt, JSON.stringify(updated));
      this.logs = this.logs.map((item: LogItem) => item.id === id ? updated : item);
      this.changes.publish(StorePartition.LOGS);
    });
  }

  async addEmotion(level: number, subEmotion?: string, note?: string): Promise<void> {
    return this.enqueue(async () => {
      const record: EmotionRecord = {
        id: util.generateRandomUUID(true), level: Math.max(-3, Math.min(3, Math.round(level))),
        subEmotion: level < 0 ? subEmotion : undefined, status: undefined,
        note: note?.trim().slice(0, 2000) || undefined, recordDate: dayString(), createdAt: isoNow()
      };
      await this.upsert(EMOTIONS_TABLE, record.id, record.createdAt, JSON.stringify(record));
      this.emotions.unshift(record);
      this.changes.publish(StorePartition.EMOTIONS);
    });
  }

  async deleteEmotion(id: string): Promise<void> {
    return this.enqueue(async () => {
      await this.requiredDatabase().executeSql(`DELETE FROM ${EMOTIONS_TABLE} WHERE id = ?`, [id]);
      this.emotions = this.emotions.filter((item: EmotionRecord) => item.id !== id);
      this.changes.publish(StorePartition.EMOTIONS);
    });
  }

  async saveTask(task: TaskItem): Promise<void> {
    return this.enqueue(async () => {
      await this.upsert(TASKS_TABLE, task.id, task.updatedAt, JSON.stringify(task));
      const exists = this.tasks.some((item: TaskItem) => item.id === task.id);
      this.tasks = exists ? this.tasks.map((item: TaskItem) => item.id === task.id ? task : item) : [task, ...this.tasks];
      this.tasks.sort((left: TaskItem, right: TaskItem) => right.updatedAt.localeCompare(left.updatedAt));
      this.changes.publish(StorePartition.TASKS);
    });
  }

  async deleteTask(id: string): Promise<void> {
    return this.enqueue(async () => {
      await this.requiredDatabase().executeSql(`DELETE FROM ${TASKS_TABLE} WHERE id = ?`, [id]);
      this.tasks = this.tasks.filter((item: TaskItem) => item.id !== id);
      this.changes.publish(StorePartition.TASKS);
    });
  }

  async replaceAll(logs: LogItem[], emotions: EmotionRecord[], tasks: TaskItem[] = []): Promise<void> {
    return this.enqueue(async () => {
      await this.replaceDatabase(logs, emotions, tasks);
      this.logs = logs.slice(); this.emotions = emotions.slice(); this.tasks = tasks.slice();
      this.sortAll();
      this.changes.publish(StorePartition.ALL);
    });
  }

  async mergeAll(logs: LogItem[], emotions: EmotionRecord[], tasks: TaskItem[] = []): Promise<void> {
    return this.enqueue(async () => {
      const logMap = new Map<string, LogItem>();
      this.logs.forEach((item: LogItem) => logMap.set(item.id, item));
      logs.forEach((item: LogItem) => logMap.set(item.id, item));
      const emotionMap = new Map<string, EmotionRecord>();
      this.emotions.forEach((item: EmotionRecord) => emotionMap.set(item.id, item));
      emotions.forEach((item: EmotionRecord) => emotionMap.set(item.id, item));
      const taskMap = new Map<string, TaskItem>();
      this.tasks.forEach((item: TaskItem) => taskMap.set(item.id, item));
      tasks.forEach((item: TaskItem) => {
        const local = taskMap.get(item.id);
        if (!local || BackupService.normalizedTimestamp(item.updatedAt) >= BackupService.normalizedTimestamp(local.updatedAt)) taskMap.set(item.id, item);
      });
      const mergedLogs = Array.from(logMap.values());
      const mergedEmotions = Array.from(emotionMap.values());
      const mergedTasks = Array.from(taskMap.values());
      await this.replaceDatabase(mergedLogs, mergedEmotions, mergedTasks);
      this.logs = mergedLogs; this.emotions = mergedEmotions; this.tasks = mergedTasks;
      this.sortAll();
      this.changes.publish(StorePartition.ALL);
    });
  }

  async clearAll(): Promise<void> {
    return this.enqueue(async () => {
      await this.replaceDatabase([], [], []);
      this.logs = []; this.emotions = []; this.tasks = [];
      this.changes.publish(StorePartition.ALL);
    });
  }

  private async upsert(table: string, id: string, sortKey: string, payload: string): Promise<void> {
    await this.requiredDatabase().insert(table, {
      'id': id, 'sort_key': sortKey, 'payload': payload
    }, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  private async replaceDatabase(logs: LogItem[], emotions: EmotionRecord[], tasks: TaskItem[]): Promise<void> {
    const database = this.requiredDatabase();
    database.beginTransaction();
    try {
      await database.executeSql(`DELETE FROM ${LOGS_TABLE}`);
      await database.executeSql(`DELETE FROM ${EMOTIONS_TABLE}`);
      await database.executeSql(`DELETE FROM ${TASKS_TABLE}`);
      await this.batchInsert(LOGS_TABLE, logs.map((item: LogItem) => this.row(item.id, item.createdAt, item)));
      await this.batchInsert(EMOTIONS_TABLE,
        emotions.map((item: EmotionRecord) => this.row(item.id, item.createdAt, item)));
      await this.batchInsert(TASKS_TABLE, tasks.map((item: TaskItem) => this.row(item.id, item.updatedAt, item)));
      database.commit();
    } catch (error) {
      database.rollBack();
      throw error as Error;
    }
  }

  private row(id: string, sortKey: string, value: Object): relationalStore.ValuesBucket {
    return { 'id': id, 'sort_key': sortKey, 'payload': JSON.stringify(value) };
  }

  private async batchInsert(table: string, rows: relationalStore.ValuesBucket[]): Promise<void> {
    const database = this.requiredDatabase();
    for (let offset = 0; offset < rows.length; offset += 5000) {
      await database.batchInsert(table, rows.slice(offset, offset + 5000));
    }
  }

  private requiredDatabase(): relationalStore.RdbStore {
    if (!this.database) throw new Error('本地数据库尚未初始化');
    return this.database;
  }
}

// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
