import { bundleManager, common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { dayString } from '../data/DateUtils';
import { TaskItem } from '../models/Models';
import { AppSession, DeleteKind, normalizeThemeMode } from '../state/FeatureStates';
import { BackupService } from '../data/BackupService';
import { FlashStore } from '../data/FlashStore';
import { TaskReminderScheduler } from '../data/TaskReminderScheduler';
import { HarmonyCapabilities } from '../data/HarmonyCapabilities';
import { NotificationChannels } from '../data/NotificationChannels';
import { FormUpdateHelper } from '../data/FormUpdateHelper';
import { LogsController } from './LogsController';
import { EmotionController } from './EmotionController';
import { CalendarController } from './CalendarController';
import { BackupController } from './BackupController';
import { ControllerRuntime } from './ControllerRuntime';
import { FeatureProjection } from './FeatureProjection';
import { StorePartition } from '../data/StoreChanges';

// 与 FlashStore 的偏好存储同名同键：FlashStore 只识别 light/dark，
// 这里直接读写原始值以保留 system 三态。
const THEME_PREFERENCES_STORE = 'flash-aero-data';
const THEME_MODE_KEY = 'theme-mode';

export class AppController {
  readonly session: AppSession = new AppSession();
  readonly runtime: ControllerRuntime = new ControllerRuntime(this.session.feedback);
  readonly logsController: LogsController = new LogsController(this.session.logs, this.runtime);
  readonly emotionController: EmotionController = new EmotionController(this.session.emotion, this.runtime);
  readonly calendarController: CalendarController = new CalendarController(this.session.calendar, this.runtime);
  readonly backupController: BackupController = new BackupController(this.session.backup, this.runtime);
  private projection: FeatureProjection = new FeatureProjection(this.session,
    (task: TaskItem) => this.calendarController.taskCalendarDay(task),
    () => this.logsController.updateSearchResults());
  private unsubscribe?: () => void;
  private dateTimer: number = 0;
  private generation: number = 0;

  async prepare(context: common.UIAbilityContext, themeLoaded: (mode: string) => void = () => {}): Promise<void> {
    this.dispose();
    const generation = ++this.generation;
    this.runtime.bind(context);
    try {
      const bundle = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      if (bundle.versionName) BackupService.appVersion = bundle.versionName;
    } catch (_) {
      // Keep the built-in fallback; exporting must never fail over a version lookup.
    }
    try {
      const store = FlashStore.instance;
      await store.initialize(context);
      if (generation !== this.generation) return;
      const themeMode = await this.loadThemeMode(context, store.themeMode);
      this.session.theme.themeMode = themeMode;
      themeLoaded(themeMode);
      this.session.settings.showWelcome = !store.welcomed;
      this.session.backup.recoveryAvailable = store.hasRecoveryData;
      this.unsubscribe = store.changes.subscribe((partition: StorePartition) => {
        this.projection.update(partition, { logs: store.logs, emotions: store.emotions, tasks: store.tasks });
        FormUpdateHelper.updateForms(context).catch(() => {});
      });
      this.projection.update(StorePartition.ALL, { logs: store.logs, emotions: store.emotions, tasks: store.tasks });
      let observedDay = dayString();
      this.dateTimer = setInterval(() => {
        const current = dayString();
        if (current !== observedDay) {
          observedDay = current;
          this.projection.updateDay();
          FormUpdateHelper.updateForms(context).catch(() => {});
        }
      }, 60000);
      try {
        await TaskReminderScheduler.rebuild(context, store.tasks.slice(), false);
      } catch (_) {
        if (generation === this.generation) this.runtime.notify('任务提醒恢复失败；任务数据仍然安全，请稍后重启应用重试');
      }
      if (generation !== this.generation) return;
      if (store.recoveryWarning) this.runtime.notify(store.recoveryWarning);
      const capability = await HarmonyCapabilities.inspect();
      if (generation !== this.generation) return;
      this.session.settings.nearLinkSupported = capability.nearLinkSupported;
      this.session.settings.floatingBallSupported = capability.floatingBallSupported;
      this.session.settings.liveViewEnabled = capability.liveViewEnabled;
      this.session.settings.agentFrameworkSupported = capability.agentFrameworkSupported;
      this.session.settings.agentRuntimeSupported = capability.agentRuntimeSupported;
      this.session.settings.fileSandboxShareSupported = capability.fileSandboxShareSupported;
      this.session.settings.notificationSettingsSupported = capability.notificationSettingsSupported;
    } catch (error) {
      if (generation === this.generation) this.runtime.notify(`本地数据加载失败：${this.runtime.errorMessage(error as Error)}`);
    }
  }

  saveTheme(mode: string): Promise<void> { return FlashStore.instance.setThemeMode(mode); }

  async openNotificationSettings(): Promise<void> {
    try {
      const opened = await NotificationChannels.openAppNotificationSettings(this.runtime.context());
      if (!opened) this.runtime.notify('当前设备不支持应用内通知设置');
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error));
    }
  }

  async setThemeMode(mode: string): Promise<void> {
    const normalized = normalizeThemeMode(mode);
    this.session.theme.themeMode = normalized;
    if (normalized === 'system') {
      const settings = await preferences.getPreferences(this.runtime.context(), THEME_PREFERENCES_STORE);
      await settings.put(THEME_MODE_KEY, normalized);
      await settings.flush();
    } else {
      await FlashStore.instance.setThemeMode(normalized);
    }
  }

  private async loadThemeMode(context: common.UIAbilityContext, fallback: string): Promise<string> {
    try {
      const settings = await preferences.getPreferences(context, THEME_PREFERENCES_STORE);
      const stored = await settings.get(THEME_MODE_KEY, fallback);
      return normalizeThemeMode(typeof stored === 'string' ? stored : fallback);
    } catch (_) {
      return normalizeThemeMode(fallback);
    }
  }

  dispose(): void {
    this.generation++;
    this.unsubscribe?.();
    this.unsubscribe = undefined;
    clearInterval(this.dateTimer);
    this.logsController.dispose();
    this.backupController.dispose();
    this.runtime.dispose();
  }
  async confirmDestructiveAction(): Promise<void> {
    const request = this.session.feedback.destructive;
    if (!request) return;
    this.session.feedback.destructive = undefined;
    try {
      if (request.kind === DeleteKind.LOG) {
        await this.logsController.removeLog(request.id);
        this.runtime.notify('记录已删除');
      } else if (request.kind === DeleteKind.EMOTION) {
        await this.emotionController.removeEmotion(request.id);
        this.runtime.notify('情绪记录已删除');
      } else if (request.kind === DeleteKind.TASK) {
        if (await this.calendarController.removeTask(request.id)) this.runtime.notify('任务已删除');
      } else if (request.kind === DeleteKind.ALL) {
        await FlashStore.instance.clearAll();
        const context = this.runtime.context() as common.UIAbilityContext;
        try {
          await TaskReminderScheduler.rebuild(context, [], false);
          this.runtime.notify('本地数据已清空');
        } catch (_) {
          this.runtime.notify('本地数据已清空，但系统提醒清理失败，请重启应用后重试');
        }
      }
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error));
    }
  }

  async finishWelcome(): Promise<void> {
    try {
      await FlashStore.instance.setWelcomed();
      this.session.settings.showWelcome = false;
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error));
    }
  }

  cancelDestructiveAction(): void {
    this.session.feedback.destructive = undefined;
  }

  destructiveTitle(): string {
    const kind = this.session.feedback.destructive?.kind;
    if (kind === DeleteKind.LOG) return '删除这条记录？';
    if (kind === DeleteKind.EMOTION) return '删除这条情绪记录？';
    if (kind === DeleteKind.TASK) return '删除这个任务？';
    return '清空全部本地数据？';
  }

  destructiveMessage(): string {
    return this.session.feedback.destructive?.kind === DeleteKind.ALL ? '日志、灵感、情绪和任务将全部删除。此操作无法撤销，建议先导出备份。' :
      '删除后无法撤销。';
  }
}
