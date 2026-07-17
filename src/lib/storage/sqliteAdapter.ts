import type { StorageAdapter, LogItem, EmotionRecord } from './types';
import type { SQLiteDBConnection } from '@capacitor-community/sqlite';

const DB_NAME = 'flash-db';
const TABLE_LOGS = 'logs';
const TABLE_EMOTIONS = 'emotions';

export class SQLiteStorageAdapter implements StorageAdapter {
  private connection: SQLiteDBConnection | null = null;

  async init(): Promise<void> {
    if (this.connection) return;
    const { SQLiteConnection, CapacitorSQLite } = await import('@capacitor-community/sqlite');
    const sqliteConnection = new SQLiteConnection(CapacitorSQLite);
    const db = await sqliteConnection.createConnection(DB_NAME, false, 'no-encryption', 1, false);
    await db.open();
    this.connection = db;
    await this.ensureSchema();
  }

  async getLogs(): Promise<LogItem[]> {
    const db = await this.ensureDB();
    const result = await db.query(`SELECT * FROM ${TABLE_LOGS} ORDER BY createdAt DESC;`);
    return (result.values ?? []).map(rowToLog);
  }

  async saveLog(log: LogItem): Promise<void> {
    const db = await this.ensureDB();
    await db.run(
      `INSERT OR REPLACE INTO ${TABLE_LOGS} (id, content, colorTag, category, importance, createdAt, recordDate)
       VALUES (?, ?, ?, ?, ?, ?, ?);`,
      [
        log.id,
        log.content,
        log.colorTag,
        log.category,
        log.importance,
        log.createdAt,
        log.recordDate,
      ]
    );
  }

  async saveLogs(logs: LogItem[]): Promise<void> {
    const db = await this.ensureDB();
    await db.execute(`BEGIN TRANSACTION;`);
    try {
      for (const log of logs) {
        await db.run(
          `INSERT OR REPLACE INTO ${TABLE_LOGS} (id, content, colorTag, category, importance, createdAt, recordDate)
           VALUES (?, ?, ?, ?, ?, ?, ?);`,
          [
            log.id,
            log.content,
            log.colorTag,
            log.category,
            log.importance,
            log.createdAt,
            log.recordDate,
          ]
        );
      }
      await db.execute(`COMMIT;`);
    } catch (error) {
      await db.execute(`ROLLBACK;`).catch(() => {});
      throw error;
    }
  }

  async deleteLog(id: string): Promise<void> {
    const db = await this.ensureDB();
    await db.run(`DELETE FROM ${TABLE_LOGS} WHERE id = ?;`, [id]);
  }

  async getEmotions(): Promise<EmotionRecord[]> {
    const db = await this.ensureDB();
    const result = await db.query(`SELECT * FROM ${TABLE_EMOTIONS} ORDER BY createdAt DESC;`);
    return (result.values ?? []).map(rowToEmotion);
  }

  async saveEmotion(emotion: EmotionRecord): Promise<void> {
    const db = await this.ensureDB();
    await db.run(
      `INSERT OR REPLACE INTO ${TABLE_EMOTIONS} (id, level, subEmotion, status, note, recordDate, createdAt)
       VALUES (?, ?, ?, ?, ?, ?, ?);`,
      [
        emotion.id,
        emotion.level,
        emotion.subEmotion ?? null,
        emotion.status ?? null,
        emotion.note ?? null,
        emotion.recordDate,
        emotion.createdAt,
      ]
    );
  }

  async saveEmotions(emotions: EmotionRecord[]): Promise<void> {
    const db = await this.ensureDB();
    await db.execute(`BEGIN TRANSACTION;`);
    try {
      for (const emotion of emotions) {
        await db.run(
          `INSERT OR REPLACE INTO ${TABLE_EMOTIONS} (id, level, subEmotion, status, note, recordDate, createdAt)
           VALUES (?, ?, ?, ?, ?, ?, ?);`,
          [
            emotion.id,
            emotion.level,
            emotion.subEmotion ?? null,
            emotion.status ?? null,
            emotion.note ?? null,
            emotion.recordDate,
            emotion.createdAt,
          ]
        );
      }
      await db.execute(`COMMIT;`);
    } catch (error) {
      await db.execute(`ROLLBACK;`).catch(() => {});
      throw error;
    }
  }

  async deleteEmotion(id: string): Promise<void> {
    const db = await this.ensureDB();
    await db.run(`DELETE FROM ${TABLE_EMOTIONS} WHERE id = ?;`, [id]);
  }

  async clearAll(): Promise<void> {
    const db = await this.ensureDB();
    await db.execute(`BEGIN TRANSACTION;`);
    try {
      await db.execute(`DELETE FROM ${TABLE_LOGS};`);
      await db.execute(`DELETE FROM ${TABLE_EMOTIONS};`);
      await db.execute(`COMMIT;`);
    } catch (error) {
      await db.execute(`ROLLBACK;`).catch(() => {});
      throw error;
    }
  }

  private async ensureDB(): Promise<SQLiteDBConnection> {
    if (!this.connection) await this.init();
    return this.connection!;
  }

  private async ensureSchema(): Promise<void> {
    const db = this.connection!;
    await db.execute(`
      CREATE TABLE IF NOT EXISTS ${TABLE_LOGS} (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        colorTag TEXT NOT NULL,
        category TEXT NOT NULL,
        importance INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        recordDate TEXT NOT NULL
      );
    `);
    await db.execute(`
      CREATE TABLE IF NOT EXISTS ${TABLE_EMOTIONS} (
        id TEXT PRIMARY KEY,
        level INTEGER NOT NULL,
        subEmotion TEXT,
        status TEXT,
        note TEXT,
        recordDate TEXT NOT NULL,
        createdAt TEXT NOT NULL
      );
    `);
  }
}

function rowToLog(row: Record<string, unknown>): LogItem {
  return {
    id: String(row.id),
    content: String(row.content),
    colorTag: String(row.colorTag) as LogItem['colorTag'],
    category: String(row.category) as LogItem['category'],
    importance: Number(row.importance),
    createdAt: String(row.createdAt),
    recordDate: String(row.recordDate),
  };
}

function rowToEmotion(row: Record<string, unknown>): EmotionRecord {
  return {
    id: String(row.id),
    level: Number(row.level) as EmotionRecord['level'],
    subEmotion: (row.subEmotion ?? null) as EmotionRecord['subEmotion'],
    status: toOptionalString(row.status),
    note: toOptionalString(row.note),
    recordDate: String(row.recordDate),
    createdAt: String(row.createdAt),
  };
}

function toOptionalString(value: unknown): string | null {
  if (value == null) return null;
  if (typeof value === 'string') return value;
  if (typeof value === 'number' || typeof value === 'boolean' || typeof value === 'bigint') {
    return String(value);
  }
  return null;
}
