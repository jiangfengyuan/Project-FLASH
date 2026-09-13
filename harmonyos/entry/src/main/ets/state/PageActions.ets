import { AppController } from './AppController';
import { LogsController } from './LogsController';
import { EmotionController } from './EmotionController';
import { CalendarController } from './CalendarController';
import { BackupController } from './BackupController';

/** Explicit event dependencies, separate from observable feature data. */
export class PageActions {
  readonly logsController: LogsController;
  readonly emotionController: EmotionController;
  readonly calendarController: CalendarController;
  readonly backupController: BackupController;
  readonly controller: AppController;
  readonly switchTab: (index: number) => void;
  readonly openDetail: (destination: string) => void;
  readonly setThemeMode: (mode: string) => void;
  constructor(controller: AppController,
    switchTab: (index: number) => void,
    openDetail: (destination: string) => void,
    setThemeMode: (mode: string) => void) {
    this.controller = controller;
    this.switchTab = switchTab;
    this.openDetail = openDetail;
    this.setThemeMode = setThemeMode;
    this.logsController = controller.logsController;
    this.emotionController = controller.emotionController;
    this.calendarController = controller.calendarController;
    this.backupController = controller.backupController;
  }
}

export function requireActions(actions: PageActions | undefined): PageActions {
  if (!actions) throw new Error('页面操作依赖未装配');
  return actions;
}
