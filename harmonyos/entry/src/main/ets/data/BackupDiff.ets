import { EmotionRecord, LogItem } from '../models/Models';

export class DifferenceSummary {
  added: number = 0;
  changed: number = 0;
  unchanged: number = 0;
  localOnly: number = 0;
}

export class BackupDifference {
  logs: DifferenceSummary = new DifferenceSummary();
  emotions: DifferenceSummary = new DifferenceSummary();
}

export class BackupDiff {
  static analyze(localLogs: LogItem[], localEmotions: EmotionRecord[], incomingLogs: LogItem[],
    incomingEmotions: EmotionRecord[]): BackupDifference {
    const result = new BackupDifference();
    result.logs = BackupDiff.logSummary(localLogs, incomingLogs);
    result.emotions = BackupDiff.emotionSummary(localEmotions, incomingEmotions);
    return result;
  }

  private static logSummary(local: LogItem[], incoming: LogItem[]): DifferenceSummary {
    const summary = new DifferenceSummary();
    const localMap = new Map<string, string>();
    local.forEach((item: LogItem) => localMap.set(item.id, JSON.stringify(item)));
    incoming.forEach((item: LogItem) => {
      const existing = localMap.get(item.id);
      if (existing === undefined) summary.added++;
      else if (existing === JSON.stringify(item)) summary.unchanged++;
      else summary.changed++;
      localMap.delete(item.id);
    });
    summary.localOnly = localMap.size;
    return summary;
  }

  private static emotionSummary(local: EmotionRecord[], incoming: EmotionRecord[]): DifferenceSummary {
    const summary = new DifferenceSummary();
    const localMap = new Map<string, string>();
    local.forEach((item: EmotionRecord) => localMap.set(item.id, JSON.stringify(item)));
    incoming.forEach((item: EmotionRecord) => {
      const existing = localMap.get(item.id);
      if (existing === undefined) summary.added++;
      else if (existing === JSON.stringify(item)) summary.unchanged++;
      else summary.changed++;
      localMap.delete(item.id);
    });
    summary.localOnly = localMap.size;
    return summary;
  }
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
