// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { EmotionRecord, LogItem } from '../models/Models';

/** 日历日期格的视觉编码数据（PRD 7.1：Tag 色点 + 心情色条）。 */
export interface DayMarkers {
  /** 当日记录的标签色（store 顺序即最新优先），最多 3 个。 */
  tagDots: string[];
  /** 超出 3 个色点的记录条数（界面显示 +N）。 */
  extraLogs: number;
  /** 当日主导情绪等级：出现次数最多；并列时取最新一条。无情绪记录时为 undefined。 */
  emotionLevel?: number;
}

export const EMPTY_DAY_MARKERS: DayMarkers = { tagDots: [], extraLogs: 0 };

export function calendarDayMarkers(logs: LogItem[], emotions: EmotionRecord[]): DayMarkers {
  const tagDots = logs.slice(0, 3).map((item: LogItem) => item.colorTag);
  let emotionLevel: number | undefined;
  if (emotions.length > 0) {
    // emotions 为最新优先；严格大于才易主，次数并列时最新一条胜出，结果确定。
    const counts = new Map<number, number>();
    let best = emotions[0].level;
    let bestCount = 0;
    for (const item of emotions) {
      const count = (counts.get(item.level) ?? 0) + 1;
      counts.set(item.level, count);
      if (count > bestCount) {
        best = item.level;
        bestCount = count;
      }
    }
    emotionLevel = best;
  }
  return {
    tagDots: tagDots,
    extraLogs: Math.max(0, logs.length - 3),
    emotionLevel: emotionLevel
  };
}
