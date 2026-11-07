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

function escapeSearchText(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * 全局搜索，口径与 FlashCore/Domain/GlobalSearch.swift 一致：大小写不敏感；日志匹配正文与
 * 标签名（当前语言），情绪匹配备注或情绪名，任务匹配标题与备注；按创建时间倒序取前 limit 条。
 */
export function globalSearch(logs: LogItem[], emotions: EmotionRecord[], tasks: TaskItem[],
  query: string, limit: number = 20): SearchMatch[] {
  const needle = query.trim();
  if (needle === '') return [];
  const pattern = new RegExp(escapeSearchText(needle), 'iu');
  const matches: SearchMatch[] = [];
  logs.forEach((item: LogItem) => {
    if (pattern.test(item.content) || pattern.test(colorTagName(item.colorTag))) {
      matches.push({ id: item.id, kind: SearchMatchKind.LOG, title: item.content, createdAt: item.createdAt });
    }
  });
  emotions.forEach((item: EmotionRecord) => {
    const title = `${emotionEmoji(item.level)} ${item.note ?? emotionName(item.level)}`;
    if (pattern.test(title)) {
      matches.push({ id: item.id, kind: SearchMatchKind.EMOTION, title: title, createdAt: item.createdAt });
    }
  });
  tasks.forEach((item: TaskItem) => {
    if (pattern.test(item.title) || pattern.test(item.notes ?? '')) {
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
  const needle = query.trim();
  if (needle === '') return [{ text: title, hit: false }];
  const pattern = new RegExp(escapeSearchText(needle), 'giu');
  const parts: HighlightPart[] = [];
  let start = 0;
  let match = pattern.exec(title);
  while (match !== null) {
    if (match.index > start) parts.push({ text: title.slice(start, match.index), hit: false });
    parts.push({ text: match[0], hit: true });
    start = pattern.lastIndex;
    match = pattern.exec(title);
  }
  if (start < title.length) parts.push({ text: title.slice(start), hit: false });
  return parts;
}
