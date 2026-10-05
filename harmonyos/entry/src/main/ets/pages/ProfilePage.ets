import { NavigationState, ThemeState, BackupState, FeedbackState, SettingsState, TransferPhase, ImportPhase, DeleteKind, contentLayout } from '../state/FeatureStates';
import { LanDevice } from '../data/LocalBackupTransfer';
import { PageActions, requireActions } from '../state/PageActions';
import {
  PageHeader, DOCK_CLEARANCE, RADIUS_CARD, BRAND, SegmentedControl, FlashCard, brandText, cardShadowColor,
  dangerText, hairlineColor, iconSemantic, motionDuration, MOTION_PRESS,
  TYPE_DISPLAY, TYPE_SECTION, TYPE_GROUP, TYPE_BODY, TYPE_SECONDARY, TYPE_CAPTION
} from '../components/CommonBuilders';

@Component
export struct ProfilePage {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink backup: BackupState;
  @ObjectLink feedback: FeedbackState;
  @ObjectLink settings: SettingsState;
  actions?: PageActions;

  // 840vp 或折叠屏展开态：设置分组双列排布。
  private isDual(): boolean {
    return contentLayout(this.navigation.isExpandedWindow, this.navigation.foldable, this.navigation.foldStatus) === 'dual';
  }

  @Builder
  private profilePage() {
    Scroll() {
      Column({ space: 16 }) {
        PageHeader(this.theme, '设置', '数据、备份与应用设置')

        FlashCard({ theme: this.theme, contentPadding: 20, space: 8 }) {
          SymbolGlyph($r('sys.symbol.doc_text')).fontSize(24).fontColor([brandText(this.theme)])
          Text('数据默认保存在此设备').fontSize(TYPE_GROUP).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
          Text('可导出备份或在可信局域网内传输').fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted)
        }

        if (this.isDual()) {
          Row({ space: 16 }) {
            Column({ space: 16 }) {
              this.appearanceGroup()
              this.recordsGroup()
              this.platformGroup()
              this.aboutGroup()
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Column({ space: 16 }) {
              this.backupGroup()
              this.lanGroup()
              this.dangerGroup()
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.alignItems(VerticalAlign.Top).width('100%')
        } else {
          this.appearanceGroup()
          this.recordsGroup()
          this.platformGroup()
          this.backupGroup()
          this.lanGroup()
          this.dangerGroup()
          this.aboutGroup()
        }
      }.width('100%').padding({ left: 20, right: 20, bottom: DOCK_CLEARANCE })
    }.width('100%').height('100%').backgroundColor(this.theme.themeBackground)
  }

  @Builder
  private appearanceGroup() {
    this.groupLabel('外观与使用')
    FlashCard({ theme: this.theme, space: 12 }) {
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.slider_vertical_3')).fontSize(20).fontColor([iconSemantic(this.theme, 'appearance')]).width(28)
        Text('主题').fontSize(TYPE_BODY).fontColor(this.theme.themeText).layoutWeight(1)
        Text(this.themeModeLabel()).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted)
      }.width('100%').height(32)
      SegmentedControl(this.theme, ['浅色', '深色', '跟随系统'], this.themeModeIndex(),
        (index: number) => requireActions(this.actions).setThemeMode(['light', 'dark', 'system'][index]))
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.bolt')).fontSize(20).fontColor([iconSemantic(this.theme, 'appearance')]).width(28)
        Column({ space: 2 }) {
          Text('减少动态效果').fontSize(TYPE_BODY).fontColor(this.theme.themeText).width('100%')
          Text('系统无公开查询接口，此为应用内设置').fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted).width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.settings.reduceMotion })
          .onChange((value: boolean) => {
            requireActions(this.actions).controller.setReduceMotion(value);
          })
      }.width('100%')
      if (this.settings.notificationSettingsSupported) {
        Row({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.bell')).fontSize(20).fontColor([iconSemantic(this.theme, 'appearance')]).width(28)
          Text('通知设置').fontSize(TYPE_BODY).fontColor(this.theme.themeText).layoutWeight(1)
          Text('›').fontSize(TYPE_SECTION).fontColor(this.theme.themeMuted)
        }.width('100%').height(44)
          .accessibilityGroup(true)
          .accessibilityText('通知设置')
          .hoverEffect(HoverEffect.Highlight)
          .stateStyles({
            normal: { .opacity(1) },
            pressed: { .opacity(0.6) }
          })
          .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
          .onClick(() => requireActions(this.actions).controller.openNotificationSettings())
      }
    }
  }

  @Builder
  private recordsGroup() {
    this.groupLabel('记录与回顾')
    FlashCard({ theme: this.theme, contentPadding: 14, space: 2 }) {
      this.navRow($r('sys.symbol.calendar'), iconSemantic(this.theme, 'calendar'), '日历', '按日期回看日志与情绪',
        () => requireActions(this.actions).openDetail('calendar'))
      this.navRow($r('sys.symbol.face_smiling'), iconSemantic(this.theme, 'emotion'), '情绪记录', '七级情绪与子情绪',
        () => requireActions(this.actions).openDetail('emotion'))
      // 记录管理直接路由到记录页（ExplorePage），不再保留重复的精简版页面。
      this.navRow($r('sys.symbol.doc_text'), iconSemantic(this.theme, 'logs'), '记录管理', '搜索、筛选、整理与分享记录',
        () => requireActions(this.actions).switchTab(1))
    }
  }

  @Builder
  private platformGroup() {
    this.groupLabel('平台能力')
    FlashCard({ theme: this.theme, contentPadding: 14, space: 2 }) {
      this.navRow($r('sys.symbol.bolt'), brandText(this.theme), '鸿蒙体验', '星闪、实况窗、智慧服务与多设备',
        () => requireActions(this.actions).openDetail('harmony'))
    }
  }

  @Builder
  private backupGroup() {
    this.groupLabel('数据与安全')
    FlashCard({ theme: this.theme, space: 2 }) {
      Text('可在 Android、macOS 与 HarmonyOS 之间迁移日志、情绪和任务。备份为明文 JSON，请只保存或分享至可信位置。')
        .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).lineHeight(19).width('100%').padding({ top: 12, bottom: 6 })
      this.actionRow($r('sys.symbol.doc_text'), iconSemantic(this.theme, 'safe'), '导出备份 JSON', '生成 flash-backup-v2 备份文件',
        !this.backup.fileBusy, () => requireActions(this.actions).backupController.exportBackup())
      if (requireActions(this.actions).backupController.sharedExportAvailable()) {
        this.actionRow($r('sys.symbol.folder'), iconSemantic(this.theme, 'safe'), '导出到下载目录', '在系统文件管理中可见（下载/Flash）',
          !this.backup.fileBusy, () => requireActions(this.actions).backupController.exportBackupToSharedDir())
      }
      if (this.settings.systemShareSupported) {
        this.actionRow($r('sys.symbol.doc_text'), iconSemantic(this.theme, 'safe'), '分享导出', '生成备份文件并通过系统分享发送',
          !this.backup.fileBusy, () => requireActions(this.actions).backupController.shareBackupExport())
      }
      this.actionRow($r('sys.symbol.magnifyingglass'), iconSemantic(this.theme, 'safe'), '标准导入并分析差异', '导入前先看合并与新增明细',
        !this.backup.fileBusy && !this.backup.busy, () => requireActions(this.actions).backupController.chooseBackup())
      this.actionRow($r('sys.symbol.clock_arrow_2_circlepath'), iconSemantic(this.theme, 'safe'), '恢复损坏或旧版备份', '尝试修复无法直接导入的备份',
        !this.backup.fileBusy && !this.backup.busy, () => requireActions(this.actions).backupController.chooseBackup(true))
      if (this.backup.recoveryAvailable) {
        this.actionRow($r('sys.symbol.doc_text'), dangerText(this.theme), '导出旧版异常原始数据', '仅用于人工恢复，请勿公开分享',
          true, () => requireActions(this.actions).backupController.exportRecoveryData())
        this.actionRow($r('sys.symbol.clock_arrow_2_circlepath'), dangerText(this.theme), '清除隔离区', '删除本地保留的异常原始数据副本',
          !this.backup.fileBusy, () => requireActions(this.actions).backupController.clearRecoveryData())
      }
      if (this.backup.importPhase !== ImportPhase.IDLE) {
        Column({ space: 10 }) {
          Text('差异分析').fontSize(TYPE_BODY).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          Text(this.backup.importSummary).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).lineHeight(20).width('100%')
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
    }
  }

  @Builder
  private lanGroup() {
    this.groupLabel('局域网传输')
    FlashCard({ theme: this.theme, space: 2 }) {
      Text('与 Android、macOS 共用协议：六位 PIN、60 秒有效、最多尝试五次。备份内容未做端到端加密，请仅在可信的家庭或办公局域网使用。')
        .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).lineHeight(19).width('100%').padding({ top: 12, bottom: 6 })
      if (this.backup.lanMode === TransferPhase.IDLE) {
        this.actionRow($r('sys.symbol.house'), iconSemantic(this.theme, 'lan'), '发送备份', '生成六位 PIN，等待对方接收',
          true, () => requireActions(this.actions).backupController.startLanSend())
        this.actionRow($r('sys.symbol.house'), iconSemantic(this.theme, 'lan'), '接收备份', '搜索发送设备并输入 PIN',
          true, () => requireActions(this.actions).backupController.startLanReceive())
      } else if (this.backup.lanMode === TransferPhase.SENDING) {
        Column({ space: 8 }) {
          Text('配对 PIN').fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted)
          Text(this.backup.lanPin).fontSize(TYPE_DISPLAY).fontWeight(FontWeight.Bold).fontColor(iconSemantic(this.theme, 'lan')).letterSpacing(6)
          Text('请在接收设备输入此 PIN；60 秒后自动失效。').fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted)
          Button('取消发送').width('100%').height(44).fontColor(this.theme.themeMuted).backgroundColor(this.theme.themeControl)
            .onClick(() => requireActions(this.actions).backupController.stopLan())
        }.width('100%').padding(12).backgroundColor(this.theme.themeControl).borderRadius(14).margin({ bottom: 8 })
      } else {
        Column({ space: 8 }) {
          Text(this.backup.lanDevices.length === 0 ? '正在搜索发送设备…' : '选择发送设备')
            .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
          ForEach(this.backup.lanDevices, (device: LanDevice) => {
            Button(device.name).width('100%').height(44)
              .fontColor(this.backup.selectedLanDevice === device.id ? Color.White : this.theme.themeText)
              .backgroundColor(this.backup.selectedLanDevice === device.id ? iconSemantic(this.theme, 'lan') : this.theme.themeControl)
              .onClick(() => this.backup.selectedLanDevice = device.id)
          }, (device: LanDevice) => device.id)
          TextInput({ placeholder: '六位配对 PIN', text: this.backup.lanEnteredPin })
            .type(InputType.Number).maxLength(6).height(44)
            .fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
            .backgroundColor(this.theme.themeControl).borderRadius(12)
            .onChange((value: string) => this.backup.lanEnteredPin = value.replace(/\D/g, '').slice(0, 6))
          Row({ space: 8 }) {
            Button(this.backup.lanMode === TransferPhase.CONNECTING ? '正在接收…' : '验证并接收').layoutWeight(1).height(44)
              .backgroundColor(iconSemantic(this.theme, 'lan')).enabled(this.backup.lanMode !== TransferPhase.CONNECTING)
              .onClick(() => requireActions(this.actions).backupController.receiveLan())
            Button('取消').width(80).height(44).fontColor(this.theme.themeMuted).backgroundColor(this.theme.themeControl)
              .onClick(() => requireActions(this.actions).backupController.stopLan())
          }.width('100%')
        }.width('100%').padding(12).backgroundColor(this.theme.themeControl).borderRadius(14).margin({ bottom: 8 })
      }
    }
  }

  @Builder
  private dangerGroup() {
    this.groupLabel('危险操作')
    FlashCard({ theme: this.theme, space: 2 }) {
      Text('清空会删除本机全部日志、情绪和任务，且无法撤销，建议先导出备份。')
        .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).lineHeight(19).width('100%').padding({ top: 12, bottom: 6 })
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.doc_text')).fontSize(20).fontColor([dangerText(this.theme)]).width(28)
        Column({ space: 2 }) {
          Text('清空全部本地数据').fontSize(TYPE_BODY).fontColor(dangerText(this.theme)).width('100%')
          Text('删除后需要再次确认，不可恢复').fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted).width('100%')
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
    }
  }

  @Builder
  private aboutGroup() {
    this.groupLabel('关于 Flash')
    Column({ space: 6 }) {
      Text('Flash Aero').fontSize(TYPE_SECTION).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText)
      Text('v0.1.0 · HarmonyOS 原生版 · com.flash.app.harmonyos').fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted)
      Text('让每一次闪念都有落点').fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted)
    }.width('100%').height(130).justifyContent(FlexAlign.Center).backgroundColor(this.theme.themeTint).borderRadius(RADIUS_CARD)
      .border({ width: 0.5, color: hairlineColor(this.theme) })
      .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })
  }

  @Builder
  private groupLabel(title: string) {
    Text(title).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%').padding({ left: 4 })
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
  private navRow(icon: Resource, color: string, title: string, subtitle: string, onTap: () => void) {
    Row({ space: 12 }) {
      SymbolGlyph(icon).fontSize(20).fontColor([color]).width(28)
      Column({ space: 2 }) {
        Text(title).fontSize(TYPE_BODY).fontColor(this.theme.themeText).width('100%')
        Text(subtitle).fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text('›').fontSize(TYPE_SECTION).fontColor(this.theme.themeMuted)
    }
    .width('100%')
    .height(64)
    .accessibilityGroup(true)
    .accessibilityText(`${title}，${subtitle}`)
    .hoverEffect(HoverEffect.Highlight)
    .stateStyles({
      normal: { .opacity(1) },
      pressed: { .opacity(0.6) }
    })
    .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
    .onClick(onTap)
  }

  @Builder
  private actionRow(icon: Resource, color: string, title: string, subtitle: string, enabled: boolean, onTap: () => void) {
    Row({ space: 12 }) {
      SymbolGlyph(icon).fontSize(20).fontColor([enabled ? color : this.theme.themeMuted]).width(28)
      Column({ space: 2 }) {
        Text(title).fontSize(TYPE_BODY).fontColor(enabled ? this.theme.themeText : this.theme.themeMuted).width('100%')
        Text(subtitle).fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .accessibilityGroup(true)
    .accessibilityText(`${title}，${subtitle}` + (enabled ? '' : '，当前不可用'))
    .enabled(enabled)
    .opacity(enabled ? 1 : 0.5)
    .hoverEffect(HoverEffect.Highlight)
    .stateStyles({
      normal: { .opacity(enabled ? 1 : 0.5) },
      pressed: { .opacity(0.6) }
    })
    .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
    .onClick(() => {
      if (enabled) onTap();
    })
  }

  build() {
    this.profilePage()
  }
}
