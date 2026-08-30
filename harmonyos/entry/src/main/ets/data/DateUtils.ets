function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

export function dayString(date: Date = new Date()): string {
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

export function isoNow(): string {
  return new Date().toISOString();
}

export function dayOffset(offset: number): string {
  const date = new Date();
  date.setDate(date.getDate() + offset);
  return dayString(date);
}

export function monthTitle(day: string): string {
  const parts = day.split('-');
  if (parts.length < 2) return day;
  return `${parts[0]} 年 ${Number(parts[1])} 月`;
}

export function shortDay(day: string): string {
  const parts = day.split('-');
  if (parts.length < 3) return day;
  return `${Number(parts[1])}月${Number(parts[2])}日`;
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
