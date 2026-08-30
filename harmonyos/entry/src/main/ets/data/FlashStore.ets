import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';
import { Category, ColorTag, EmotionRecord, importanceFromContent, LogItem } from '../models/Models';
import { BackupService } from './BackupService';
import { dayString, isoNow } from './DateUtils';

const STORE_NAME = 'flash-aero-data';
const LOGS_KEY = 'logs-json';
const EMOTIONS_KEY = 'emotions-json';
const WELCOMED_KEY = 'welcomed';

export class FlashStore {
  static readonly instance: FlashStore = new FlashStore();

  logs: LogItem[] = [];
  emotions: EmotionRecord[] = [];
  welcomed: boolean = false;
  recoveryWarning: string = '';
  private dataPreferences?: preferences.Preferences;
  private initializing?: Promise<void>;

  async initialize(context: common.Context): Promise<void> {
    if (this.dataPreferences) return;
    if (this.initializing) return this.initializing;
    this.initializing = this.load(context);
    try {
      await this.initializing;
    } finally {
      this.initializing = undefined;
    }
  }

  private async load(context: common.Context): Promise<void> {
    this.dataPreferences = await preferences.getPreferences(context, STORE_NAME);
    const logsJson = await this.dataPreferences.get(LOGS_KEY, '[]') as string;
    const emotionsJson = await this.dataPreferences.get(EMOTIONS_KEY, '[]') as string;
    this.welcomed = await this.dataPreferences.get(WELCOMED_KEY, false) as boolean;
    this.recoveryWarning = '';
    try {
      const storedLogs = `{"version":"${BackupService.VERSION}","exportedAt":"${isoNow()}",` +
        `"appVersion":"0.1.0","notes":"local","logs":${logsJson},"emotions":[]}`;
      this.logs = BackupService.parse(storedLogs).logs;
    } catch (_) {
      this.logs = [];
      this.recoveryWarning = '检测到本地日志数据损坏，已隔离异常日志';
    }
    try {
      const storedEmotions = `{"version":"${BackupService.VERSION}","exportedAt":"${isoNow()}",` +
        `"appVersion":"0.1.0","notes":"local","logs":[],"emotions":${emotionsJson}}`;
      this.emotions = BackupService.parse(storedEmotions).emotions;
    } catch (_) {
      this.emotions = [];
      this.recoveryWarning = this.recoveryWarning ? `${this.recoveryWarning}；情绪数据也存在异常` :
        '检测到本地情绪数据损坏，已隔离异常记录';
    }
    this.sortAll();
  }

  private sortAll(): void {
    this.logs.sort((left: LogItem, right: LogItem) => right.createdAt.localeCompare(left.createdAt));
    this.emotions.sort((left: EmotionRecord, right: EmotionRecord) => right.createdAt.localeCompare(left.createdAt));
  }

  private async persist(): Promise<void> {
    if (!this.dataPreferences) return;
    await this.dataPreferences.put(LOGS_KEY, JSON.stringify(this.logs));
    await this.dataPreferences.put(EMOTIONS_KEY, JSON.stringify(this.emotions));
    await this.dataPreferences.flush();
  }

  async setWelcomed(): Promise<void> {
    this.welcomed = true;
    if (!this.dataPreferences) return;
    await this.dataPreferences.put(WELCOMED_KEY, true);
    await this.dataPreferences.flush();
  }

  async addLog(content: string, category: string = Category.LOG, colorTag?: string): Promise<void> {
    const trimmed = content.trim().slice(0, 10000);
    if (!trimmed) return;
    const item: LogItem = {
      id: util.generateRandomUUID(true),
      content: trimmed,
      colorTag: colorTag ?? (category === Category.IDEA ? ColorTag.IDEA : ColorTag.DAILY),
      category: category,
      importance: importanceFromContent(trimmed),
      createdAt: isoNow(),
      recordDate: dayString()
    };
    this.logs.unshift(item);
    await this.persist();
  }

  async deleteLog(id: string): Promise<void> {
    this.logs = this.logs.filter((item: LogItem) => item.id !== id);
    await this.persist();
  }

  async updateLog(id: string, content: string): Promise<void> {
    const trimmed = content.trim().slice(0, 10000);
    if (!trimmed) return;
    this.logs = this.logs.map((item: LogItem) => item.id === id ? {
      id: item.id,
      content: trimmed,
      colorTag: item.colorTag,
      category: item.category,
      importance: importanceFromContent(trimmed),
      createdAt: item.createdAt,
      recordDate: item.recordDate
    } : item);
    await this.persist();
  }

  async addEmotion(level: number, subEmotion?: string, note?: string): Promise<void> {
    const record: EmotionRecord = {
      id: util.generateRandomUUID(true),
      level: Math.max(-3, Math.min(3, Math.round(level))),
      subEmotion: level < 0 ? subEmotion : undefined,
      status: undefined,
      note: note?.trim().slice(0, 2000) || undefined,
      recordDate: dayString(),
      createdAt: isoNow()
    };
    this.emotions.unshift(record);
    await this.persist();
  }

  async deleteEmotion(id: string): Promise<void> {
    this.emotions = this.emotions.filter((item: EmotionRecord) => item.id !== id);
    await this.persist();
  }

  async replaceAll(logs: LogItem[], emotions: EmotionRecord[]): Promise<void> {
    this.logs = logs.slice();
    this.emotions = emotions.slice();
    this.sortAll();
    await this.persist();
  }

  async mergeAll(logs: LogItem[], emotions: EmotionRecord[]): Promise<void> {
    const logMap = new Map<string, LogItem>();
    this.logs.forEach((item: LogItem) => logMap.set(item.id, item));
    logs.forEach((item: LogItem) => logMap.set(item.id, item));
    const emotionMap = new Map<string, EmotionRecord>();
    this.emotions.forEach((item: EmotionRecord) => emotionMap.set(item.id, item));
    emotions.forEach((item: EmotionRecord) => emotionMap.set(item.id, item));
    this.logs = Array.from(logMap.values());
    this.emotions = Array.from(emotionMap.values());
    this.sortAll();
    await this.persist();
  }

  async clearAll(): Promise<void> {
    this.logs = [];
    this.emotions = [];
    await this.persist();
  }
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
