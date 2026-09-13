import { common } from '@kit.AbilityKit';
import { BackupState, TransferPhase, ImportPhase } from '../state/FeatureStates';
import { BackupData } from '../models/Models';
import { FlashStore } from '../data/FlashStore';
import { TaskReminderScheduler } from '../data/TaskReminderScheduler';
import { ControllerRuntime } from './ControllerRuntime';
import { BackupDiff } from '../data/BackupDiff';
import { BackupFiles } from '../data/BackupFiles';
import { BackupImport, BackupService } from '../data/BackupService';
import { LanDevice, LocalBackupDiscovery, LocalBackupReceiver, LocalBackupSender } from '../data/LocalBackupTransfer';

export class BackupController {
  private state: BackupState;
  private store: FlashStore;
  private runtime: ControllerRuntime;
  constructor(state: BackupState, runtime: ControllerRuntime, store: FlashStore = FlashStore.instance) {
    this.state = state;
    this.store = store;
    this.runtime = runtime;
  }
  private pendingImport?: BackupImport;
  /** Local snapshot the pending preview was computed from. Overwrite must
   * re-verify this before replacing the database, or records created between
   * preview and confirmation would be deleted without being counted. */
  private pendingSnapshot?: BackupData;
  private generation: number = 0;
  private lanGeneration: number = 0;
  private lanSender?: LocalBackupSender;
  private lanDiscovery?: LocalBackupDiscovery;
  private lanReceiver?: LocalBackupReceiver;
  cancelImport(): void {
    if (this.state.busy) return;
    this.pendingImport = undefined;
    this.pendingSnapshot = undefined;
    this.state.importSummary = '';
    this.state.importPhase = ImportPhase.IDLE;
  }

  dispose(): void {
    this.generation++;
    this.state.fileBusy = false;
    this.stopLan();
    this.cancelImport();
  }

  async exportBackup(): Promise<void> {
    if (this.state.fileBusy) return;
    if (!this.store.ready) {
      this.runtime.notify('本地数据尚未加载完成，无法导出备份');
      return;
    }
    const generation = this.generation;
    this.state.fileBusy = true;
    try {
      const context = this.runtime.context() as common.UIAbilityContext;
      const snapshot = this.store.snapshot();
      const json = BackupService.exportJSON(snapshot.logs, snapshot.emotions, snapshot.tasks);
      await BackupFiles.exportJSON(context, json);
      if (generation === this.generation) this.runtime.notify('备份已导出');
    } catch (error) {
      if (generation === this.generation) this.runtime.notify(this.runtime.errorMessage(error as Error));
    } finally {
      if (generation === this.generation) this.state.fileBusy = false;
    }
  }

  async exportRecoveryData(): Promise<void> {
    if (this.state.fileBusy) return;
    const generation = this.generation;
    this.state.fileBusy = true;
    try {
      const archive = await this.store.recoveryArchive();
      if (generation !== this.generation) return;
      if (!archive) {
        this.state.recoveryAvailable = false;
        this.runtime.notify('没有可导出的恢复数据');
        return;
      }
      const context = this.runtime.context() as common.UIAbilityContext;
      await BackupFiles.exportJSON(context, archive, 'flash-aero-recovery');
      if (generation === this.generation) this.runtime.notify('恢复原始数据已导出，请妥善保管并联系支持人员处理');
    } catch (error) {
      if (generation === this.generation) this.runtime.notify(this.runtime.errorMessage(error as Error));
    } finally {
      if (generation === this.generation) this.state.fileBusy = false;
    }
  }

  async chooseBackup(recovery: boolean = false): Promise<void> {
    if (this.state.fileBusy || this.state.busy) return;
    const generation = this.generation;
    this.state.fileBusy = true;
    try {
      const context = this.runtime.context() as common.UIAbilityContext;
      const json = await BackupFiles.importJSON(context);
      const incoming = recovery ? BackupService.parseRecovery(json) : BackupService.parseStrict(json);
      if (generation !== this.generation) return;
      this.stageImport(incoming);
      this.state.importSummary = (recovery ? "部分恢复（跳过非法、重复和超限记录；原文件不变）" : "标准导入") + "\n" + this.state.importSummary;
    } catch (error) {
      if (generation === this.generation) {
        this.cancelImport();
        this.runtime.notify(this.runtime.errorMessage(error as Error));
      }
    } finally {
      if (generation === this.generation) this.state.fileBusy = false;
    }
  }

  stageImport(incoming: BackupImport): void {
    if (this.state.busy) return;
    const snapshot = this.store.snapshot();
    this.pendingSnapshot = snapshot;
    this.pendingImport = incoming;
    this.state.importPhase = ImportPhase.PREVIEW;
    this.state.importSummary = this.describeImport(incoming, snapshot);
  }

  private describeImport(incoming: BackupImport, snapshot: BackupData): string {
    const difference = BackupDiff.analyze(
      snapshot.logs, snapshot.emotions, incoming.logs, incoming.emotions,
      snapshot.tasks, incoming.tasks);
    return `日志：新增 ${difference.logs.added}、变更 ${difference.logs.changed}、本机独有 ${difference.logs.localOnly}\n` +
      `情绪：新增 ${difference.emotions.added}、变更 ${difference.emotions.changed}、本机独有 ${difference.emotions.localOnly}\n` +
      `任务：新增 ${difference.tasks.added}、变更 ${difference.tasks.changed}、本机独有 ${difference.tasks.localOnly}\n` +
      `无效项目：${incoming.skippedLogs + incoming.skippedEmotions + incoming.skippedTasks}`;
  }

  async startLanSend(): Promise<void> {
    if (!this.store.ready) {
      this.runtime.notify('本地数据尚未加载完成，无法发送备份');
      return;
    }
    this.stopLan();
    const generation = this.lanGeneration;
    try {
      const context = this.runtime.context() as common.UIAbilityContext;
      const snapshot = this.store.snapshot();
      const json = BackupService.exportJSON(snapshot.logs, snapshot.emotions, snapshot.tasks);
      const sender = new LocalBackupSender(context, json, (success: boolean) => {
        // An older session may finish while a new one is starting; never clear the new session's state.
        if (this.lanSender !== sender) return;
        this.state.lanMode = TransferPhase.IDLE;
        this.state.lanPin = '';
        this.lanSender = undefined;
        this.runtime.notify(success ? '备份已发送' : '配对已结束');
      });
      this.lanSender = sender;
      this.state.lanMode = TransferPhase.SENDING;
      this.state.lanPin = sender.pin;
      await sender.start();
    } catch (error) {
      if (generation !== this.lanGeneration) return;
      this.stopLan();
      this.runtime.notify(this.runtime.errorMessage(error as Error));
    }
  }

  startLanReceive(): void {
    this.stopLan();
    try {
      const context = this.runtime.context() as common.UIAbilityContext;
      this.state.lanMode = TransferPhase.RECEIVING;
      const discovery = new LocalBackupDiscovery(context, (devices: LanDevice[]) => {
        if (this.lanDiscovery !== discovery) return;
        this.state.lanDevices = devices.slice();
        if (this.state.selectedLanDevice !== '' && !devices.some((device: LanDevice) => device.id === this.state.selectedLanDevice)) {
          this.state.selectedLanDevice = '';
        }
      });
      this.lanDiscovery = discovery;
      discovery.start();
    } catch (error) {
      this.stopLan();
      this.runtime.notify(this.runtime.errorMessage(error as Error));
    }
  }

  async receiveLan(): Promise<void> {
    if (this.state.lanMode !== TransferPhase.RECEIVING || this.state.busy) return;
    const device = this.state.lanDevices.find((item: LanDevice) => item.id === this.state.selectedLanDevice);
    if (!device) { this.runtime.notify('请先选择发送设备'); return; }
    if (!/^\d{4}$/.test(this.state.lanEnteredPin)) { this.runtime.notify('请输入四位数字 PIN'); return; }
    this.state.lanMode = TransferPhase.CONNECTING;
    const receiver = LocalBackupReceiver.start(device, this.state.lanEnteredPin);
    this.lanReceiver = receiver;
    try {
      const incoming = BackupService.parseStrict(await receiver.result);
      if (this.lanReceiver !== receiver) return;
      this.lanReceiver = undefined;
      this.stopLan();
      this.stageImport(incoming);
      this.runtime.notify('备份已接收，请选择合并或覆盖');
    } catch (error) {
      if (this.lanReceiver !== receiver) return;
      this.lanReceiver = undefined;
      this.state.lanMode = TransferPhase.RECEIVING;
      this.runtime.notify(this.runtime.errorMessage(error as Error));
    }
  }

  stopLan(): void {
    this.lanGeneration++;
    const sender = this.lanSender;
    const discovery = this.lanDiscovery;
    const receiver = this.lanReceiver;
    this.lanSender = undefined;
    this.lanDiscovery = undefined;
    this.lanReceiver = undefined;
    // Invalidate callbacks before closing adapters, which may call back synchronously.
    sender?.stop(false);
    discovery?.stop();
    receiver?.cancel();
    this.state.lanMode = TransferPhase.IDLE;
    this.state.lanPin = '';
    this.state.lanEnteredPin = '';
    this.state.lanDevices = [];
    this.state.selectedLanDevice = '';
  }

  async applyBackup(merge: boolean): Promise<void> {
    if (!this.pendingImport || this.state.busy) return;
    const incoming = this.pendingImport;
    if (!merge) {
      // Overwrite deletes local-only records: the preview counts must reflect
      // the data as it is now, not as it was when the file was picked.
      const current = this.store.snapshot();
      if (!this.pendingSnapshot || !BackupDiff.sameData(this.pendingSnapshot, current)) {
        this.pendingSnapshot = current;
        this.state.importSummary = this.describeImport(incoming, current);
        this.state.importPhase = ImportPhase.PREVIEW;
        this.runtime.notify('预览后本地数据有变化，差异已重新计算，请确认后再覆盖');
        return;
      }
    }
    this.state.busy = true;
    this.state.importPhase = ImportPhase.APPLYING;
    try {
      if (merge) {
        await this.store.mergeAll(incoming.logs, incoming.emotions, incoming.tasks);
      } else {
        await this.store.replaceAll(incoming.logs, incoming.emotions, incoming.tasks);
      }
      this.pendingImport = undefined;
      this.pendingSnapshot = undefined;
      this.state.importSummary = '';
      this.state.importPhase = ImportPhase.IDLE;
      const context = this.runtime.context() as common.UIAbilityContext;
      try {
        await TaskReminderScheduler.rebuild(context, this.store.snapshot().tasks, false);
        this.runtime.notify(merge ? '备份已合并' : '本地数据已覆盖');
      } catch (_) {
        this.runtime.notify((merge ? '备份已合并' : '本地数据已覆盖') + '，但系统提醒恢复失败');
      }
    } catch (error) {
      this.state.importPhase = this.pendingImport ? ImportPhase.PREVIEW : ImportPhase.IDLE;
      this.runtime.notify(this.runtime.errorMessage(error as Error));
    } finally {
      this.state.busy = false;
    }
  }

}
