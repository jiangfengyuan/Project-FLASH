import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { i18n } from '@kit.LocalizationKit';
import { dayString, shiftCalendarMonth } from '../data/DateUtils';
import { ColorTag, TaskDueKind, TaskItem } from '../models/Models';
import { CalendarState } from '../state/FeatureStates';
import { FlashStore } from '../data/FlashStore';
import { TaskReminderScheduler } from '../data/TaskReminderScheduler';
import { ControllerRuntime } from './ControllerRuntime';

export class CalendarController {
  private state: CalendarState;
  private store: FlashStore;
  private runtime: ControllerRuntime;
  constructor(state: CalendarState, runtime: ControllerRuntime, store: FlashStore = FlashStore.instance) {
    this.state = state;
    this.store = store;
    this.runtime = runtime;
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
      return Number.isFinite(result.getTime()) ? result : undefined;
    } catch (_) {
      return undefined;
    }
  }

  async saveTaskEditor(): Promise<void> {
    if (this.state.busy) return;
    const title = this.state.taskTitle.trim().slice(0, 200);
    const anchor = this.localDateToInstant(this.state.taskDate, this.state.taskAllDay ? '09:00' : this.state.taskTime,
      this.state.taskTimeZone || i18n.getTimeZone().getID());
    if (!title) { this.runtime.notify('请输入任务标题'); return; }
    if (!anchor) { this.runtime.notify('请输入有效的日期和时间'); return; }
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
        this.runtime.notify('任务已保存');
      } catch (_) {
        this.runtime.notify('任务已保存，但系统提醒未启用');
      }
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error));
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
        this.runtime.notify('任务状态已更新，但系统提醒同步失败');
      }
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error));
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
      this.runtime.notify('任务已删除，但系统提醒同步失败');
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
