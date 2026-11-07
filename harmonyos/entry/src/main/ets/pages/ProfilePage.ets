import { NavigationState, ThemeState, BackupState, FeedbackState, SettingsState, ImportPhase, DeleteKind, contentLayout } from '../state/FeatureStates';
import { IDEA_REMINDER_THRESHOLD } from '../data/IdeaReminder';
import { tr } from '../data/I18n';
import { PageActions, requireActions } from '../state/PageActions';
import {
  PageHeader, DOCK_CLEARANCE, RADIUS_CARD, SegmentedControl, FlashCard, brandText, brandFill, onBrandFill, cardShadowColor, pageGutter, paperShadow,
  dangerText, hairlineColor, iconSemantic, motionDuration, MOTION_PRESS,
  TYPE_SECTION, TYPE_GROUP, TYPE_BODY, TYPE_SECONDARY, TYPE_CAPTION
} from '../components/CommonBuilders';

const IDEA_FREQUENCIES: string[] = ['daily', 'every3days', 'weekly'];

@Component
export struct ProfilePage {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink backup: BackupState;
  @ObjectLink feedback: FeedbackState;
  @ObjectLink settings: SettingsState;
  actions?: PageActions;
  // 空串为设置首页；settings-idea / settings-backup / settings-transfer 为子页（对齐 iOS）。
  section: string = '';

  // 840vp 或折叠屏展开态：设置分组双列排布。
  private isDual(): boolean {
    return contentLayout(this.navigation.isExpandedWindow, this.navigation.foldable, this.navigation.foldStatus) === 'dual';
  }

  @Builder
  private profilePage() {
    Scroll() {
      Column({ space: 16 }) {
        if (this.section === 'settings-idea') {
          this.ideaReminderGroup()
        } else if (this.section === 'settings-backup') {
          this.backupGroup()
          this.dangerGroup()
        } else if (this.section === 'settings-transfer') {
          this.transferGroup()
        } else {
          PageHeader(this.theme, tr('设置'), tr('数据、备份与应用设置'))
          FlashCard({ theme: this.theme, seed: 'settings-local', space: 8 }) {
            SymbolGlyph($r('sys.symbol.doc_text')).fontSize(24).fontColor([brandText(this.theme)])
            Text(tr('数据默认保存在此设备')).fontSize(TYPE_GROUP).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
            Text(tr('可导出备份或通过系统分享传输')).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted)
          }
          if (this.isDual()) {
            Row({ space: 16 }) {
              Column({ space: 16 }) {
                this.appearanceGroup()
                this.platformGroup()
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Column({ space: 16 }) {
                this.dataGroup()
                this.aboutGroup()
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            }.alignItems(VerticalAlign.Top).width('100%')
          } else {
            this.appearanceGroup()
            this.dataGroup()
            this.platformGroup()
            this.aboutGroup()
          }
        }
      }.width('100%').padding({ left: pageGutter(), right: pageGutter(), bottom: this.section === '' ? DOCK_CLEARANCE : 32 })
    }.width('100%').height('100%')
  }

  @Builder
  private dataGroup() {
    this.groupLabel(tr('数据与安全'))
    FlashCard({ theme: this.theme, contentPadding: 14, space: 2 }) {
      this.navRow($r('sys.symbol.folder'), iconSemantic(this.theme, 'safe'), tr('备份与恢复'), tr('导出、导入与清空'),
        () => requireActions(this.actions).openDetail('settings-backup'))
      this.navRow($r('sys.symbol.house'), iconSemantic(this.theme, 'lan'), tr('设备间传输'), tr('暂时停用，点击查看替代方式'),
        () => requireActions(this.actions).openDetail('settings-transfer'))
    }
  }

  // 灵感提醒（对齐 iOS）：开关 + 频率；通知权限只在开启时申请。
  @Builder
  private ideaReminderGroup() {
    this.groupLabel(tr('提醒'))
    FlashCard({ theme: this.theme, space: 12 }) {
      Row({ space: 12 }) {
        Text(tr('想法等待梳理时提醒')).fontSize(TYPE_BODY).fontColor(this.theme.themeText).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.settings.ideaReminderEnabled })
          .onChange((value: boolean) => requireActions(this.actions).controller.setIdeaReminder(value, this.settings.ideaReminderFrequency))
      }.width('100%')
      if (this.settings.ideaReminderEnabled) {
        SegmentedControl(this.theme, [tr('每天'), tr('每 3 天'), tr('每周')], IDEA_FREQUENCIES.indexOf(this.settings.ideaReminderFrequency),
          (index: number) => requireActions(this.actions).controller.setIdeaReminder(true, IDEA_FREQUENCIES[index]))
      }
      Text(tr('累计 {0} 个以上时，晚上 8 点提醒你梳理；打开查看过的想法不再计入。', IDEA_REMINDER_THRESHOLD))
        .fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted).width('100%')
    }
  }

  // 旧 LAN 已停用：这里只说明替代方式，不提供任何发送或接收入口。
  @Builder
  private transferGroup() {
    FlashCard({ theme: this.theme, seed: 'transfer-info', space: 8 }) {
      Text(tr('局域网传输暂时停用')).fontSize(TYPE_GROUP).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
      Text(tr('旧协议存在安全风险。请使用「备份与恢复」里的导出备份或系统分享，通过你信任的方式传到另一台设备。'))
        .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).lineHeight(20).width('100%')
    }
  }

  @Builder
  private appearanceGroup() {
    this.groupLabel(tr('外观与使用'))
    FlashCard({ theme: this.theme, space: 12 }) {
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.slider_vertical_3')).fontSize(20).fontColor([iconSemantic(this.theme, 'appearance')]).width(28)
        Text(tr('主题')).fontSize(TYPE_BODY).fontColor(this.theme.themeText).layoutWeight(1)
        Text(this.themeModeLabel()).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted)
      }.width('100%').height(32)
      SegmentedControl(this.theme, [tr('浅色'), tr('深色'), tr('跟随系统')], this.themeModeIndex(),
        (index: number) => requireActions(this.actions).setThemeMode(['light', 'dark', 'system'][index]))
      this.navRow($r('sys.symbol.lightbulb'), iconSemantic(this.theme, 'logs'), tr('灵感提醒'),
        this.settings.ideaReminderEnabled ? this.frequencyLabel() : tr('已关闭'),
        () => requireActions(this.actions).openDetail('settings-idea'))
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.bolt')).fontSize(20).fontColor([iconSemantic(this.theme, 'appearance')]).width(28)
        Column({ space: 2 }) {
          Text(tr('减少动态效果')).fontSize(TYPE_BODY).fontColor(this.theme.themeText).width('100%')
          Text(tr('系统无公开查询接口，此为应用内设置')).fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted).width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.settings.reduceMotion })
          .onChange((value: boolean) => {
            requireActions(this.actions).controller.setReduceMotion(value);
          })
      }.width('100%')
      if (this.settings.notificationSettingsSupported) {
        Row({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.bell')).fontSize(20).fontColor([iconSemantic(this.theme, 'appearance')]).width(28)
          Text(tr('通知设置')).fontSize(TYPE_BODY).fontColor(this.theme.themeText).layoutWeight(1)
          Text('›').fontSize(TYPE_SECTION).fontColor(this.theme.themeMuted)
        }.width('100%').height(44)
          .accessibilityGroup(true)
          .accessibilityText(tr('通知设置'))
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
  private platformGroup() {
    this.groupLabel(tr('平台能力'))
    FlashCard({ theme: this.theme, contentPadding: 14, space: 2 }) {
      this.navRow($r('sys.symbol.bolt'), brandText(this.theme), tr('鸿蒙体验'), tr('星闪、实况窗、智慧服务与多设备'),
        () => requireActions(this.actions).openDetail('harmony'))
    }
  }

  @Builder
  private backupGroup() {
    this.groupLabel(tr('数据与安全'))
    FlashCard({ theme: this.theme, space: 2 }) {
      Text(tr('可在 Android、macOS 与 HarmonyOS 之间迁移日志、情绪和任务。备份为明文 JSON，请只保存或分享至可信位置。'))
        .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).lineHeight(19).width('100%').padding({ top: 12, bottom: 6 })
      this.actionRow($r('sys.symbol.doc_text'), iconSemantic(this.theme, 'safe'), tr('导出备份 JSON'), tr('生成 flash-backup-v2 备份文件'),
        !this.backup.fileBusy, () => requireActions(this.actions).backupController.exportBackup())
      if (requireActions(this.actions).backupController.sharedExportAvailable()) {
        this.actionRow($r('sys.symbol.folder'), iconSemantic(this.theme, 'safe'), tr('导出到下载目录'), tr('在系统文件管理中可见（下载/Flash）'),
          !this.backup.fileBusy, () => requireActions(this.actions).backupController.exportBackupToSharedDir())
      }
      if (this.settings.systemShareSupported) {
        this.actionRow($r('sys.symbol.doc_text'), iconSemantic(this.theme, 'safe'), tr('分享导出'), tr('生成备份文件并通过系统分享发送'),
          !this.backup.fileBusy, () => requireActions(this.actions).backupController.shareBackupExport())
      }
      this.actionRow($r('sys.symbol.magnifyingglass'), iconSemantic(this.theme, 'safe'), tr('标准导入并分析差异'), tr('导入前先看合并与新增明细'),
        !this.backup.fileBusy && !this.backup.busy, () => requireActions(this.actions).backupController.chooseBackup())
      this.actionRow($r('sys.symbol.clock_arrow_2_circlepath'), iconSemantic(this.theme, 'safe'), tr('恢复损坏或旧版备份'), tr('尝试修复无法直接导入的备份'),
        !this.backup.fileBusy && !this.backup.busy, () => requireActions(this.actions).backupController.chooseBackup(true))
      if (this.backup.recoveryAvailable) {
        this.actionRow($r('sys.symbol.doc_text'), dangerText(this.theme), tr('导出旧版异常原始数据'), tr('仅用于人工恢复，请勿公开分享'),
          true, () => requireActions(this.actions).backupController.exportRecoveryData())
        this.actionRow($r('sys.symbol.clock_arrow_2_circlepath'), dangerText(this.theme), tr('清除隔离区'), tr('删除本地保留的异常原始数据副本'),
          !this.backup.fileBusy, () => requireActions(this.actions).backupController.clearRecoveryData())
      }
      if (this.backup.importPhase !== ImportPhase.IDLE) {
        Column({ space: 10 }) {
          Text(tr('差异分析')).fontSize(TYPE_BODY).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          Text(this.backup.importSummary).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).lineHeight(20).width('100%')
          Row({ space: 8 }) {
            Button(tr('合并')).layoutWeight(1).height(44).fontColor(onBrandFill(this.theme)).backgroundColor(brandFill(this.theme))
              .enabled(!this.backup.busy)
              .onClick(() => requireActions(this.actions).backupController.applyBackup(true))
            Button(tr('覆盖')).layoutWeight(1).height(44).fontColor(dangerText(this.theme)).backgroundColor(this.theme.themeDanger)
              .enabled(!this.backup.busy)
              .onClick(() => requireActions(this.actions).backupController.applyBackup(false))
            Button(tr('取消')).layoutWeight(1).height(44).fontColor(this.theme.themeMuted).backgroundColor(this.theme.themeControl)
              .enabled(!this.backup.busy)
              .onClick(() => requireActions(this.actions).backupController.cancelImport())
          }.width('100%')
        }.width('100%').padding(12).backgroundColor(this.theme.themeControl).borderRadius(14)
      }
    }
  }

  @Builder
  private dangerGroup() {
    this.groupLabel(tr('危险操作'))
    FlashCard({ theme: this.theme, space: 2 }) {
      Text(tr('清空会删除本机全部日志、情绪和任务，且无法撤销，建议先导出备份。'))
        .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).lineHeight(19).width('100%').padding({ top: 12, bottom: 6 })
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.doc_text')).fontSize(20).fontColor([dangerText(this.theme)]).width(28)
        Column({ space: 2 }) {
          Text(tr('清空全部本地数据')).fontSize(TYPE_BODY).fontColor(dangerText(this.theme)).width('100%')
          Text(tr('删除后需要再次确认，不可恢复')).fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted).width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .accessibilityGroup(true)
      .accessibilityText(tr('清空全部本地数据，删除后需要再次确认，不可恢复'))
      .enabled(!this.backup.busy && !this.backup.fileBusy)
      .opacity(this.backup.busy || this.backup.fileBusy ? 0.4 : 1)
      .onClick(() => {
        if (!this.backup.busy && !this.backup.fileBusy) {
          this.feedback.destructive = { kind: DeleteKind.ALL, id: '' };
        }
      })
    }
  }

  @Builder
  private aboutGroup() {
    this.groupLabel(tr('关于 Flash'))
    Column({ space: 6 }) {
      Text('Flash Aero').fontSize(TYPE_SECTION).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText)
      Text(tr('v0.1.0 · HarmonyOS 原生版 · com.flash.app.harmonyos')).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted)
      Text(tr('让每一次闪念都有落点 · 无云端账号')).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted)
    }.width('100%').height(130).justifyContent(FlexAlign.Center).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)
      .border({ width: 0.75, color: hairlineColor(this.theme) })
      .shadow(paperShadow(this.theme))
  }

  @Builder
  private groupLabel(title: string) {
    Text(title).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%').padding({ left: 4 })
  }

  private frequencyLabel(): string {
    if (this.settings.ideaReminderFrequency === 'every3days') return tr('每 3 天');
    if (this.settings.ideaReminderFrequency === 'weekly') return tr('每周');
    return tr('每天');
  }

  private themeModeIndex(): number {
    if (this.theme.themeMode === 'dark') return 1;
    if (this.theme.themeMode === 'system') return 2;
    return 0;
  }

  private themeModeLabel(): string {
    if (this.theme.themeMode === 'dark') return tr('深色');
    if (this.theme.themeMode === 'system') return tr('跟随系统');
    return tr('浅色');
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
    .accessibilityText(`${title}，${subtitle}` + (enabled ? '' : tr('，当前不可用')))
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
