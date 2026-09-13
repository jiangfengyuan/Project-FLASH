import { ThemeState, BackupState, FeedbackState, TransferPhase, ImportPhase, DeleteKind } from '../state/FeatureStates';
import { LanDevice } from '../data/LocalBackupTransfer';
import { PageActions, requireActions } from '../state/PageActions';
const BRAND = '#6C5CE7';

@Component
export struct SettingsPage {
  @ObjectLink theme: ThemeState;
  @ObjectLink backup: BackupState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;

  @Builder
  private settingsPage() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 10 }) {
          Text('外观').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          Text('切换时平滑过渡背景、表面与文字颜色，不会重建当前页面。')
            .fontSize(12).fontColor(this.theme.themeMuted).width('100%')
          Row({ space: 8 }) {
            Button('浅色').layoutWeight(1).height(40)
              .fontColor(this.theme.themeMode === 'light' ? Color.White : this.theme.themeText)
              .backgroundColor(this.theme.themeMode === 'light' ? BRAND : this.theme.themeControl)
              .onClick(() => requireActions(this.actions).setThemeMode('light'))
            Button('深色').layoutWeight(1).height(40)
              .fontColor(this.theme.themeMode === 'dark' ? Color.White : this.theme.themeText)
              .backgroundColor(this.theme.themeMode === 'dark' ? BRAND : this.theme.themeControl)
              .onClick(() => requireActions(this.actions).setThemeMode('dark'))
          }.width('100%')
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(20)

        Column({ space: 8 }) {
          Text('跨设备备份').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          Text('备份格式与 Android、macOS 保持一致：flash-backup-v2（仍可导入 v1）')
            .fontSize(12).fontColor(this.theme.themeMuted).width('100%')
          Text('备份为明文 JSON，包含日志、情绪和任务内容；请只保存或分享至可信位置。')
            .fontSize(11).fontColor(this.theme.themeMuted).width('100%')
          Button('导出备份 JSON').width('100%').height(42).backgroundColor(BRAND)
            .enabled(!this.backup.fileBusy)
            .onClick(() => requireActions(this.actions).backupController.exportBackup())
          Button('标准导入并分析差异').width('100%').height(42).fontColor(BRAND).backgroundColor(this.theme.themeTint)
            .enabled(!this.backup.fileBusy && !this.backup.busy)
            .onClick(() => requireActions(this.actions).backupController.chooseBackup())
          Button('恢复损坏或旧版备份').width('100%').height(42).fontColor(BRAND).backgroundColor(this.theme.themeTint)
            .enabled(!this.backup.fileBusy && !this.backup.busy)
            .onClick(() => requireActions(this.actions).backupController.chooseBackup(true))
          if (this.backup.recoveryAvailable) {
            Button('导出旧版异常原始数据').width('100%').height(42)
              .fontColor('#B42318').backgroundColor(this.theme.themeDanger)
              .onClick(() => requireActions(this.actions).backupController.exportRecoveryData())
            Text('该恢复文件可能包含无法解析的旧版内容，仅用于人工恢复，请勿公开分享。')
              .fontSize(11).fontColor(this.theme.themeMuted).width('100%')
          }
          if (this.backup.importPhase !== ImportPhase.IDLE) {
            Column({ space: 10 }) {
              Text('差异分析').fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
              Text(this.backup.importSummary).fontSize(12).fontColor(this.theme.themeMuted).lineHeight(20).width('100%')
              Row({ space: 8 }) {
                Button('合并').layoutWeight(1).height(38).backgroundColor(BRAND)
                  .enabled(!this.backup.busy)
                  .onClick(() => requireActions(this.actions).backupController.applyBackup(true))
                Button('覆盖').layoutWeight(1).height(38).fontColor('#B42318').backgroundColor(this.theme.themeDanger)
                  .enabled(!this.backup.busy)
                  .onClick(() => requireActions(this.actions).backupController.applyBackup(false))
                Button('取消').layoutWeight(1).height(38).fontColor(this.theme.themeMuted).backgroundColor(this.theme.themeControl)
                  .enabled(!this.backup.busy)
                  .onClick(() => requireActions(this.actions).backupController.cancelImport())
              }.width('100%')
            }.width('100%').padding(12).backgroundColor(this.theme.themeControl).borderRadius(14)
          }
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(20)

        Column({ space: 8 }) {
          Text('局域网传输').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          Text('与 Android、macOS 共用协议：四位 PIN、60 秒有效、最多尝试五次。')
            .fontSize(12).fontColor(this.theme.themeMuted).width('100%')
          Text('备份内容未做端到端加密，请仅在可信的家庭或办公局域网使用。')
            .fontSize(11).fontColor(this.theme.themeMuted).width('100%')
          if (this.backup.lanMode === TransferPhase.IDLE) {
            Row({ space: 8 }) {
              Button('发送备份').layoutWeight(1).height(42).backgroundColor('#7A4CC2')
                .onClick(() => requireActions(this.actions).backupController.startLanSend())
              Button('接收备份').layoutWeight(1).height(42).fontColor('#7A4CC2').backgroundColor(this.theme.themeTint)
                .onClick(() => requireActions(this.actions).backupController.startLanReceive())
            }.width('100%')
          } else if (this.backup.lanMode === TransferPhase.SENDING) {
            Column({ space: 8 }) {
              Text('配对 PIN').fontSize(12).fontColor(this.theme.themeMuted)
              Text(this.backup.lanPin).fontSize(38).fontWeight(FontWeight.Bold).fontColor('#7A4CC2').letterSpacing(8)
              Text('请在接收设备输入此 PIN；60 秒后自动失效。').fontSize(12).fontColor(this.theme.themeMuted)
              Button('取消发送').width('100%').height(38).fontColor(this.theme.themeMuted).backgroundColor(this.theme.themeControl)
                .onClick(() => requireActions(this.actions).backupController.stopLan())
            }.width('100%').padding(12).backgroundColor(this.theme.themeControl).borderRadius(14)
          } else {
            Column({ space: 8 }) {
              Text(this.backup.lanDevices.length === 0 ? '正在搜索发送设备…' : '选择发送设备')
                .fontSize(13).fontColor(this.theme.themeMuted).width('100%')
              ForEach(this.backup.lanDevices, (device: LanDevice) => {
                Button(device.name).width('100%').height(38)
                  .fontColor(this.backup.selectedLanDevice === device.id ? Color.White : this.theme.themeText)
                  .backgroundColor(this.backup.selectedLanDevice === device.id ? '#7A4CC2' : this.theme.themeControl)
                  .onClick(() => this.backup.selectedLanDevice = device.id)
              }, (device: LanDevice) => device.id)
              TextInput({ placeholder: '四位配对 PIN', text: this.backup.lanEnteredPin })
                .type(InputType.Number).maxLength(4).height(42)
                .fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
                .backgroundColor(this.theme.themeControl).borderRadius(12)
                .onChange((value: string) => this.backup.lanEnteredPin = value.replace(/\D/g, '').slice(0, 4))
              Row({ space: 8 }) {
                Button(this.backup.lanMode === TransferPhase.CONNECTING ? '正在接收…' : '验证并接收').layoutWeight(1).height(40)
                  .backgroundColor('#7A4CC2').enabled(this.backup.lanMode !== TransferPhase.CONNECTING)
                  .onClick(() => requireActions(this.actions).backupController.receiveLan())
                Button('取消').width(80).height(40).fontColor(this.theme.themeMuted).backgroundColor(this.theme.themeControl)
                  .onClick(() => requireActions(this.actions).backupController.stopLan())
              }.width('100%')
            }.width('100%').padding(12).backgroundColor(this.theme.themeControl).borderRadius(14)
          }
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(20)

        Button('清空全部本地数据').width('100%').height(44).fontColor('#B42318').backgroundColor(this.theme.themeDanger)
          .onClick(() => this.feedback.destructive = { kind: DeleteKind.ALL, id: '' })
        Text('Flash Aero v0.1.0\nHarmonyOS 原生版 · com.flash.app.harmonyos')
          .fontSize(12).fontColor(this.theme.themeMuted).textAlign(TextAlign.Center).width('100%').margin({ top: 12 })
      }.width('100%').padding({ left: 16, right: 16, bottom: 30 })
    }.width('100%').layoutWeight(1)
  }

  build() {
    this.settingsPage()
  }
}
