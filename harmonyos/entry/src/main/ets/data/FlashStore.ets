import { common } from '@kit.AbilityKit';
import { preferences, relationalStore } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import {
  BackupData, Category, ColorTag, EmotionRecord, importanceFromContent, isValidImportance, LogItem, TaskItem
} from '../models/Models';
import { BackupService } from './BackupService';
import { BackupDiff } from './BackupDiff';
import { dayString, isoNow, isValidRecordDay } from './DateUtils';
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
const QUARANTINE_FILES: string[] = [
  QUARANTINE_LOGS_FILE, QUARANTINE_EMOTIONS_FILE, QUARANTINE_TASKS_FILE, QUARANTINE_RDB_FILE
];
// Quarantine holds plaintext recovered from the encrypted database; a single
// file must stay small enough that the exposure stays bounded even if cleanup
// never runs.
const QUARANTINE_MAX_FILE_BYTES = 1024 * 1024;
// Quarantined originals expire after 30 days: they exist to bridge a support
// conversation, not to keep plaintext forever.
const QUARANTINE_TTL_MILLIS = 30 * 24 * 60 * 60 * 1000;
const LOGS_TABLE = 'logs';
const EMOTIONS_TABLE = 'emotions';
const TASKS_TABLE = 'tasks';
// Idea Reminder 的已读状态：本机界面状态（对齐 Android idea_view_state 表），
// 不写入 flash-backup-v2 备份，与业务数据同库存储但独立于快照导出。
const IDEA_VIEW_TABLE = 'idea_view_state';

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

interface ParsedRowPayload {
  ok: boolean;
  value: Object | undefined;
}

export interface LogMetaEdit {
  id: string;
  category: string;
  colorTag: string;
}

interface IdeaViewPayload {
  viewedAt?: string;
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
   * concurrently. A failed write does not poison the queue for the next one.
   * The wrapped value passes through so conditional writes can report whether
   * they applied. */
  private enqueue<T>(write: () => Promise<T>): Promise<T> {
    const operation = this.writes.then(async () => {
      if (!this.initialized) throw new Error('本地数据尚未加载完成，请稍后重试');
      return write();
    });
    // The queue tail stays void regardless of what the current operation
    // resolves to; a failed write does not poison the next one.
    this.writes = operation.then(() => {}, () => {});
    return operation;
  }

  logs: LogItem[] = [];
  emotions: EmotionRecord[] = [];
  tasks: TaskItem[] = [];
  welcomed: boolean = false;
  themeMode: string = 'light';
  recoveryWarning: string = '';
  hasRecoveryData: boolean = false;
  // 灵感已读状态（logId → viewedAt ISO），load 时从 idea_view_state 表加载。
  private viewedIdeaIds: Map<string, string> = new Map<string, string>();
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
    await this.cleanupQuarantine();
    await this.loadRecoveryState();
    await this.loadIdeaViewState();
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
    await database.executeSql(`CREATE TABLE IF NOT EXISTS ${IDEA_VIEW_TABLE} (` +
      'id TEXT PRIMARY KEY, sort_key TEXT NOT NULL, payload TEXT NOT NULL)');
  }

  /** Load local idea read state. A corrupt row degrades to "unviewed", which
   * only re-surfaces the reminder — never blocks startup. */
  private async loadIdeaViewState(): Promise<void> {
    const rows = await this.readPayloads(IDEA_VIEW_TABLE);
    const viewed = new Map<string, string>();
    for (const row of rows) {
      let viewedAt = '';
      try {
        const parsed = JSON.parse(row.payload) as IdeaViewPayload;
        viewedAt = typeof parsed.viewedAt === 'string' ? parsed.viewedAt : '';
      } catch (_) {}
      viewed.set(row.id, viewedAt);
    }
    this.viewedIdeaIds = viewed;
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
        await this.keepLegacyRaw(QUARANTINE_LOGS_FILE, logsJson, '旧版日志有异常项目');
      }
    } catch (_) {
      await this.keepLegacyRaw(QUARANTINE_LOGS_FILE, logsJson, '旧版日志数据损坏');
    }
    try {
      const document = `{"version":"${BackupService.LEGACY_VERSION}","exportedAt":"${isoNow()}",` +
        `"appVersion":"0.1.0","notes":"migration","logs":[],"emotions":${emotionsJson}}`;
      const parsed = BackupService.parse(document);
      migratedEmotions = parsed.emotions;
      if (parsed.skippedEmotions > 0) {
        await this.keepLegacyRaw(QUARANTINE_EMOTIONS_FILE, emotionsJson, '旧版情绪有异常项目');
      }
    } catch (_) {
      await this.keepLegacyRaw(QUARANTINE_EMOTIONS_FILE, emotionsJson, '旧版情绪数据损坏');
    }
    try {
      const document = `{"version":"${BackupService.VERSION}","exportedAt":"${isoNow()}",` +
        '"appVersion":"0.1.0","notes":"migration","schemas":{"logs":1,"emotions":1,"tasks":1},' +
        `"data":{"logs":[],"emotions":[],"tasks":${tasksJson}}}`;
      const parsed = BackupService.parse(document);
      migratedTasks = parsed.tasks;
      if (parsed.skippedTasks > 0) {
        await this.keepLegacyRaw(QUARANTINE_TASKS_FILE, tasksJson, '旧版任务有异常项目');
      }
    } catch (_) {
      await this.keepLegacyRaw(QUARANTINE_TASKS_FILE, tasksJson, '旧版任务数据损坏');
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
    // Row-level validation: each payload is parsed once and checked with the
    // same field validators BackupService.parse applies, instead of being
    // string-wrapped into a single-use document and parsed twice more.
    for (const row of logValues) {
      const parsed = this.parseRowPayload(row.payload);
      const item = parsed.ok ? BackupService.validatedLog(parsed.value as LogItem) : undefined;
      if (item) logs.push(item);
      else rejected.push(this.recoveryEntry(LOGS_TABLE, row, parsed.ok ? 'validation-rejected' : 'malformed-json'));
    }
    for (const row of emotionValues) {
      const parsed = this.parseRowPayload(row.payload);
      const item = parsed.ok ? BackupService.validatedEmotion(parsed.value as EmotionRecord) : undefined;
      if (item) emotions.push(item);
      else rejected.push(this.recoveryEntry(EMOTIONS_TABLE, row, parsed.ok ? 'validation-rejected' : 'malformed-json'));
    }
    for (const row of taskValues) {
      const parsed = this.parseRowPayload(row.payload);
      const item = parsed.ok ? BackupService.validatedTask(parsed.value as TaskItem) : undefined;
      if (item) tasks.push(item);
      else rejected.push(this.recoveryEntry(TASKS_TABLE, row, parsed.ok ? 'validation-rejected' : 'malformed-json'));
    }
    // Persist the exact rejected bytes before hiding them from the normal view.
    // Quarantine persistence is best-effort: the originals stay in the database,
    // so a failed copy downgrades to a warning and must never fail initialization.
    const quarantined = await this.persistDatabaseRecovery(rejected);
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

  private async loadRecoveryState(): Promise<void> {
    const logs = await this.readQuarantineFile(QUARANTINE_LOGS_FILE);
    const emotions = await this.readQuarantineFile(QUARANTINE_EMOTIONS_FILE);
    const tasks = await this.readQuarantineFile(QUARANTINE_TASKS_FILE);
    const databaseRaw = await this.readQuarantineFile(QUARANTINE_RDB_FILE);
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
    if (!(await this.writeQuarantineFile(file, value))) return false;
    await settings.delete(key);
    return true;
  }

  /** A failed quarantine copy degrades to a warning. Losing the copy is
   * acceptable; blocking startup over it is not. */
  private async keepLegacyRaw(file: string, content: string, warning: string): Promise<void> {
    this.hasRecoveryData = true;
    if (await this.writeQuarantineFile(file, content)) {
      this.appendRecoveryWarning(`${warning}，原始数据已保留用于恢复`);
    } else {
      this.appendRecoveryWarning(`${warning}，但恢复副本写入失败，原始数据未能保留`);
    }
  }

  private async writeQuarantineFile(name: string, content: string): Promise<boolean> {
    if (!this.filesDir) return false;
    try {
      if (new util.TextEncoder().encodeInto(content).length > QUARANTINE_MAX_FILE_BYTES) {
        console.error(`Flash quarantine write refused: ${name} exceeds the size cap`);
        return false;
      }
      const dir = `${this.filesDir}/quarantine`;
      try {
        if (!(await fileIo.access(dir))) await fileIo.mkdir(dir, true);
      } catch (_) {
        await fileIo.mkdir(dir, true);
      }
      const file = await fileIo.open(`${dir}/${name}`,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        await fileIo.write(file.fd, content, { encoding: 'utf-8' });
      } finally {
        await fileIo.close(file);
      }
      return true;
    } catch (error) {
      console.error(`Flash quarantine write failed: ${(error as Error).message}`);
      return false;
    }
  }

  private quarantinePath(name: string): string {
    return `${this.filesDir}/quarantine/${name}`;
  }

  private async readQuarantineFile(name: string): Promise<string> {
    if (!this.filesDir) return '';
    try {
      const path = this.quarantinePath(name);
      if (!(await fileIo.access(path))) return '';
      const file = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);
      try {
        const size = (await fileIo.stat(file.fd)).size;
        // Never load an oversized quarantine file: plaintext exposure stays
        // bounded even if a pre-upgrade leftover exceeds the cap.
        if (size < 1 || size > QUARANTINE_MAX_FILE_BYTES) return '';
        const buffer = new ArrayBuffer(size);
        await fileIo.read(file.fd, buffer, { length: size });
        const decoder = util.TextDecoder.create('utf-8', { fatal: false, ignoreBOM: true });
        return decoder.decodeToString(new Uint8Array(buffer));
      } finally {
        await fileIo.close(file);
      }
    } catch (_) {
      return '';
    }
  }

  /** Age out quarantine files. Best-effort, like every quarantine step: a
   * cleanup failure must never block startup. */
  private async cleanupQuarantine(): Promise<void> {
    if (!this.filesDir) return;
    for (const name of QUARANTINE_FILES) {
      try {
        const path = this.quarantinePath(name);
        if (!(await fileIo.access(path))) continue;
        const file = await fileIo.open(path, fileIo.OpenMode.READ_ONLY);
        let expired = false;
        try {
          // HarmonyOS Stat.mtime is documented as seconds since the epoch,
          // but some API levels report milliseconds; normalize by magnitude
          // so the TTL comparison holds in either unit.
          const mtime = (await fileIo.stat(file.fd)).mtime;
          const mtimeMillis = mtime > 1e12 ? mtime : mtime * 1000;
          expired = Number.isFinite(mtimeMillis) && (Date.now() - mtimeMillis) > QUARANTINE_TTL_MILLIS;
        } finally {
          await fileIo.close(file);
        }
        if (expired) await fileIo.unlink(path);
      } catch (error) {
        console.error(`Flash quarantine cleanup failed: ${(error as Error).message}`);
      }
    }
  }

  /** Remove every quarantine file after the originals have been handed to the
   * user (successful recovery export) or explicitly discarded. Recomputed on
   * the next launch from what remains on disk. */
  async clearQuarantine(): Promise<void> {
    if (this.filesDir) {
      for (const name of QUARANTINE_FILES) {
        try {
          const path = this.quarantinePath(name);
          if (await fileIo.access(path)) await fileIo.unlink(path);
        } catch (error) {
          console.error(`Flash quarantine clear failed: ${(error as Error).message}`);
        }
      }
    }
    this.hasRecoveryData = false;
    this.recoveryWarning = '';
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

  private parseRowPayload(payload: string): ParsedRowPayload {
    // Mirrors the old document-wrapped path: an oversized payload tripped the
    // file-size guard there and was quarantined as malformed-json.
    if (new util.TextEncoder().encodeInto(payload).length > BackupService.MAX_BYTES) {
      return { ok: false, value: undefined };
    }
    try {
      return { ok: true, value: JSON.parse(payload) as Object };
    } catch (_) {
      return { ok: false, value: undefined };
    }
  }

  private recoveryEntry(table: string, row: RawPayloadRow, reason: string): DatabaseRecoveryEntry {
    return { table: table, id: row.id, raw: row.payload, reason: reason, capturedAt: isoNow() };
  }

  private async persistDatabaseRecovery(incoming: DatabaseRecoveryEntry[]): Promise<boolean> {
    if (incoming.length === 0) return true;
    const stored = await this.readQuarantineFile(QUARANTINE_RDB_FILE) || '[]';
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
    const logs = await this.readQuarantineFile(QUARANTINE_LOGS_FILE);
    const emotions = await this.readQuarantineFile(QUARANTINE_EMOTIONS_FILE);
    const tasks = await this.readQuarantineFile(QUARANTINE_TASKS_FILE);
    const databaseRaw = await this.readQuarantineFile(QUARANTINE_RDB_FILE) || '[]';
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
      // Android 靠外键级联清理 idea_view_state；这里手动同步删除本机已读状态。
      await this.requiredDatabase().executeSql(`DELETE FROM ${IDEA_VIEW_TABLE} WHERE id = ?`, [id]);
      this.viewedIdeaIds.delete(id);
      this.logs = this.logs.filter((item: LogItem) => item.id !== id);
      this.changes.publish(StorePartition.LOGS);
    });
  }

  /** 未读灵感 = 从未在本机查看过的灵感。已读状态不进跨端备份。 */
  unviewedIdeas(): LogItem[] {
    return this.logs.filter((item: LogItem) =>
      item.category === Category.IDEA && !this.viewedIdeaIds.has(item.id));
  }

  async markIdeaViewed(id: string): Promise<void> {
    if (this.viewedIdeaIds.has(id)) return;
    return this.enqueue(async () => {
      await this.persistIdeaViewed(id, isoNow());
      this.changes.publish(StorePartition.LOGS);
    });
  }

  /** 批量已读（首页提醒行/灵感视图进入时）：一次队列写入、单次发布。 */
  async markAllIdeasViewed(): Promise<void> {
    const pending = this.unviewedIdeas();
    if (pending.length === 0) return;
    return this.enqueue(async () => {
      const viewedAt = isoNow();
      for (const item of pending) {
        await this.persistIdeaViewed(item.id, viewedAt);
      }
      this.changes.publish(StorePartition.LOGS);
    });
  }

  private async persistIdeaViewed(id: string, viewedAt: string): Promise<void> {
    await this.upsert(IDEA_VIEW_TABLE, id, viewedAt, JSON.stringify({ viewedAt: viewedAt }));
    this.viewedIdeaIds.set(id, viewedAt);
  }

  /** 覆盖导入/清空后修剪已读表，避免指向已删除记录的残留行。仅影响本地提醒，
   * 最坏结果是灵感重新显示为未读，因此不与业务替换共用同一事务。 */
  private async pruneIdeaViewState(surviving: Set<string>): Promise<void> {
    let dirty = false;
    this.viewedIdeaIds.forEach((viewedAt: string, id: string) => {
      if (!surviving.has(id)) {
        this.viewedIdeaIds.delete(id);
        dirty = true;
      }
    });
    if (!dirty) return;
    const database = this.requiredDatabase();
    await database.executeSql(`DELETE FROM ${IDEA_VIEW_TABLE}`);
    const rows: relationalStore.ValuesBucket[] = [];
    this.viewedIdeaIds.forEach((viewedAt: string, id: string) => {
      rows.push({ 'id': id, 'sort_key': viewedAt, 'payload': JSON.stringify({ viewedAt: viewedAt }) });
    });
    if (rows.length > 0) await database.batchInsert(IDEA_VIEW_TABLE, rows);
  }

  /** One queued row write publishes only after all edited fields are persisted. */
  async updateLog(id: string, content: string, category?: string, colorTag?: string, recordDate?: string,
    importance?: number): Promise<void> {
    return this.enqueue(async () => {
      const trimmed = content.trim();
      if (!trimmed) throw new Error('内容不能为空');
      if (content.length > 100000) throw new Error('内容超过 100000 字符，请删减后保存');
      if (recordDate !== undefined && !isValidRecordDay(recordDate)) throw new Error('请输入有效日期（YYYY-MM-DD）');
      if (importance !== undefined && !isValidImportance(importance)) throw new Error('重要度需在 0 到 4 之间');
      const existing = this.logs.find((item: LogItem) => item.id === id);
      if (!existing) throw new Error('这条记录已不存在');
      const updated: LogItem = {
        id: existing.id, content: trimmed, colorTag: colorTag ?? existing.colorTag, category: category ?? existing.category,
        importance: importance ?? existing.importance, createdAt: existing.createdAt, recordDate: recordDate ?? existing.recordDate
      };
      await this.upsert(LOGS_TABLE, updated.id, updated.createdAt, JSON.stringify(updated));
      this.logs = this.logs.map((item: LogItem) => item.id === id ? updated : item);
      this.changes.publish(StorePartition.LOGS);
    });
  }

  /** Meta edits (整理分类/标签) mirror updateLog in reverse: the body and the
   * creation-time importance parse stay untouched, only category/colorTag move. */
  async updateLogMeta(id: string, category: string, colorTag: string): Promise<void> {
    return this.enqueue(async () => {
      const existing = this.logs.find((item: LogItem) => item.id === id);
      if (!existing) return;
      const updated: LogItem = {
        id: existing.id, content: existing.content, colorTag: colorTag, category: category,
        importance: existing.importance, createdAt: existing.createdAt, recordDate: existing.recordDate
      };
      await this.upsert(LOGS_TABLE, updated.id, updated.createdAt, JSON.stringify(updated));
      this.logs = this.logs.map((item: LogItem) => item.id === id ? updated : item);
      this.changes.publish(StorePartition.LOGS);
    });
  }

  /** Batch form of updateLogMeta: one queued pass, one publish. A failure
   * stops the remaining rows; rows already persisted stay visible in memory,
   * matching what a per-row loop would leave behind. */
  async updateLogsMetaBatch(edits: LogMetaEdit[]): Promise<void> {
    return this.enqueue(async () => {
      const editsById = new Map<string, LogMetaEdit>();
      edits.forEach((edit: LogMetaEdit) => editsById.set(edit.id, edit));
      if (editsById.size === 0) return;
      const next = this.logs.slice();
      let applied = 0;
      let failure: Error | undefined;
      for (let index = 0; index < next.length; index++) {
        const edit = editsById.get(next[index].id);
        if (!edit) continue;
        const existing = next[index];
        const updated: LogItem = {
          id: existing.id, content: existing.content, colorTag: edit.colorTag, category: edit.category,
          importance: existing.importance, createdAt: existing.createdAt, recordDate: existing.recordDate
        };
        try {
          await this.upsert(LOGS_TABLE, updated.id, updated.createdAt, JSON.stringify(updated));
        } catch (error) {
          failure = error as Error;
          break;
        }
        next[index] = updated;
        applied++;
      }
      if (applied > 0) {
        this.logs = next;
        this.changes.publish(StorePartition.LOGS);
      }
      if (failure) throw failure;
    });
  }

  async addEmotion(level: number, subEmotion?: string, note?: string, status?: string): Promise<void> {
    return this.enqueue(async () => {
      const record: EmotionRecord = {
        id: util.generateRandomUUID(true), level: Math.max(-3, Math.min(3, Math.round(level))),
        subEmotion: level < 0 ? subEmotion : undefined,
        // 具体心情状态：PRD 语义为短文本（≤50），契约上限远高于此。
        status: status?.trim().slice(0, 50) || undefined,
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
      await this.pruneIdeaViewState(new Set<string>(logs.map((item: LogItem) => item.id)));
      this.logs = logs.slice(); this.emotions = emotions.slice(); this.tasks = tasks.slice();
      this.sortAll();
      this.changes.publish(StorePartition.ALL);
    });
  }

  /** Destructive overwrite with the staleness check inside the write queue:
   * the snapshot comparison and the database replace are one atomic step, so
   * a record written between preview and confirmation either appears in
   * `expected` (then the replace proceeds) or aborts it. Returns false when
   * the store changed and nothing was replaced. */
  async replaceAllIfCurrent(logs: LogItem[], emotions: EmotionRecord[], tasks: TaskItem[] = [],
    expected: BackupData): Promise<boolean> {
    return this.enqueue(async () => {
      if (!BackupDiff.sameData(expected, this.snapshot())) return false;
      await this.replaceDatabase(logs, emotions, tasks);
      await this.pruneIdeaViewState(new Set<string>(logs.map((item: LogItem) => item.id)));
      this.logs = logs.slice(); this.emotions = emotions.slice(); this.tasks = tasks.slice();
      this.sortAll();
      this.changes.publish(StorePartition.ALL);
      return true;
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
      await this.pruneIdeaViewState(new Set<string>());
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
