import { StorePartition } from '../data/StoreChanges';
import { BackupData, Category, EmotionRecord, emotionEmoji, LogItem, TaskItem } from '../models/Models';
import { dayString } from '../data/DateUtils';
import { AppSession } from './FeatureStates';

/** Rebuild only changed partitions. Drafts and pagination survive publication. */
export class FeatureProjection {
  private session: AppSession;
  private taskDay: (task: TaskItem) => string;
  private searchChanged: () => void;
  constructor(session: AppSession, taskDay: (task: TaskItem) => string, searchChanged: () => void) {
    this.session = session;
    this.taskDay = taskDay;
    this.searchChanged = searchChanged;
  }

  update(partition: StorePartition, data: BackupData): void {
    const calendar = this.session.calendar;
    if (partition === StorePartition.ALL || partition === StorePartition.LOGS) {
      this.session.logs.logs = data.logs.slice();
      this.session.home.recentLogs = data.logs.slice(0, 5);
      const groups = new Map<string, LogItem[]>();
      data.logs.forEach((item: LogItem) => {
        const entries = groups.get(item.recordDate) ?? [];
        entries.push(item);
        groups.set(item.recordDate, entries);
      });
      calendar.logsByDay = groups;
      this.searchChanged();
      this.updateLogCounts();
    }
    if (partition === StorePartition.ALL || partition === StorePartition.EMOTIONS) {
      this.session.emotion.emotions = data.emotions.slice();
      this.session.home.latestEmoji = data.emotions.length > 0 ? emotionEmoji(data.emotions[0].level) : '—';
      const groups = new Map<string, EmotionRecord[]>();
      data.emotions.forEach((item: EmotionRecord) => {
        const entries = groups.get(item.recordDate) ?? [];
        entries.push(item);
        groups.set(item.recordDate, entries);
      });
      calendar.emotionsByDay = groups;
      this.updateEmotionCount();
    }
    if (partition === StorePartition.ALL || partition === StorePartition.TASKS) {
      calendar.tasks = data.tasks.slice();
      const groups = new Map<string, TaskItem[]>();
      data.tasks.forEach((item: TaskItem) => {
        const day = this.taskDay(item);
        if (!day) return;
        const entries = groups.get(day) ?? [];
        entries.push(item);
        groups.set(day, entries);
      });
      calendar.tasksByDay = groups;
      this.updateTaskCounts();
    }
    const days = new Set<string>();
    calendar.logsByDay.forEach((_, key: string) => { days.add(key); });
    calendar.emotionsByDay.forEach((_, key: string) => { days.add(key); });
    calendar.tasksByDay.forEach((_, key: string) => { days.add(key); });
    calendar.activityDays = Array.from(days).sort().reverse();
  }

  updateDay(): void {
    this.updateLogCounts();
    this.updateEmotionCount();
    this.updateTaskCounts();
  }

  private updateLogCounts(): void {
    const today = dayString();
    this.session.home.todayLogCount = this.session.logs.logs.filter((item: LogItem) =>
      item.recordDate === today && item.category === Category.LOG).length;
    this.session.home.todayIdeaCount = this.session.logs.logs.filter((item: LogItem) =>
      item.recordDate === today && item.category === Category.IDEA).length;
  }

  private updateEmotionCount(): void {
    const today = dayString();
    this.session.home.todayEmotionCount = this.session.emotion.emotions.filter((item: EmotionRecord) =>
      item.recordDate === today).length;
  }

  private updateTaskCounts(): void {
    const today = dayString();
    const todays = this.session.calendar.tasks.filter((item: TaskItem) => this.taskDay(item) === today);
    this.session.home.todayTaskCount = todays.length;
    this.session.home.todayTaskDoneCount = todays.filter((item: TaskItem) =>
      item.completedAt !== undefined && item.completedAt !== null).length;
  }
}
