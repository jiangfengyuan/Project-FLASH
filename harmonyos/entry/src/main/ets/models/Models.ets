export enum ColorTag {
  URGENT = 'urgent',
  INSPIRATION = 'inspiration',
  DAILY = 'daily',
  MEMO = 'memo',
  EMOTION = 'emotion',
  IDEA = 'idea'
}

export enum Category {
  LOG = 'log',
  IDEA = 'idea'
}

export enum SubEmotion {
  SAD = 'sad',
  ANGRY = 'angry',
  UNCOMFORTABLE = 'uncomfortable'
}

export interface LogItem {
  id: string;
  content: string;
  colorTag: string;
  category: string;
  importance: number;
  createdAt: string;
  recordDate: string;
}

export interface EmotionRecord {
  id: string;
  level: number;
  subEmotion?: string | null;
  status?: string | null;
  note?: string | null;
  recordDate: string;
  createdAt: string;
}

export interface BackupDocument {
  version: string;
  exportedAt: string;
  appVersion: string;
  notes: string;
  logs: LogItem[];
  emotions: EmotionRecord[];
}

export const COLOR_TAGS: string[] = [
  ColorTag.URGENT,
  ColorTag.INSPIRATION,
  ColorTag.DAILY,
  ColorTag.MEMO,
  ColorTag.EMOTION,
  ColorTag.IDEA
];

export const CATEGORIES: string[] = [Category.LOG, Category.IDEA];
export const SUB_EMOTIONS: string[] = [SubEmotion.SAD, SubEmotion.ANGRY, SubEmotion.UNCOMFORTABLE];

export function colorTagName(value: string): string {
  switch (value) {
    case ColorTag.URGENT: return '紧急';
    case ColorTag.INSPIRATION: return '灵感';
    case ColorTag.MEMO: return '备忘';
    case ColorTag.EMOTION: return '情绪';
    case ColorTag.IDEA: return '想法';
    default: return '日常';
  }
}

export function colorTagColor(value: string): string {
  switch (value) {
    case ColorTag.URGENT: return '#FF6B6B';
    case ColorTag.INSPIRATION: return '#FFD93D';
    case ColorTag.MEMO: return '#6BCB77';
    case ColorTag.EMOTION: return '#9B59B6';
    case ColorTag.IDEA: return '#FF9F43';
    default: return '#4D96FF';
  }
}

export function emotionName(level: number): string {
  switch (level) {
    case -3: return '非常不开心';
    case -2: return '很不开心';
    case -1: return '不开心';
    case 1: return '开心';
    case 2: return '很开心';
    case 3: return '非常开心';
    default: return '中性';
  }
}

export function emotionEmoji(level: number): string {
  switch (level) {
    case -3: return '😡';
    case -2: return '😣';
    case -1: return '😔';
    case 1: return '🙂';
    case 2: return '😊';
    case 3: return '😍';
    default: return '😐';
  }
}

export function subEmotionName(value?: string | null): string {
  switch (value) {
    case SubEmotion.SAD: return '伤心';
    case SubEmotion.ANGRY: return '生气';
    case SubEmotion.UNCOMFORTABLE: return '难受';
    default: return '';
  }
}

export function importanceFromContent(content: string): number {
  if (content.includes('!!!!')) return 4;
  if (content.includes('!!!')) return 3;
  if (content.includes('!!')) return 2;
  return 0;
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
