import {
  BackupDocument,
  CATEGORIES,
  COLOR_TAGS,
  EmotionRecord,
  LogItem,
  SUB_EMOTIONS
} from '../models/Models';
import { util } from '@kit.ArkTS';
import { isoNow } from './DateUtils';

export class BackupImport {
  logs: LogItem[] = [];
  emotions: EmotionRecord[] = [];
  skippedLogs: number = 0;
  skippedEmotions: number = 0;
}

export class BackupService {
  static readonly VERSION: string = 'flash-backup-v1';
  static readonly MAX_BYTES: number = 50 * 1024 * 1024;
  private static readonly MAX_FIELD_LENGTH: number = 100000;
  // Keep imports bounded even when a small, adversarial JSON file contains huge arrays.
  private static readonly MAX_ENTRY_COUNT: number = 100000;
  private static readonly UUID_PATTERN: RegExp = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
  private static readonly DAY_PATTERN: RegExp = /^\d{4}-\d{2}-\d{2}$/;

  static exportJSON(logs: LogItem[], emotions: EmotionRecord[], notes: string = ''): string {
    const document: BackupDocument = {
      version: BackupService.VERSION,
      exportedAt: isoNow(),
      appVersion: '0.1.0',
      notes: notes,
      logs: logs,
      emotions: emotions
    };
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
    if (document.version !== BackupService.VERSION) throw new Error('备份版本不兼容');
    if (!Array.isArray(document.logs) || !Array.isArray(document.emotions)) {
      throw new Error('备份数据结构不完整');
    }
    const result = new BackupImport();
    const logIds = new Set<string>();
    for (let index = 0; index < document.logs.length; index++) {
      if (result.logs.length >= BackupService.MAX_ENTRY_COUNT) {
        result.skippedLogs += document.logs.length - index;
        break;
      }
      const item = document.logs[index];
      if (BackupService.validLog(item) && !logIds.has(item.id)) {
        logIds.add(item.id);
        result.logs.push(item);
      } else {
        result.skippedLogs++;
      }
    }
    const emotionIds = new Set<string>();
    for (let index = 0; index < document.emotions.length; index++) {
      if (result.emotions.length >= BackupService.MAX_ENTRY_COUNT) {
        result.skippedEmotions += document.emotions.length - index;
        break;
      }
      const item = document.emotions[index];
      if (BackupService.validEmotion(item) && !emotionIds.has(item.id)) {
        emotionIds.add(item.id);
        result.emotions.push({
          id: item.id,
          level: item.level,
          subEmotion: item.subEmotion ?? undefined,
          status: item.status ?? undefined,
          note: item.note ?? undefined,
          recordDate: item.recordDate,
          createdAt: item.createdAt
        });
      } else {
        result.skippedEmotions++;
      }
    }
    return result;
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

  private static validDate(createdAt: string, recordDate: string): boolean {
    if (typeof createdAt !== 'string' || Number.isNaN(Date.parse(createdAt))) return false;
    if (typeof recordDate !== 'string' || !BackupService.DAY_PATTERN.test(recordDate)) return false;
    const date = new Date(`${recordDate}T00:00:00Z`);
    return !Number.isNaN(date.getTime()) && date.toISOString().startsWith(recordDate);
  }
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
