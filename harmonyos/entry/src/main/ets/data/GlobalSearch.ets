// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { tr } from './I18n';
import { emotionEmoji, emotionName, colorTagName, EmotionRecord, LogItem, TaskItem } from '../models/Models';

export enum SearchMatchKind {
  LOG = 'log',
  EMOTION = 'emotion',
  TASK = 'task'
}

export interface SearchMatch {
  id: string;
  kind: SearchMatchKind;
  title: string;
  createdAt: string;
}

export function searchKindName(kind: SearchMatchKind): string {
  if (kind === SearchMatchKind.EMOTION) return tr('情绪');
  if (kind === SearchMatchKind.TASK) return tr('任务');
  return tr('记录');
}

function contains(text: string, needle: string): boolean {
  return text.toLowerCase().includes(needle);
}

/**
 * 全局搜索，口径与 FlashCore/Domain/GlobalSearch.swift 一致：大小写不敏感；日志匹配正文与
 * 标签名（当前语言），情绪匹配备注或情绪名，任务匹配标题与备注；按创建时间倒序取前 limit 条。
 */
export function globalSearch(logs: LogItem[], emotions: EmotionRecord[], tasks: TaskItem[],
  query: string, limit: number = 20): SearchMatch[] {
  const needle = query.trim().toLowerCase();
  if (needle === '') return [];
  const matches: SearchMatch[] = [];
  logs.forEach((item: LogItem) => {
    if (contains(item.content, needle) || contains(colorTagName(item.colorTag), needle)) {
      matches.push({ id: item.id, kind: SearchMatchKind.LOG, title: item.content, createdAt: item.createdAt });
    }
  });
  emotions.forEach((item: EmotionRecord) => {
    const title = `${emotionEmoji(item.level)} ${item.note ?? emotionName(item.level)}`;
    if (contains(title, needle)) {
      matches.push({ id: item.id, kind: SearchMatchKind.EMOTION, title: title, createdAt: item.createdAt });
    }
  });
  tasks.forEach((item: TaskItem) => {
    if (contains(item.title, needle) || contains(item.notes ?? '', needle)) {
      matches.push({ id: item.id, kind: SearchMatchKind.TASK, title: item.title, createdAt: item.createdAt });
    }
  });
  matches.sort((left: SearchMatch, right: SearchMatch) => right.createdAt.localeCompare(left.createdAt));
  return matches.slice(0, limit);
}

export interface HighlightPart {
  text: string;
  hit: boolean;
}

/** 把标题切成命中与未命中的片段（大小写不敏感） */
export function highlightParts(title: string, query: string): HighlightPart[] {
  const needle = query.trim().toLowerCase();
  if (needle === '') return [{ text: title, hit: false }];
  const lower = title.toLowerCase();
  const parts: HighlightPart[] = [];
  let start = 0;
  while (start < title.length) {
    const hit = lower.indexOf(needle, start);
    if (hit < 0) break;
    if (hit > start) parts.push({ text: title.slice(start, hit), hit: false });
    parts.push({ text: title.slice(hit, hit + needle.length), hit: true });
    start = hit + needle.length;
  }
  if (start < title.length) parts.push({ text: title.slice(start), hit: false });
  return parts;
}
