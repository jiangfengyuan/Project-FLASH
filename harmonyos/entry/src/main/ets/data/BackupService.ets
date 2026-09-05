import {
  BackupDocument,
  BackupData,
  CATEGORIES,
  COLOR_TAGS,
  EmotionRecord,
  LogItem,
  SUB_EMOTIONS,
  TaskDueKind,
  TaskItem
} from '../models/Models';
import { util } from '@kit.ArkTS';
import { isoNow } from './DateUtils';

export class BackupImport {
  logs: LogItem[] = [];
  emotions: EmotionRecord[] = [];
  skippedLogs: number = 0;
  skippedEmotions: number = 0;
  tasks: TaskItem[] = [];
  skippedTasks: number = 0;
  sourceVersion: string = '';
}

/** JSON.parse overwrites duplicate object keys, so strict import scans the raw text first. */
class StrictJSONScanner {
  private index: number = 0;
  private readonly text: string;

  private constructor(text: string) {
    this.text = text;
  }

  static validate(text: string): void {
    const scanner = new StrictJSONScanner(text);
    scanner.value(0);
    scanner.whitespace();
    if (scanner.index !== text.length) scanner.fail();
  }

  private value(depth: number): void {
    this.whitespace();
    if (depth > 128 || this.index >= this.text.length) this.fail();
    switch (this.text[this.index]) {
      case '{': {
        this.index++;
        if (this.take('}')) return;
        const keys = new Set<string>();
        do {
          this.whitespace();
          const key = this.string();
          if (keys.has(key)) throw new Error(`/：JSON 对象包含重复键：${key}`);
          keys.add(key);
          this.expect(':');
          this.value(depth + 1);
        } while (this.take(','));
        this.expect('}');
        return;
      }
      case '[':
        this.index++;
        if (this.take(']')) return;
        do this.value(depth + 1); while (this.take(','));
        this.expect(']');
        return;
      case '"': this.string(); return;
      case 't': this.literal('true'); return;
      case 'f': this.literal('false'); return;
      case 'n': this.literal('null'); return;
      default: this.number();
    }
  }

  private string(): string {
    if (this.index >= this.text.length || this.text[this.index++] !== '"') this.fail();
    let result = '';
    while (this.index < this.text.length) {
      const character = this.text[this.index++];
      if (character === '"') return result;
      if (character.charCodeAt(0) < 0x20) this.fail();
      if (character !== '\\') {
        result += character;
        continue;
      }
      if (this.index >= this.text.length) this.fail();
      const escape = this.text[this.index++];
      switch (escape) {
        case '"': case '\\': case '/': result += escape; break;
        case 'b': result += '\b'; break;
        case 'f': result += '\f'; break;
        case 'n': result += '\n'; break;
        case 'r': result += '\r'; break;
        case 't': result += '\t'; break;
        case 'u': {
          let codeUnit = 0;
          for (let count = 0; count < 4; count++) {
            if (this.index >= this.text.length) this.fail();
            const digit = StrictJSONScanner.hex(this.text[this.index++]);
            if (digit < 0) this.fail();
            codeUnit = codeUnit * 16 + digit;
          }
          result += String.fromCharCode(codeUnit);
          break;
        }
        default: this.fail();
      }
    }
    this.fail();
  }

  private static hex(character: string): number {
    const value = character.charCodeAt(0);
    if (value >= 0x30 && value <= 0x39) return value - 0x30;
    if (value >= 0x41 && value <= 0x46) return value - 0x41 + 10;
    if (value >= 0x61 && value <= 0x66) return value - 0x61 + 10;
    return -1;
  }

  private number(): void {
    if (this.text[this.index] === '-') this.index++;
    if (this.index >= this.text.length) this.fail();
    if (this.text[this.index] === '0') this.index++; else this.digits();
    if (this.text[this.index] === '.') { this.index++; this.digits(); }
    if (this.text[this.index] === 'e' || this.text[this.index] === 'E') {
      this.index++;
      if (this.text[this.index] === '+' || this.text[this.index] === '-') this.index++;
      this.digits();
    }
  }

  private digits(): void {
    const start = this.index;
    while (this.index < this.text.length && this.text[this.index] >= '0' && this.text[this.index] <= '9') this.index++;
    if (this.index === start) this.fail();
  }

  private literal(value: string): void {
    if (!this.text.startsWith(value, this.index)) this.fail();
    this.index += value.length;
  }

  private whitespace(): void {
    while (this.index < this.text.length && ' \t\r\n'.includes(this.text[this.index])) this.index++;
  }

  private take(character: string): boolean {
    this.whitespace();
    if (this.text[this.index] !== character) return false;
    this.index++;
    return true;
  }

  private expect(character: string): void {
    if (!this.take(character)) this.fail();
  }

  private fail(): never {
    throw new Error(`/：JSON 语法不合法（位置 ${this.index}）`);
  }
}

export class BackupService {
  static readonly VERSION: string = 'flash-backup-v2';
  static readonly LEGACY_VERSION: string = 'flash-backup-v1';
  static readonly MAX_BYTES: number = 50 * 1024 * 1024;
  /** Stamped into exported documents. AppController overwrites this from the
   * bundle info at startup; the literal only survives as a fallback. */
  static appVersion: string = '0.1.0';
  private static readonly MAX_FIELD_LENGTH: number = 100000;
  // Keep imports bounded even when a small, adversarial JSON file contains huge arrays.
  private static readonly MAX_ENTRY_COUNT: number = 100000;
  private static readonly UUID_PATTERN: RegExp = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
  private static readonly DAY_PATTERN: RegExp = /^\d{4}-\d{2}-\d{2}$/;
  private static readonly ISO_PATTERN: RegExp =
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})$/;

  static exportJSON(logs: LogItem[], emotions: EmotionRecord[], tasks: TaskItem[] = [],
    notes: string = ''): string {
    const data: BackupData = {
      logs: logs,
      emotions: emotions,
      tasks: tasks
    };
    const document: BackupDocument = {
      version: BackupService.VERSION,
      exportedAt: isoNow(),
      appVersion: BackupService.appVersion,
      notes: notes,
      schemas: { logs: 1, emotions: 1, tasks: 1 },
      data: data
    };
    const validated = BackupService.parseStrict(JSON.stringify(document));
    document.data = { logs: validated.logs, emotions: validated.emotions, tasks: validated.tasks };
    return JSON.stringify(document, null, 2);
  }

  static parse(json: string): BackupImport {
    if (new util.TextEncoder().encodeInto(json).length > BackupService.MAX_BYTES) {
      throw new Error('备份文件超过 50 MB');
    }
    let document: BackupDocument;
    try {
      document = JSON.parse(json) as BackupDocument;
    } catch (_) {
      throw new Error('备份文件不是有效的 JSON 对象');
    }
    if (document.version !== BackupService.VERSION && document.version !== BackupService.LEGACY_VERSION) {
      throw new Error('备份版本不兼容');
    }
    let sourceLogs: LogItem[];
    let sourceEmotions: EmotionRecord[];
    let sourceTasks: TaskItem[];
    if (document.version === BackupService.LEGACY_VERSION) {
      if (!Array.isArray(document.logs) || !Array.isArray(document.emotions)) {
        throw new Error('备份数据结构不完整');
      }
      sourceLogs = document.logs;
      sourceEmotions = document.emotions;
      sourceTasks = [];
    } else {
      const schemas = document.schemas;
      const data = document.data;
      if (!schemas || schemas.logs !== 1 || schemas.emotions !== 1 || schemas.tasks !== 1 ||
        !data || !Array.isArray(data.logs) || !Array.isArray(data.emotions) || !Array.isArray(data.tasks)) {
        throw new Error('备份数据结构不完整或分区版本不兼容');
      }
      sourceLogs = data.logs;
      sourceEmotions = data.emotions;
      sourceTasks = data.tasks;
    }
    if (!Array.isArray(sourceLogs) || !Array.isArray(sourceEmotions)) {
      throw new Error('备份数据结构不完整');
    }
    const result = new BackupImport();
    result.sourceVersion = document.version;
    const logIds = new Set<string>();
    for (let index = 0; index < sourceLogs.length; index++) {
      if (index >= BackupService.MAX_ENTRY_COUNT) {
        result.skippedLogs += sourceLogs.length - index;
        break;
      }
      const item = sourceLogs[index];
      if (BackupService.validLog(item) && !logIds.has(item.id)) {
        logIds.add(item.id);
        result.logs.push({
          id: item.id,
          content: item.content,
          colorTag: item.colorTag,
          category: item.category,
          importance: item.importance,
          createdAt: BackupService.normalizedISO(item.createdAt),
          recordDate: item.recordDate
        });
      } else {
        result.skippedLogs++;
      }
    }
    const emotionIds = new Set<string>();
    for (let index = 0; index < sourceEmotions.length; index++) {
      if (index >= BackupService.MAX_ENTRY_COUNT) {
        result.skippedEmotions += sourceEmotions.length - index;
        break;
      }
      const item = sourceEmotions[index];
      if (BackupService.validEmotion(item) && !emotionIds.has(item.id)) {
        emotionIds.add(item.id);
        result.emotions.push({
          id: item.id,
          level: item.level,
          subEmotion: item.subEmotion ?? undefined,
          status: item.status ?? undefined,
          note: item.note ?? undefined,
          recordDate: item.recordDate,
          createdAt: BackupService.normalizedISO(item.createdAt)
        });
      } else {
        result.skippedEmotions++;
      }
    }
    const taskIds = new Set<string>();
    for (let index = 0; index < sourceTasks.length; index++) {
      if (index >= BackupService.MAX_ENTRY_COUNT) {
        result.skippedTasks += sourceTasks.length - index;
        break;
      }
      const item = sourceTasks[index];
      if (BackupService.validTask(item) && !taskIds.has(item.id)) {
        taskIds.add(item.id);
        result.tasks.push(BackupService.normalizedTask(item));
      } else {
        result.skippedTasks++;
      }
    }
    return result;
  }

  static parseStrict(json: string): BackupImport {
    if (json.startsWith('\uFEFF')) throw new Error('/：不允许 BOM');
    if (new util.TextEncoder().encodeInto(json).length > BackupService.MAX_BYTES) throw new Error('/：文件超过 50 MiB');
    StrictJSONScanner.validate(json);
    const result = BackupService.parse(json);
    const document = JSON.parse(json) as BackupDocument;
    BackupService.checkFields(document, ['version', 'exportedAt', 'appVersion', 'notes', 'schemas', 'data'], [], '/');
    if (result.sourceVersion !== BackupService.VERSION || !BackupService.validISO(document.exportedAt) ||
      typeof document.appVersion !== 'string' || typeof document.notes !== 'string' ||
      document.notes.length > BackupService.MAX_FIELD_LENGTH) throw new Error('/：备份版本或元信息不合法');
    BackupService.checkFields(document.schemas, ['logs', 'emotions', 'tasks'], [], '/schemas');
    BackupService.checkFields(document.data, ['logs', 'emotions', 'tasks'], [], '/data');
    const data = document.data;
    if (!data) throw new Error("/data：必须是对象");
    if (data.logs.length > BackupService.MAX_ENTRY_COUNT || data.emotions.length > BackupService.MAX_ENTRY_COUNT ||
      data.tasks.length > BackupService.MAX_ENTRY_COUNT) throw new Error('/data：数组超过上限');
    data.logs.forEach((item: LogItem, i: number) => {
      BackupService.checkFields(item, ['id', 'content', 'colorTag', 'category', 'importance', 'createdAt', 'recordDate'], [], `/data/logs/${i}`);
    });
    data.emotions.forEach((item: EmotionRecord, i: number) => {
      BackupService.checkFields(item, ['id', 'level', 'createdAt', 'recordDate'], ['subEmotion', 'note', 'status'], `/data/emotions/${i}`);
    });
    data.tasks.forEach((item: TaskItem, i: number) => {
      BackupService.checkFields(item, ['id', 'title', 'colorTag', 'importance', 'due', 'createdAt', 'updatedAt'], ['notes', 'reminderAt', 'completedAt'], `/data/tasks/${i}`);
      BackupService.checkFields(item.due, item.due.kind === TaskDueKind.ALL_DAY ? ['kind', 'date'] : ['kind', 'at', 'timeZone'], [], `/data/tasks/${i}/due`);
    });
    if (result.skippedLogs + result.skippedEmotions + result.skippedTasks !== 0) throw new Error('/data：存在非法或重复记录，请使用损坏文件恢复入口');
    return result;
  }

  static parseRecovery(json: string): BackupImport {
    const result = BackupService.parse(json);
    const document = JSON.parse(json) as BackupDocument;
    const legacy = result.sourceVersion === BackupService.LEGACY_VERSION;
    BackupService.checkFields(document, [], legacy ? ['version', 'exportedAt', 'appVersion', 'notes', 'logs', 'emotions'] : ['version', 'exportedAt', 'appVersion', 'notes', 'schemas', 'data'], '/');
    if (!legacy) {
      BackupService.checkFields(document.schemas, ['logs', 'emotions', 'tasks'], [], '/schemas');
      BackupService.checkFields(document.data, ['logs', 'emotions', 'tasks'], [], '/data');
    }
    const logs = legacy ? (document.logs ?? []) : (document.data?.logs ?? []);
    const emotions = legacy ? (document.emotions ?? []) : (document.data?.emotions ?? []);
    logs.forEach((item: LogItem, i: number) => {
      if (item && typeof item === 'object' && !Array.isArray(item)) BackupService.checkFields(item, [], ['id', 'content', 'colorTag', 'category', 'importance', 'createdAt', 'recordDate'], `/data/logs/${i}`);
    });
    emotions.forEach((item: EmotionRecord, i: number) => {
      if (item && typeof item === 'object' && !Array.isArray(item)) BackupService.checkFields(item, [], ['id', 'level', 'createdAt', 'recordDate', 'note', 'status', 'subEmotion'], `/data/emotions/${i}`);
    });
    if (!legacy) document.data?.tasks.forEach((item: TaskItem, i: number) => {
      if (!item || typeof item !== 'object' || Array.isArray(item)) return;
      BackupService.checkFields(item, [], ['id', 'title', 'colorTag', 'importance', 'due', 'createdAt', 'updatedAt', 'notes', 'reminderAt', 'completedAt'], `/data/tasks/${i}`);
      if (item.due && typeof item.due === 'object' && !Array.isArray(item.due)) BackupService.checkFields(item.due, [], item.due.kind === TaskDueKind.ALL_DAY ? ['kind', 'date'] : ['kind', 'at', 'timeZone'], `/data/tasks/${i}/due`);
    });
    return result;
  }

  private static checkFields(value: Object | undefined, required: string[], optional: string[], path: string): void {
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error(`${path}：必须是对象`);
    const keys = Object.keys(value);
    if (required.some((key: string) => !keys.includes(key)) ||
      keys.some((key: string) => !required.includes(key) && !optional.includes(key))) {
      throw new Error(`${path}：缺少必填字段或包含未知字段`);
    }
  }

  private static validLog(item: LogItem): boolean {
    return !!item && typeof item.id === 'string' && BackupService.UUID_PATTERN.test(item.id) &&
      typeof item.content === 'string' && item.content.length <= BackupService.MAX_FIELD_LENGTH &&
      COLOR_TAGS.includes(item.colorTag) && CATEGORIES.includes(item.category) &&
      Number.isInteger(item.importance) && item.importance >= 0 && item.importance <= 4 &&
      BackupService.validDate(item.createdAt, item.recordDate);
  }

  private static validEmotion(item: EmotionRecord): boolean {
    if (!item) return false;
    const subValid = item.subEmotion === undefined || item.subEmotion === null || SUB_EMOTIONS.includes(item.subEmotion);
    const noteValid = item.note === undefined || item.note === null ||
      (typeof item.note === 'string' && item.note.length <= BackupService.MAX_FIELD_LENGTH);
    const statusValid = item.status === undefined || item.status === null ||
      (typeof item.status === 'string' && item.status.length <= BackupService.MAX_FIELD_LENGTH);
    return typeof item.id === 'string' && BackupService.UUID_PATTERN.test(item.id) &&
      Number.isInteger(item.level) && item.level >= -3 && item.level <= 3 &&
      subValid && noteValid && statusValid && BackupService.validDate(item.createdAt, item.recordDate);
  }

  private static validTask(item: TaskItem): boolean {
    if (!item || typeof item.id !== 'string' || !BackupService.UUID_PATTERN.test(item.id) ||
      typeof item.title !== 'string' || !item.title.trim() || item.title.length > 200 ||
      !BackupService.validOptionalText(item.notes) || !COLOR_TAGS.includes(item.colorTag) ||
      !Number.isInteger(item.importance) || item.importance < 0 || item.importance > 4 ||
      !item.due || (item.due.kind !== TaskDueKind.ALL_DAY && item.due.kind !== TaskDueKind.DATE_TIME) ||
      !BackupService.validISO(item.createdAt) || !BackupService.validISO(item.updatedAt) ||
      new Date(item.updatedAt).getTime() < new Date(item.createdAt).getTime() ||
      !BackupService.validOptionalISO(item.reminderAt) || !BackupService.validOptionalISO(item.completedAt)) {
      return false;
    }
    if (item.due.kind === TaskDueKind.ALL_DAY) {
      return typeof item.due.date === 'string' && BackupService.validDay(item.due.date);
    }
    return typeof item.due.at === 'string' && BackupService.validISO(item.due.at) &&
      typeof item.due.timeZone === 'string' && BackupService.validTimeZone(item.due.timeZone);
  }

  private static normalizedTask(item: TaskItem): TaskItem {
    return {
      id: item.id,
      title: item.title.trim(),
      notes: item.notes ?? undefined,
      colorTag: item.colorTag,
      importance: item.importance,
      due: item.due.kind === TaskDueKind.ALL_DAY ?
        { kind: TaskDueKind.ALL_DAY, date: item.due.date } :
        { kind: TaskDueKind.DATE_TIME, at: BackupService.normalizedISO(item.due.at),
          timeZone: item.due.timeZone },
      reminderAt: item.reminderAt ? BackupService.normalizedISO(item.reminderAt) : undefined,
      completedAt: item.completedAt ? BackupService.normalizedISO(item.completedAt) : undefined,
      createdAt: BackupService.normalizedISO(item.createdAt),
      updatedAt: BackupService.normalizedISO(item.updatedAt)
    };
  }

  private static validOptionalText(value?: string | null): boolean {
    return value === undefined || value === null ||
      (typeof value === 'string' && value.length <= BackupService.MAX_FIELD_LENGTH);
  }

  private static validOptionalISO(value?: string | null): boolean {
    return value === undefined || value === null || BackupService.validISO(value);
  }

  private static validISO(value?: string): boolean {
    if (typeof value !== 'string' || !BackupService.ISO_PATTERN.test(value) ||
      !BackupService.validDay(value.slice(0, 10))) return false;
    const time = value.slice(11, 19).split(':').map((part: string) => Number.parseInt(part));
    if (time.length !== 3 || time[0] > 23 || time[1] > 59 || time[2] > 59) return false;
    if (!value.endsWith('Z')) {
      const zone = value.slice(-5).split(':').map((part: string) => Number.parseInt(part));
      if (zone.length !== 2 || zone[0] > 23 || zone[1] > 59) return false;
    }
    const year = new Date(value).getUTCFullYear();
    return !value.endsWith('-00:00') && year >= 1 && year <= 9999;
  }

  static normalizedTimestamp(value: string): string {
    if (!BackupService.validISO(value)) throw new Error('/updatedAt：任务时间不合法');
    return BackupService.normalizedISO(value);
  }

  private static normalizedISO(value?: string): string {
    return new Date(value ?? 0).toISOString();
  }

  private static validTimeZone(value: string): boolean {
    if (/^(?:[+-]|GMT[+-]|UTC[+-])/.test(value)) return false;
    try {
      new Intl.DateTimeFormat('en-US', { timeZone: value }).format(new Date(0));
      return true;
    } catch (_) {
      return false;
    }
  }

  private static validDate(createdAt: string, recordDate: string): boolean {
    if (!BackupService.validISO(createdAt)) return false;
    return BackupService.validDay(recordDate);
  }

  private static validDay(recordDate: string): boolean {
    if (typeof recordDate !== 'string' || !BackupService.DAY_PATTERN.test(recordDate)) return false;
    const date = new Date(`${recordDate}T00:00:00Z`);
    return date.getUTCFullYear() >= 1 && !Number.isNaN(date.getTime()) && date.toISOString().startsWith(recordDate);
  }
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
