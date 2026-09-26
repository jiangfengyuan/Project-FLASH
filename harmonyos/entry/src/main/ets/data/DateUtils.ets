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

/** Strict calendar day; rejects Date rollover and supports years 0001–9999. */
export function isValidRecordDay(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parts = value.split('-').map((part: string) => Number(part));
  if (parts[0] < 1) return false;
  const day = new Date(0);
  day.setUTCFullYear(parts[0], parts[1] - 1, parts[2]);
  return day.getUTCFullYear() === parts[0] && day.getUTCMonth() === parts[1] - 1 &&
    day.getUTCDate() === parts[2];
}

/** Six Monday-first weeks, including adjacent-month days. Use local noon across DST. */
export function calendarWeeks(month: string): string[][] {
  const first = new Date(month.slice(0, 7) + '-01T12:00:00');
  const offset = (first.getDay() + 6) % 7;
  const weeks: string[][] = [];
  for (let week = 0; week < 6; week++) {
    const days: string[] = [];
    for (let index = 0; index < 7; index++) {
      const date = new Date(first.getTime());
      date.setDate(1 - offset + week * 7 + index);
      days.push(dayString(date));
    }
    weeks.push(days);
  }
  return weeks;
}

export function shiftCalendarMonth(month: string, delta: number): string {
  const date = new Date(month.slice(0, 7) + '-01T12:00:00');
  date.setMonth(date.getMonth() + delta);
  return dayString(date);
}
