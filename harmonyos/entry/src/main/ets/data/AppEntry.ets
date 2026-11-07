// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { tr } from './I18n';

/**
 * 外部入口解析。深链与快捷方式只打开界面，不携带正文、不写数据；
 * 系统分享的文字进入快速记录面板，由用户确认后才保存。
 */
export enum EntryKind {
  CAPTURE_IDEA = 'capture-idea',
  CAPTURE_LOG = 'capture-log',
  TODAY = 'today',
  IDEAS = 'ideas',
  SHARED = 'shared'
}

export interface AppEntry {
  kind: EntryKind;
  payload: string;
}

/** flash://capture[?category=idea|log]、flash://today、flash://ideas；其余一律忽略 */
export function parseDeepLink(uri: string | undefined): AppEntry | undefined {
  if (!uri) return undefined;
  const parts = uri.split('?');
  const path = parts[0].replace(/\/$/, '');
  if (path === 'flash://capture') {
    return { kind: parts[1] === 'category=log' ? EntryKind.CAPTURE_LOG : EntryKind.CAPTURE_IDEA, payload: '' };
  }
  if (path === 'flash://today') return { kind: EntryKind.TODAY, payload: '' };
  if (path === 'flash://ideas') return { kind: EntryKind.IDEAS, payload: '' };
  return undefined;
}

/** 卡片、快捷方式与通知的命名入口 */
export function namedEntry(name: string): AppEntry | undefined {
  if (name === 'ideas') return { kind: EntryKind.IDEAS, payload: '' };
  if (name === 'capture-idea') return { kind: EntryKind.CAPTURE_IDEA, payload: '' };
  if (name === 'capture-log') return { kind: EntryKind.CAPTURE_LOG, payload: '' };
  if (name === 'today') return { kind: EntryKind.TODAY, payload: '' };
  return undefined;
}

/** 分享内容的读取上限：足以覆盖正文上限，超长由面板提示 */
const MAX_SHARED_CHARS = 200000;

export function sharedEntry(text: string): AppEntry | undefined {
  const trimmed = text.trim();
  if (trimmed === '') return undefined;
  return { kind: EntryKind.SHARED, payload: trimmed.slice(0, MAX_SHARED_CHARS) };
}

/** 判断这次输入是否「末尾单独键入回车」：是则提交；粘贴多行保留换行（口径同 iOS）。 */
export function isTypedTrailingReturn(previous: string, next: string): boolean {
  return next.length === previous.length + 1 && next.endsWith('\n') && next.startsWith(previous);
}

export function greetingText(hour: number): string {
  if (hour >= 5 && hour < 11) return tr('早上好 ☀️');
  if (hour >= 11 && hour < 18) return tr('下午好 🌤');
  return tr('晚上好 🌙');
}
