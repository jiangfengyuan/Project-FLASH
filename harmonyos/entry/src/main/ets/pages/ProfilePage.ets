import { ThemeState, BackupState, FeedbackState, SettingsState, TransferPhase, ImportPhase, DeleteKind } from '../state/FeatureStates';
import { LanDevice } from '../data/LocalBackupTransfer';
import { PageActions, requireActions } from '../state/PageActions';
import { PageHeader, DOCK_CLEARANCE, RADIUS_CARD, BRAND, SegmentedControl, brandText, cardShadowColor, dangerText, hairlineColor } from '../components/CommonBuilders';

// 语义图标色：在浅色卡片（#FFFFFF）与深色卡片（#3A3D5C）上对比度均 ≥3:1。
const ICON_APPEARANCE = '#5A88E8';
const ICON_CALENDAR = '#9A74EA';
const ICON_EMOTION = '#E35A90';
const ICON_LOGS = '#B08400';
const ICON_SAFE = '#1E9E62';
const ICON_LAN = '#9A74EA';

@Component
export struct ProfilePage {
  @ObjectLink theme: ThemeState;
  @ObjectLink backup: BackupState;
  @ObjectLink feedback: FeedbackState;
  @ObjectLink settings: SettingsState;
  actions?: PageActions;

  @Builder
  private profilePage() {
    Scroll() {
      Column({ space: 16 }) {
        PageHeader(this.theme, '设置', '数据、备份与应用设置')

        Column({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.doc_text')).fontSize(24).fontColor([brandText(this.theme)])
          Text('数据默认保存在此设备').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
          Text('可导出备份或在可信局域网内传输').fontSize(12).fontColor(this.theme.themeMuted)
        }.width('100%').padding(20).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)
          .border({ width: 0.5, color: hairlineColor(this.theme) })
          .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })

        this.groupLabel('外观与使用')
        Column({ space: 12 }) {
          Row({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.slider_vertical_3')).fontSize(20).fontColor([ICON_APPEARANCE]).width(28)
            Text('主题').fontSize(15).fontColor(this.theme.themeText).layoutWeight(1)
            Text(this.themeModeLabel()).fontSize(13).fontColor(this.theme.themeMuted)
          }.width('100%').height(32)
          SegmentedControl(this.theme, ['浅色', '深色', '跟随系统'], this.themeModeIndex(),
            (index: number) => requireActions(this.actions).setThemeMode(['light', 'dark', 'system'][index]))
          if (this.settings.notificationSettingsSupported) {
            Row({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.bell')).fontSize(20).fontColor([ICON_APPEARANCE]).width(28)
              Text('通知设置').fontSize(15).fontColor(this.theme.themeText).layoutWeight(1)
              Text('›').fontSize(22).fontColor(this.theme.themeMuted)
            }.width('100%').height(44)
              .accessibilityGroup(true)
              .accessibilityText('通知设置')
              .stateStyles({
                normal: { .opacity(1) },
                pressed: { .opacity(0.6) }
              })
              .animation({ duration: 120, curve: Curve.EaseOut })
              .onClick(() => requireActions(this.actions).controller.openNotificationSettings())
          }
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)
          .border({ width: 0.5, color: hairlineColor(this.theme) })
          .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })

        this.groupLabel('记录与回顾')
        Column({ space: 2 }) {
          this.navRow($r('sys.symbol.calendar'), ICON_CALENDAR, '日历', '按日期回看日志与情绪', 'calendar')
          this.navRow($r('sys.symbol.face_smiling'), ICON_EMOTION, '情绪记录', '七级情绪与子情绪', 'emotion')
          this.navRow($r('sys.symbol.doc_text'), ICON_LOGS, '记录管理', '搜索、查看和删除记录', 'logs')
        }.width('100%').backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD).padding({ left: 14, right: 14 })
          .border({ width: 0.5, color: hairlineColor(this.theme) })
          .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })

        this.groupLabel('平台能力')
        Column({ space: 2 }) {
          this.navRow($r('sys.symbol.bolt'), brandText(this.theme), '鸿蒙体验', '星闪、实况窗、智慧服务与多设备', 'harmony')
        }.width('100%').backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD).padding({ left: 14, right: 14 })
          .border({ width: 0.5, color: hairlineColor(this.theme) })
          .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })

        this.groupLabel('数据与安全')
        Column({ space: 2 }) {
          Text('可在 Android、macOS 与 HarmonyOS 之间迁移日志、情绪和任务。备份为明文 JSON，请只保存或分享至可信位置。')
            .fontSize(12).fontColor(this.theme.themeMuted).lineHeight(19).width('100%').padding({ top: 12, bottom: 6 })
          this.actionRow($r('sys.symbol.doc_text'), ICON_SAFE, '导出备份 JSON', '生成 flash-backup-v2 备份文件',
            !this.backup.fileBusy, () => requireActions(this.actions).backupController.exportBackup())
          if (requireActions(this.actions).backupController.sharedExportAvailable()) {
            this.actionRow($r('sys.symbol.folder'), ICON_SAFE, '导出到下载目录', '在系统文件管理中可见（下载/Flash）',
              !this.backup.fileBusy, () => requireActions(this.actions).backupController.exportBackupToSharedDir())
          }
          this.actionRow($r('sys.symbol.magnifyingglass'), ICON_SAFE, '标准导入并分析差异', '导入前先看合并与新增明细',
            !this.backup.fileBusy && !this.backup.busy, () => requireActions(this.actions).backupController.chooseBackup())
          this.actionRow($r('sys.symbol.clock_arrow_2_circlepath'), ICON_SAFE, '恢复损坏或旧版备份', '尝试修复无法直接导入的备份',
            !this.backup.fileBusy && !this.backup.busy, () => requireActions(this.actions).backupController.chooseBackup(true))
          if (this.backup.recoveryAvailable) {
            this.actionRow($r('sys.symbol.doc_text'), dangerText(this.theme), '导出旧版异常原始数据', '仅用于人工恢复，请勿公开分享',
              true, () => requireActions(this.actions).backupController.exportRecoveryData())
            this.actionRow($r('sys.symbol.clock_arrow_2_circlepath'), dangerText(this.theme), '清除隔离区', '删除本地保留的异常原始数据副本',
              !this.backup.fileBusy, () => requireActions(this.actions).backupController.clearRecoveryData())
          }
          if (this.backup.importPhase !== ImportPhase.IDLE) {
            Column({ space: 10 }) {
              Text('差异分析').fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
              Text(this.backup.importSummary).fontSize(12).fontColor(this.theme.themeMuted).lineHeight(20).width('100%')
              Row({ space: 8 }) {
                Button('合并').layoutWeight(1).height(44).backgroundColor(BRAND)
                  .enabled(!this.backup.busy)
                  .onClick(() => requireActions(this.actions).backupController.applyBackup(true))
                Button('覆盖').layoutWeight(1).height(44).fontColor(dangerText(this.theme)).backgroundColor(this.theme.themeDanger)
                  .enabled(!this.backup.busy)
                  .onClick(() => requireActions(this.actions).backupController.applyBackup(false))
                Button('取消').layoutWeight(1).height(44).fontColor(this.theme.themeMuted).backgroundColor(this.theme.themeControl)
                  .enabled(!this.backup.busy)
                  .onClick(() => requireActions(this.actions).backupController.cancelImport())
              }.width('100%')
            }.width('100%').padding(12).backgroundColor(this.theme.themeControl).borderRadius(14)
          }
        }.width('100%').padding({ left: 16, right: 16, bottom: 6 }).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)
          .border({ width: 0.5, color: hairlineColor(this.theme) })
          .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })

        this.groupLabel('局域网传输')
        Column({ space: 2 }) {
          Text('与 Android、macOS 共用协议：六位 PIN、60 秒有效、最多尝试五次。备份内容未做端到端加密，请仅在可信的家庭或办公局域网使用。')
            .fontSize(12).fontColor(this.theme.themeMuted).lineHeight(19).width('100%').padding({ top: 12, bottom: 6 })
          if (this.backup.lanMode === TransferPhase.IDLE) {
            this.actionRow($r('sys.symbol.house'), ICON_LAN, '发送备份', '生成六位 PIN，等待对方接收',
              true, () => requireActions(this.actions).backupController.startLanSend())
            this.actionRow($r('sys.symbol.house'), ICON_LAN, '接收备份', '搜索发送设备并输入 PIN',
              true, () => requireActions(this.actions).backupController.startLanReceive())
          } else if (this.backup.lanMode === TransferPhase.SENDING) {
            Column({ space: 8 }) {
              Text('配对 PIN').fontSize(12).fontColor(this.theme.themeMuted)
              Text(this.backup.lanPin).fontSize(32).fontWeight(FontWeight.Bold).fontColor(ICON_LAN).letterSpacing(6)
              Text('请在接收设备输入此 PIN；60 秒后自动失效。').fontSize(12).fontColor(this.theme.themeMuted)
              Button('取消发送').width('100%').height(44).fontColor(this.theme.themeMuted).backgroundColor(this.theme.themeControl)
                .onClick(() => requireActions(this.actions).backupController.stopLan())
            }.width('100%').padding(12).backgroundColor(this.theme.themeControl).borderRadius(14).margin({ bottom: 8 })
          } else {
            Column({ space: 8 }) {
              Text(this.backup.lanDevices.length === 0 ? '正在搜索发送设备…' : '选择发送设备')
                .fontSize(13).fontColor(this.theme.themeMuted).width('100%')
              ForEach(this.backup.lanDevices, (device: LanDevice) => {
                Button(device.name).width('100%').height(44)
                  .fontColor(this.backup.selectedLanDevice === device.id ? Color.White : this.theme.themeText)
                  .backgroundColor(this.backup.selectedLanDevice === device.id ? ICON_LAN : this.theme.themeControl)
                  .onClick(() => this.backup.selectedLanDevice = device.id)
              }, (device: LanDevice) => device.id)
              TextInput({ placeholder: '六位配对 PIN', text: this.backup.lanEnteredPin })
                .type(InputType.Number).maxLength(6).height(44)
                .fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
                .backgroundColor(this.theme.themeControl).borderRadius(12)
                .onChange((value: string) => this.backup.lanEnteredPin = value.replace(/\D/g, '').slice(0, 6))
              Row({ space: 8 }) {
                Button(this.backup.lanMode === TransferPhase.CONNECTING ? '正在接收…' : '验证并接收').layoutWeight(1).height(44)
                  .backgroundColor(ICON_LAN).enabled(this.backup.lanMode !== TransferPhase.CONNECTING)
                  .onClick(() => requireActions(this.actions).backupController.receiveLan())
                Button('取消').width(80).height(44).fontColor(this.theme.themeMuted).backgroundColor(this.theme.themeControl)
                  .onClick(() => requireActions(this.actions).backupController.stopLan())
              }.width('100%')
            }.width('100%').padding(12).backgroundColor(this.theme.themeControl).borderRadius(14).margin({ bottom: 8 })
          }
        }.width('100%').padding({ left: 16, right: 16, bottom: 6 }).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)
          .border({ width: 0.5, color: hairlineColor(this.theme) })
          .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })

        this.groupLabel('危险操作')
        Column({ space: 2 }) {
          Text('清空会删除本机全部日志、情绪和任务，且无法撤销，建议先导出备份。')
            .fontSize(12).fontColor(this.theme.themeMuted).lineHeight(19).width('100%').padding({ top: 12, bottom: 6 })
          Row({ space: 12 }) {
            SymbolGlyph($r('sys.symbol.doc_text')).fontSize(20).fontColor([dangerText(this.theme)]).width(28)
            Column({ space: 2 }) {
              Text('清空全部本地数据').fontSize(15).fontColor(dangerText(this.theme)).width('100%')
              Text('删除后需要再次确认，不可恢复').fontSize(11).fontColor(this.theme.themeMuted).width('100%')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ top: 12, bottom: 12 })
          .accessibilityGroup(true)
          .accessibilityText('清空全部本地数据，删除后需要再次确认，不可恢复')
          .enabled(!this.backup.busy && !this.backup.fileBusy && this.backup.lanMode === TransferPhase.IDLE)
          .opacity(this.backup.busy || this.backup.fileBusy || this.backup.lanMode !== TransferPhase.IDLE ? 0.4 : 1)
          .onClick(() => {
            if (!this.backup.busy && !this.backup.fileBusy && this.backup.lanMode === TransferPhase.IDLE) {
              this.feedback.destructive = { kind: DeleteKind.ALL, id: '' };
            }
          })
        }.width('100%').padding({ left: 16, right: 16, bottom: 6 }).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)
          .border({ width: 0.5, color: hairlineColor(this.theme) })
          .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })

        this.groupLabel('关于 Flash')
        Column({ space: 6 }) {
          Text('Flash Aero').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText)
          Text('v0.1.0 · HarmonyOS 原生版 · com.flash.app.harmonyos').fontSize(13).fontColor(this.theme.themeMuted)
          Text('让每一次闪念都有落点').fontSize(12).fontColor(this.theme.themeMuted)
        }.width('100%').height(130).justifyContent(FlexAlign.Center).backgroundColor(this.theme.themeTint).borderRadius(RADIUS_CARD)
          .border({ width: 0.5, color: hairlineColor(this.theme) })
          .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })
      }.width('100%').padding({ left: 20, right: 20, bottom: DOCK_CLEARANCE })
    }.width('100%').height('100%').backgroundColor(this.theme.themeBackground)
  }

  @Builder
  private groupLabel(title: string) {
    Text(title).fontSize(13).fontColor(this.theme.themeMuted).width('100%').padding({ left: 4 })
  }

  private themeModeIndex(): number {
    if (this.theme.themeMode === 'dark') return 1;
    if (this.theme.themeMode === 'system') return 2;
    return 0;
  }

  private themeModeLabel(): string {
    if (this.theme.themeMode === 'dark') return '深色';
    if (this.theme.themeMode === 'system') return '跟随系统';
    return '浅色';
  }

  @Builder
  private navRow(icon: Resource, color: string, title: string, subtitle: string, destination: string) {
    Row({ space: 12 }) {
      SymbolGlyph(icon).fontSize(20).fontColor([color]).width(28)
      Column({ space: 2 }) {
        Text(title).fontSize(15).fontColor(this.theme.themeText).width('100%')
        Text(subtitle).fontSize(11).fontColor(this.theme.themeMuted).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text('›').fontSize(22).fontColor(this.theme.themeMuted)
    }
    .width('100%')
    .height(64)
    .accessibilityGroup(true)
    .accessibilityText(`${title}，${subtitle}`)
    .stateStyles({
      normal: { .opacity(1) },
      pressed: { .opacity(0.6) }
    })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .onClick(() => requireActions(this.actions).openDetail(destination))
  }

  @Builder
  private actionRow(icon: Resource, color: string, title: string, subtitle: string, enabled: boolean, onTap: () => void) {
    Row({ space: 12 }) {
      SymbolGlyph(icon).fontSize(20).fontColor([enabled ? color : this.theme.themeMuted]).width(28)
      Column({ space: 2 }) {
        Text(title).fontSize(15).fontColor(enabled ? this.theme.themeText : this.theme.themeMuted).width('100%')
        Text(subtitle).fontSize(11).fontColor(this.theme.themeMuted).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .accessibilityGroup(true)
    .accessibilityText(`${title}，${subtitle}` + (enabled ? '' : '，当前不可用'))
    .enabled(enabled)
    .opacity(enabled ? 1 : 0.5)
    .stateStyles({
      normal: { .opacity(enabled ? 1 : 0.5) },
      pressed: { .opacity(0.6) }
    })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .onClick(() => {
      if (enabled) onTap();
    })
  }

  build() {
    this.profilePage()
  }
}
