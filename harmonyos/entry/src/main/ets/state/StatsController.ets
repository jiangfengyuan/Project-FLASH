import {
  DailyActivity, dailyActivity, EmotionDistribution, emotionDistribution, ReviewComparison, reviewComparison,
  reviewDays
} from '../data/ReviewWindow';
import { dayString } from '../data/DateUtils';
import { EmotionRecord, LogItem } from '../models/Models';
import { EmotionState, LogsState } from './FeatureStates';

/** Stats-page derivations memoized per (window, data version, day). The
 * @Builder body re-reads these on every re-render, so the filters and
 * aggregations must not re-run unless the inputs actually changed. */
export class StatsController {
  private logs: LogsState;
  private emotion: EmotionState;
  private memoKey: string = '';
  private memoDays: string[] = [];
  private memoPeriodLogs: LogItem[] = [];
  private memoPeriodEmotions: EmotionRecord[] = [];
  private memoComparison?: ReviewComparison;
  private memoDistribution?: EmotionDistribution;
  private memoActivity: DailyActivity[] = [];

  constructor(logs: LogsState, emotion: EmotionState) {
    this.logs = logs;
    this.emotion = emotion;
  }

  private refresh(window: string): void {
    const key = `${window}|${this.logs.logsVersion}|${this.emotion.emotionsVersion}|${dayString()}`;
    if (key === this.memoKey) return;
    this.memoKey = key;
    this.memoDays = reviewDays(window);
    const daySet = new Set<string>(this.memoDays);
    this.memoPeriodLogs = this.logs.logs.filter((item: LogItem) => daySet.has(item.recordDate));
    this.memoPeriodEmotions = this.emotion.emotions.filter((item: EmotionRecord) => daySet.has(item.recordDate));
    this.memoComparison = reviewComparison(this.logs.logs, this.emotion.emotions, window);
    this.memoDistribution = emotionDistribution(this.emotion.emotions, this.memoDays);
    this.memoActivity = dailyActivity(this.logs.logs, this.emotion.emotions, this.memoDays);
  }

  days(window: string): string[] {
    this.refresh(window);
    return this.memoDays;
  }

  periodLogs(window: string): LogItem[] {
    this.refresh(window);
    return this.memoPeriodLogs;
  }

  periodEmotions(window: string): EmotionRecord[] {
    this.refresh(window);
    return this.memoPeriodEmotions;
  }

  comparison(window: string): ReviewComparison {
    this.refresh(window);
    return this.memoComparison as ReviewComparison;
  }

  distribution(window: string): EmotionDistribution {
    this.refresh(window);
    return this.memoDistribution as EmotionDistribution;
  }

  activity(window: string): DailyActivity[] {
    this.refresh(window);
    return this.memoActivity;
  }

  activeDays(window: string): number {
    this.refresh(window);
    const days = this.memoPeriodLogs.map((item: LogItem) => item.recordDate)
      .concat(this.memoPeriodEmotions.map((item: EmotionRecord) => item.recordDate));
    return new Set<string>(days).size;
  }

  periodAverage(window: string): string {
    this.refresh(window);
    const items = this.memoPeriodEmotions;
    return items.length === 0 ? '—' :
      (items.reduce((sum: number, item: EmotionRecord) => sum + item.level, 0) / items.length).toFixed(1);
  }
}
