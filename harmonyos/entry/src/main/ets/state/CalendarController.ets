import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { i18n } from '@kit.LocalizationKit';
import { dayString, shiftCalendarMonth, calendarWeeks } from '../data/DateUtils';
import { calendarDayMarkers, DayMarkers, EMPTY_DAY_MARKERS } from '../data/CalendarMarkers';
import { ColorTag, EmotionRecord, LogItem, TaskDueKind, TaskItem } from '../models/Models';
import { CalendarState } from '../state/FeatureStates';
import { FlashStore } from '../data/FlashStore';
import { TaskReminderScheduler } from '../data/TaskReminderScheduler';
import { ControllerRuntime } from './ControllerRuntime';

export class CalendarController {
  private state: CalendarState;
  private store: FlashStore;
  private runtime: ControllerRuntime;
  private weeksMonth: string = '';
  private weeksVersion: number = -1;
  private weeksCache: string[][] = [];
  private countsVersion: number = -1;
  private countsCache: Map<string, number> = new Map<string, number>();
  private markersVersion: number = -1;
  private markersCache: Map<string, DayMarkers> = new Map<string, DayMarkers>();
  constructor(state: CalendarState, runtime: ControllerRuntime, store: FlashStore = FlashStore.instance) {
    this.state = state;
    this.store = store;
    this.runtime = runtime;
  }

  /** Month grid memoized per (month, data version): 42 cells re-render on
   * every state touch, and the grid only changes with the data or the month. */
  monthWeeks(): string[][] {
    if (this.weeksMonth !== this.state.displayedMonth || this.weeksVersion !== this.state.dataVersion) {
      this.weeksCache = calendarWeeks(this.state.displayedMonth);
      this.weeksMonth = this.state.displayedMonth;
      this.weeksVersion = this.state.dataVersion;
    }
    return this.weeksCache;
  }

  /** Per-day record totals aggregated once per data version; each of the 42
   * day cells asks for its count several times per render. */
  dayCount(day: string): number {
    if (this.countsVersion !== this.state.dataVersion) {
      const counts = new Map<string, number>();
      this.state.logsByDay.forEach((items: LogItem[], key: string) => {
        counts.set(key, (counts.get(key) ?? 0) + items.length);
      });
      this.state.emotionsByDay.forEach((items: EmotionRecord[], key: string) => {
        counts.set(key, (counts.get(key) ?? 0) + items.length);
      });
      this.state.tasksByDay.forEach((items: TaskItem[], key: string) => {
        counts.set(key, (counts.get(key) ?? 0) + items.length);
      });
      this.countsCache = counts;
      this.countsVersion = this.state.dataVersion;
    }
    return this.countsCache.get(day) ?? 0;
  }

  /** 日期格视觉编码聚合（色点 + 主导情绪），与 dayCount 同一数据版本节奏。 */
  dayMarkers(day: string): DayMarkers {
    if (this.markersVersion !== this.state.dataVersion) {
      const markers = new Map<string, DayMarkers>();
      const days = new Set<string>();
      this.state.logsByDay.forEach((_, key: string) => { days.add(key); });
      this.state.emotionsByDay.forEach((_, key: string) => { days.add(key); });
      days.forEach((key: string) => {
        markers.set(key, calendarDayMarkers(
          this.state.logsByDay.get(key) ?? [], this.state.emotionsByDay.get(key) ?? []));
      });
      this.markersCache = markers;
      this.markersVersion = this.state.dataVersion;
    }
    return this.markersCache.get(day) ?? EMPTY_DAY_MARKERS;
  }

  selectCalendarDay(day: string): void {
    this.state.selectedDay = day;
    this.state.displayedMonth = day.slice(0, 7) + '-01';
  }

  shiftMonth(delta: number): void {
    this.state.displayedMonth = shiftCalendarMonth(this.state.displayedMonth, delta);
  }

  backToToday(): void { this.selectCalendarDay(dayString()); }

  taskCalendarDay(task: TaskItem): string {
    if (task.due.kind === TaskDueKind.ALL_DAY) return task.due.date ?? '';
    if (!task.due.at || !task.due.timeZone) return '';
    const instant = new Date(task.due.at).getTime();
    if (!Number.isFinite(instant)) return '';
    try {
      const offset = i18n.getTimeZone(task.due.timeZone).getOffset(instant);
      const local = new Date(instant + offset);
      return `${local.getUTCFullYear()}-${this.pad2(local.getUTCMonth() + 1)}-${this.pad2(local.getUTCDate())}`;
    } catch (_) {
      return '';
    }
  }

  openTaskEditor(task?: TaskItem, selectedDay?: string): void {
    this.state.editingTaskId = task?.id ?? 'new';
    this.state.taskTitle = task?.title ?? '';
    this.state.taskNotes = task?.notes ?? '';
    this.state.taskAllDay = task?.due.kind !== TaskDueKind.DATE_TIME;
    this.state.taskTimeZone = task?.due.timeZone ?? i18n.getTimeZone().getID();
    this.state.taskDate = task ? this.taskCalendarDay(task) : (selectedDay || dayString());
    this.state.taskTime = '09:00';
    if (task?.due.at) {
      try {
        const instant = new Date(task.due.at).getTime();
        const offset = i18n.getTimeZone(this.state.taskTimeZone).getOffset(instant);
        const local = new Date(instant + offset);
        this.state.taskTime = `${this.pad2(local.getUTCHours())}:${this.pad2(local.getUTCMinutes())}`;
      } catch (_) {}
    }
    this.state.taskReminderMinutes = this.reminderOffset(task);
  }

  closeTaskEditor(): void {
    this.state.editingTaskId = '';
    this.state.taskTitle = '';
    this.state.taskNotes = '';
    this.state.taskReminderMinutes = -1;
  }

  reminderOffset(task?: TaskItem): number {
    if (!task?.reminderAt) return -1;
    const anchor = this.taskAnchor(task);
    if (!anchor) return 0;
    const minutes = Math.round((anchor.getTime() - new Date(task.reminderAt).getTime()) / 60000);
    // Keep non-preset offsets (possibly set on another device) intact instead
    // of folding them into "at due time"; the editor echoes them verbatim and
    // saving without touching the reminder chips preserves the original value.
    return minutes >= 0 ? minutes : 0;
  }

  taskAnchor(task: TaskItem): Date | undefined {
    if (task.due.kind === TaskDueKind.DATE_TIME && task.due.at) return new Date(task.due.at);
    if (task.due.date) return this.localDateToInstant(task.due.date, '09:00', i18n.getTimeZone().getID());
    return undefined;
  }

  localDateToInstant(day: string, time: string, timeZone: string): Date | undefined {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || !/^\d{2}:\d{2}$/.test(time)) return undefined;
    const dateParts = day.split('-').map((value: string) => Number(value));
    const timeParts = time.split(':').map((value: string) => Number(value));
    // Date.UTC silently carries impossible days (2026-02-30 -> 2026-03-02) and maps
    // years 0000-0099 to 1900+. Round-trip check the wall clock instead, so a day
    // that BackupService.validDay would later reject can never be saved here.
    const wall = new Date(Date.UTC(dateParts[0], dateParts[1] - 1, dateParts[2], timeParts[0], timeParts[1], 0));
    wall.setUTCFullYear(dateParts[0]);
    if (dateParts[0] < 1 || !Number.isFinite(wall.getTime()) ||
        wall.getUTCFullYear() !== dateParts[0] || wall.getUTCMonth() !== dateParts[1] - 1 ||
        wall.getUTCDate() !== dateParts[2] || wall.getUTCHours() !== timeParts[0] ||
        wall.getUTCMinutes() !== timeParts[1]) return undefined;
    const localMillis = wall.getTime();
    try {
      const zone = i18n.getTimeZone(timeZone);
      let instant = localMillis - zone.getOffset(localMillis);
      instant = localMillis - zone.getOffset(instant);
      const result = new Date(instant);
      if (!Number.isFinite(result.getTime())) return undefined;
      // Round-trip the probed instant: across a DST gap the two-pass offset
      // probe can land on an instant whose local wall clock differs from the
      // requested day/time (e.g. a nonexistent 02:30 on spring-forward). Hold
      // the result to the same strict standard as the wall check above.
      const back = new Date(instant + zone.getOffset(instant));
      if (back.getUTCFullYear() !== dateParts[0] || back.getUTCMonth() !== dateParts[1] - 1 ||
          back.getUTCDate() !== dateParts[2] || back.getUTCHours() !== timeParts[0] ||
          back.getUTCMinutes() !== timeParts[1]) return undefined;
      return result;
    } catch (_) {
      return undefined;
    }
  }

  async saveTaskEditor(): Promise<void> {
    if (this.state.busy) return;
    const title = this.state.taskTitle.trim().slice(0, 200);
    const anchor = this.localDateToInstant(this.state.taskDate, this.state.taskAllDay ? '09:00' : this.state.taskTime,
      this.state.taskTimeZone || i18n.getTimeZone().getID());
    if (!title) { this.runtime.notify('请输入任务标题', 'error'); return; }
    if (!anchor) { this.runtime.notify('请输入有效的日期和时间', 'error'); return; }
    const existing = this.state.tasks.find((item: TaskItem) => item.id === this.state.editingTaskId);
    const now = new Date().toISOString();
    const reminderAt = this.state.taskReminderMinutes < 0 ? undefined :
      new Date(anchor.getTime() - this.state.taskReminderMinutes * 60000).toISOString();
    const task: TaskItem = {
      id: existing?.id ?? util.generateRandomUUID(true), title: title,
      notes: this.state.taskNotes.trim().slice(0, 100000) || undefined,
      colorTag: existing?.colorTag ?? ColorTag.MEMO, importance: existing?.importance ?? 0,
      due: this.state.taskAllDay ? { kind: TaskDueKind.ALL_DAY, date: this.state.taskDate } : {
        kind: TaskDueKind.DATE_TIME, at: anchor.toISOString(),
        timeZone: this.state.taskTimeZone || i18n.getTimeZone().getID()
      },
      reminderAt: reminderAt, completedAt: existing?.completedAt,
      createdAt: existing?.createdAt ?? now, updatedAt: now
    };
    this.state.busy = true;
    try {
      await this.store.saveTask(task);
      this.closeTaskEditor();
      const context = this.runtime.context() as common.UIAbilityContext;
      try {
        await TaskReminderScheduler.rebuild(context, this.store.tasks.slice(), reminderAt !== undefined);
        this.runtime.notify('任务已保存', 'success');
      } catch (_) {
        this.runtime.notify('任务已保存，但系统提醒未启用');
      }
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error), 'error');
    } finally {
      this.state.busy = false;
    }
  }

  async toggleTask(task: TaskItem): Promise<void> {
    if (this.state.busy) return;
    const updated: TaskItem = {
      id: task.id, title: task.title, notes: task.notes, colorTag: task.colorTag, importance: task.importance,
      due: task.due, reminderAt: task.reminderAt,
      completedAt: task.completedAt ? undefined : new Date().toISOString(),
      createdAt: task.createdAt, updatedAt: new Date().toISOString()
    };
    this.state.busy = true;
    try {
      await this.store.saveTask(updated);
      try {
        const context = this.runtime.context();
        await TaskReminderScheduler.rebuild(context, this.store.tasks.slice(), false);
      } catch (_) {
        this.runtime.notify('任务状态已更新，但系统提醒同步失败', 'error');
      }
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error), 'error');
    } finally {
      this.state.busy = false;
    }
  }

  async removeTask(id: string): Promise<boolean> {
    await this.store.deleteTask(id);
    const context = this.runtime.context() as common.UIAbilityContext;
    try {
      await TaskReminderScheduler.rebuild(context, this.store.tasks.slice(), false);
      return true;
    } catch (_) {
      this.runtime.notify('任务已删除，但系统提醒同步失败', 'error');
      return false;
    }
  }

  pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  displayedActivityDays(): string[] {
    return this.state.activityDays.slice(0, this.state.calendarDayLimit);
  }

}
