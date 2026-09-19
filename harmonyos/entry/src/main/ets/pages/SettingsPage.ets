import { ThemeState, BackupState, FeedbackState, TransferPhase, ImportPhase, DeleteKind } from '../state/FeatureStates';
import { LanDevice } from '../data/LocalBackupTransfer';
import { PageActions, requireActions } from '../state/PageActions';
import { BRAND, RADIUS_CARD } from '../components/CommonBuilders';

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
          Text('外观与使用').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          Text('选择适合你的明暗外观。')
            .fontSize(12).fontColor(this.theme.themeMuted).width('100%')
          Row({ space: 8 }) {
            Button('浅色').layoutWeight(1).height(44)
              .fontColor(this.theme.themeMode === 'light' ? Color.White : this.theme.themeText)
              .backgroundColor(this.theme.themeMode === 'light' ? BRAND : this.theme.themeControl)
              .onClick(() => requireActions(this.actions).setThemeMode('light'))
            Button('深色').layoutWeight(1).height(44)
              .fontColor(this.theme.themeMode === 'dark' ? Color.White : this.theme.themeText)
              .backgroundColor(this.theme.themeMode === 'dark' ? BRAND : this.theme.themeControl)
              .onClick(() => requireActions(this.actions).setThemeMode('dark'))
          }.width('100%')
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)

        Column({ space: 8 }) {
          Text('数据与安全').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          Text('可在 Android、macOS 与 HarmonyOS 之间迁移日志、情绪和任务。')
            .fontSize(12).fontColor(this.theme.themeMuted).width('100%')
          Text('备份为明文 JSON，包含日志、情绪和任务内容；请只保存或分享至可信位置。')
            .fontSize(11).fontColor(this.theme.themeMuted).width('100%')
          Button('导出备份 JSON').width('100%').height(44).backgroundColor(BRAND)
            .enabled(!this.backup.fileBusy)
            .onClick(() => requireActions(this.actions).backupController.exportBackup())
          Button('标准导入并分析差异').width('100%').height(44).fontColor(BRAND).backgroundColor(this.theme.themeTint)
            .enabled(!this.backup.fileBusy && !this.backup.busy)
            .onClick(() => requireActions(this.actions).backupController.chooseBackup())
          Button('恢复损坏或旧版备份').width('100%').height(44).fontColor(BRAND).backgroundColor(this.theme.themeTint)
            .enabled(!this.backup.fileBusy && !this.backup.busy)
            .onClick(() => requireActions(this.actions).backupController.chooseBackup(true))
          if (this.backup.recoveryAvailable) {
            Button('导出旧版异常原始数据').width('100%').height(44)
              .fontColor('#B42318').backgroundColor(this.theme.themeDanger)
              .onClick(() => requireActions(this.actions).backupController.exportRecoveryData())
            Text('该恢复文件可能包含无法解析的旧版内容，仅用于人工恢复，请勿公开分享。')
              .fontSize(11).fontColor(this.theme.themeMuted).width('100%')
            Button('清除隔离区').width('100%').height(44)
              .fontColor(this.theme.themeMuted).backgroundColor(this.theme.themeControl)
              .enabled(!this.backup.fileBusy)
              .onClick(() => requireActions(this.actions).backupController.clearRecoveryData())
            Text('删除本地保留的异常原始数据副本；导出恢复文件成功后会自动清除。')
              .fontSize(11).fontColor(this.theme.themeMuted).width('100%')
          }
          if (this.backup.importPhase !== ImportPhase.IDLE) {
            Column({ space: 10 }) {
              Text('差异分析').fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
              Text(this.backup.importSummary).fontSize(12).fontColor(this.theme.themeMuted).lineHeight(20).width('100%')
              Row({ space: 8 }) {
                Button('合并').layoutWeight(1).height(44).backgroundColor(BRAND)
                  .enabled(!this.backup.busy)
                  .onClick(() => requireActions(this.actions).backupController.applyBackup(true))
                Button('覆盖').layoutWeight(1).height(44).fontColor('#B42318').backgroundColor(this.theme.themeDanger)
                  .enabled(!this.backup.busy)
                  .onClick(() => requireActions(this.actions).backupController.applyBackup(false))
                Button('取消').layoutWeight(1).height(44).fontColor(this.theme.themeMuted).backgroundColor(this.theme.themeControl)
                  .enabled(!this.backup.busy)
                  .onClick(() => requireActions(this.actions).backupController.cancelImport())
              }.width('100%')
            }.width('100%').padding(12).backgroundColor(this.theme.themeControl).borderRadius(14)
          }
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)

        Column({ space: 8 }) {
          Text('局域网传输').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          Text('与 Android、macOS 共用协议：六位 PIN、60 秒有效、最多尝试五次。')
            .fontSize(12).fontColor(this.theme.themeMuted).width('100%')
          Text('备份内容未做端到端加密，请仅在可信的家庭或办公局域网使用。')
            .fontSize(11).fontColor(this.theme.themeMuted).width('100%')
          if (this.backup.lanMode === TransferPhase.IDLE) {
            Row({ space: 8 }) {
              Button('发送备份').layoutWeight(1).height(44).backgroundColor('#7A4CC2')
                .onClick(() => requireActions(this.actions).backupController.startLanSend())
              Button('接收备份').layoutWeight(1).height(44).fontColor('#7A4CC2').backgroundColor(this.theme.themeTint)
                .onClick(() => requireActions(this.actions).backupController.startLanReceive())
            }.width('100%')
          } else if (this.backup.lanMode === TransferPhase.SENDING) {
            Column({ space: 8 }) {
              Text('配对 PIN').fontSize(12).fontColor(this.theme.themeMuted)
              Text(this.backup.lanPin).fontSize(32).fontWeight(FontWeight.Bold).fontColor('#7A4CC2').letterSpacing(6)
              Text('请在接收设备输入此 PIN；60 秒后自动失效。').fontSize(12).fontColor(this.theme.themeMuted)
              Button('取消发送').width('100%').height(44).fontColor(this.theme.themeMuted).backgroundColor(this.theme.themeControl)
                .onClick(() => requireActions(this.actions).backupController.stopLan())
            }.width('100%').padding(12).backgroundColor(this.theme.themeControl).borderRadius(14)
          } else {
            Column({ space: 8 }) {
              Text(this.backup.lanDevices.length === 0 ? '正在搜索发送设备…' : '选择发送设备')
                .fontSize(13).fontColor(this.theme.themeMuted).width('100%')
              ForEach(this.backup.lanDevices, (device: LanDevice) => {
                Button(device.name).width('100%').height(44)
                  .fontColor(this.backup.selectedLanDevice === device.id ? Color.White : this.theme.themeText)
                  .backgroundColor(this.backup.selectedLanDevice === device.id ? '#7A4CC2' : this.theme.themeControl)
                  .onClick(() => this.backup.selectedLanDevice = device.id)
              }, (device: LanDevice) => device.id)
              TextInput({ placeholder: '六位配对 PIN', text: this.backup.lanEnteredPin })
                .type(InputType.Number).maxLength(6).height(44)
                .fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
                .backgroundColor(this.theme.themeControl).borderRadius(12)
                .onChange((value: string) => this.backup.lanEnteredPin = value.replace(/\D/g, '').slice(0, 6))
              Row({ space: 8 }) {
                Button(this.backup.lanMode === TransferPhase.CONNECTING ? '正在接收…' : '验证并接收').layoutWeight(1).height(44)
                  .backgroundColor('#7A4CC2').enabled(this.backup.lanMode !== TransferPhase.CONNECTING)
                  .onClick(() => requireActions(this.actions).backupController.receiveLan())
                Button('取消').width(80).height(44).fontColor(this.theme.themeMuted).backgroundColor(this.theme.themeControl)
                  .onClick(() => requireActions(this.actions).backupController.stopLan())
              }.width('100%')
            }.width('100%').padding(12).backgroundColor(this.theme.themeControl).borderRadius(14)
          }
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)

        Column({ space: 8 }) {
        Text('危险操作').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
        Text('清空后无法撤销，建议先导出备份。').fontSize(12).fontColor(this.theme.themeMuted).width('100%')
        Button('清空全部本地数据').width('100%').height(44).fontColor('#B42318').backgroundColor(this.theme.themeDanger)
          .enabled(!this.backup.busy && !this.backup.fileBusy && this.backup.lanMode === TransferPhase.IDLE)
          .onClick(() => this.feedback.destructive = { kind: DeleteKind.ALL, id: '' })
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)
        Text('Flash Aero v0.1.0\nHarmonyOS 原生版 · com.flash.app.harmonyos')
          .fontSize(12).fontColor(this.theme.themeMuted).textAlign(TextAlign.Center).width('100%').margin({ top: 12 })
      }.width('100%').padding({ left: 16, right: 16, bottom: 30 })
    }.width('100%').layoutWeight(1)
  }

  build() {
    this.settingsPage()
  }
}
