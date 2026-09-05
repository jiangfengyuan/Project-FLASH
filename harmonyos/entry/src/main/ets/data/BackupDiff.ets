import { BackupData, EmotionRecord, LogItem, TaskItem } from '../models/Models';

export class DifferenceSummary {
  added: number = 0;
  changed: number = 0;
  unchanged: number = 0;
  localOnly: number = 0;
}

export class BackupDifference {
  logs: DifferenceSummary = new DifferenceSummary();
  emotions: DifferenceSummary = new DifferenceSummary();
  tasks: DifferenceSummary = new DifferenceSummary();
}

export class BackupDiff {
  static analyze(localLogs: LogItem[], localEmotions: EmotionRecord[], incomingLogs: LogItem[],
    incomingEmotions: EmotionRecord[], localTasks: TaskItem[] = [],
    incomingTasks: TaskItem[] = []): BackupDifference {
    const result = new BackupDifference();
    result.logs = BackupDiff.logSummary(localLogs, incomingLogs);
    result.emotions = BackupDiff.emotionSummary(localEmotions, incomingEmotions);
    result.tasks = BackupDiff.taskSummary(localTasks, incomingTasks);
    return result;
  }

  /** Staleness check for the destructive overwrite preview. Snapshots are
   * shallow array copies and every store mutation replaces the affected item
   * objects, so identity order comparison catches any local change. */
  static sameData(left: BackupData, right: BackupData): boolean {
    return BackupDiff.sameItems(left.logs, right.logs) &&
      BackupDiff.sameItems(left.emotions, right.emotions) &&
      BackupDiff.sameItems(left.tasks, right.tasks);
  }

  private static sameItems<T>(left: T[], right: T[]): boolean {
    if (left.length !== right.length) return false;
    for (let index = 0; index < left.length; index++) {
      if (left[index] !== right[index]) return false;
    }
    return true;
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

  private static taskSummary(local: TaskItem[], incoming: TaskItem[]): DifferenceSummary {
    const summary = new DifferenceSummary();
    const localMap = new Map<string, string>();
    local.forEach((item: TaskItem) => localMap.set(item.id, JSON.stringify(item)));
    incoming.forEach((item: TaskItem) => {
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
