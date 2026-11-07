// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

/**
 * 界面文案入口（键即简体中文原文，占位符写成 {0}、{1}）。
 *
 * 与 iOS / Android 共用 docs/i18n/translations.json：tools/i18n/generate.py 生成
 * resources 下各语言的 string.json，资源名由原文的 FNV-1a 散列决定（i18nKey）。
 * 未安装资源管理器时（主机测试）直接返回中文原文。存储值（日期、ID、备份字段）不得走这里。
 */
export interface StringSource {
  getStringByNameSync(name: string): string;
  getPluralStringByNameSync?(name: string, count: number): string;
}

let source: StringSource | undefined = undefined;
let language: string = 'zh';
const cache: Map<string, string> = new Map<string, string>();

export function installI18n(manager: StringSource, systemLanguage: string): void {
  source = manager;
  language = systemLanguage;
  cache.clear();
}

/** 只有中文界面使用随包的霞鹜文楷；其他语言该子集覆盖不足，用系统字体 */
export function usesBundledDisplayFont(): boolean {
  return language.startsWith('zh');
}

/** FNV-1a（32 位，按 UTF-16 码元），与 tools/i18n/generate.py 一致 */
export function i18nKey(text: string): string {
  let hash = 0x811c9dc5;
  for (let index = 0; index < text.length; index++) {
    hash ^= text.charCodeAt(index);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return 's_' + (hash >>> 0).toString(16).padStart(8, '0');
}

function lookup(text: string, count: number | undefined): string {
  if (source === undefined) return text;
  const cacheKey = count === undefined ? text : `${text}#${count}`;
  const cached = cache.get(cacheKey);
  if (cached !== undefined) return cached;
  const name = i18nKey(text);
  let value = text;
  try {
    if (count !== undefined && source.getPluralStringByNameSync !== undefined) {
      value = source.getPluralStringByNameSync(name, count);
    } else {
      value = source.getStringByNameSync(name);
    }
  } catch (_) {
    try {
      value = source.getStringByNameSync(name);
    } catch (__) {
      value = text;
    }
  }
  cache.set(cacheKey, value);
  return value;
}

/** tr('共 {0} 条', 3)。占位符直接替换，不经语言格式化，数字保持 ASCII。 */
export function tr(text: string, ...args: (string | number)[]): string {
  const firstCount = args.find((item: string | number) => typeof item === 'number');
  let out = lookup(text, typeof firstCount === 'number' ? firstCount : undefined);
  args.forEach((value: string | number, index: number) => {
    out = out.split(`{${index}}`).join(`${value}`);
  });
  return out;
}
