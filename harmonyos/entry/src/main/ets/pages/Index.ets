import { common } from '@kit.AbilityKit';
import { mediaquery } from '@kit.ArkUI';
import { Category } from '../models/Models';
import { shouldShowIdeaReminder } from '../data/IdeaReminder';
import { AppController } from '../state/AppController';
import { PageActions } from '../state/PageActions';
import { NavigationState, ThemeState, HomeState, LogsState, EmotionState, CalendarState, BackupState, SettingsState, FeedbackState, SystemEnvironment, normalizeThemeMode, resolveThemeDark, systemEnvironment, contentLayout } from '../state/FeatureStates';
import { HomePage } from '../pages/HomePage';
import { ExplorePage } from '../pages/ExplorePage';
import { StatsPage } from '../pages/StatsPage';
import { ProfilePage } from '../pages/ProfilePage';
import { EmotionPage } from '../pages/EmotionPage';
import { CalendarPage } from '../pages/CalendarPage';
import { MemoryPage } from '../pages/MemoryPage';
import { SearchPage } from '../pages/SearchPage';
import { LogFlowPage } from '../pages/LogFlowPage';
import { AppEntry, EntryKind } from '../data/AppEntry';
import { tr } from '../data/I18n';
import { HarmonyFeaturesPage } from '../pages/HarmonyFeaturesPage';
import { QuickInputDialog } from '../components/QuickInputDialog';
import { EditLogDialog } from '../components/EditLogDialog';
import { TaskEditorDialog } from '../components/TaskEditorDialog';
import { DestructiveConfirmDialog } from '../components/DestructiveConfirmDialog';
import { WelcomeOverlay } from '../components/WelcomeOverlay';
import {
  DISPLAY_FONT_NAME, FabButton, FlashDockBar, QuickCaptureBar, DetailHeader, LoadingState, ErrorState, brandText, brandFill, onBrandFill, parchmentColor, dockShadowColor,
  toastSurface, toastLevelColor, motionDuration, ELEVATED_SHADOW_RADIUS, ELEVATED_SHADOW_Y,
  MOTION_PRESS, MOTION_FADE, MOTION_PAGE, TYPE_CAPTION, TYPE_SECONDARY,
  CONTENT_MAX_WIDE, CONTENT_MAX_MEDIUM, CONTENT_MAX_CENTERED,
  PAGE_BACKGROUND_LIGHT, PAGE_BACKGROUND_DARK, CARD_SURFACE_LIGHT, CARD_SURFACE_DARK,
  TEXT_PRIMARY_LIGHT, TEXT_PRIMARY_DARK, TEXT_MUTED_LIGHT, TEXT_MUTED_DARK,
  WEAK_SURFACE_LIGHT, CONTROL_SURFACE_DARK, TINT_SURFACE_LIGHT, TINT_SURFACE_DARK,
  DANGER_SURFACE_LIGHT, DANGER_SURFACE_DARK, hairlineColor
} from '../components/CommonBuilders';
// 调色板以 CommonBuilders 令牌为准，此处仅组合主题所需的常量。
const LIGHT_BACKGROUND = PAGE_BACKGROUND_LIGHT;
const LIGHT_SURFACE = CARD_SURFACE_LIGHT;
const LIGHT_TEXT = TEXT_PRIMARY_LIGHT;
const LIGHT_MUTED = TEXT_MUTED_LIGHT;
const DARK_BACKGROUND = PAGE_BACKGROUND_DARK;
const DARK_SURFACE = CARD_SURFACE_DARK;
const DARK_TEXT = TEXT_PRIMARY_DARK;
const DARK_MUTED = TEXT_MUTED_DARK;
const LIGHT_CONTROL = WEAK_SURFACE_LIGHT;
const DARK_CONTROL = CONTROL_SURFACE_DARK;
const LIGHT_TINT = TINT_SURFACE_LIGHT;
const DARK_TINT = TINT_SURFACE_DARK;
const LIGHT_DANGER = DANGER_SURFACE_LIGHT;
const DARK_DANGER = DANGER_SURFACE_DARK;

// 浮层进出过渡统一克制在 MOTION_FADE（200ms）内；渲染时求值以尊重减少动态效果。
function overlayTransition(): TransitionEffect {
  return TransitionEffect.opacity(0)
    .combine(TransitionEffect.translate({ y: 16 }))
    .animation({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut });
}

@Entry
@Component
struct Index {
  private controller: AppController = new AppController();
  @State private navigation: NavigationState = this.controller.session.navigation;
  @State private theme: ThemeState = this.controller.session.theme;
  @State private home: HomeState = this.controller.session.home;
  @State private logs: LogsState = this.controller.session.logs;
  @State private emotion: EmotionState = this.controller.session.emotion;
  @State private calendar: CalendarState = this.controller.session.calendar;
  @State private backup: BackupState = this.controller.session.backup;
  @State private settings: SettingsState = this.controller.session.settings;
  @State private feedback: FeedbackState = this.controller.session.feedback;
  @State @Watch('onSystemEnvironmentChange') private systemEnv: SystemEnvironment = systemEnvironment;
  @StorageLink('flashPendingEntry') @Watch('onPendingEntry') private pendingEntry: AppEntry | undefined = undefined;
  private actions: PageActions = new PageActions(this.controller,
    (index: number) => this.switchTab(index), (destination: string) => this.openDetail(destination),
    (mode: string) => this.setThemeMode(mode));
  private mediumQuery?: mediaquery.MediaQueryListener;
  private expandedQuery?: mediaquery.MediaQueryListener;
  private hostContext?: common.UIAbilityContext;
  private navigationToken: number = 0;

  aboutToAppear(): void {
    const query = this.getUIContext().getMediaQuery();
    this.mediumQuery = query.matchMediaSync('(min-width: 600vp)');
    this.expandedQuery = query.matchMediaSync('(min-width: 840vp)');
    this.navigation.isMediumWindow = this.mediumQuery.matches;
    this.navigation.isExpandedWindow = this.expandedQuery.matches;
    this.mediumQuery.on('change', (result: mediaquery.MediaQueryResult) => {
      this.navigation.isMediumWindow = result.matches;
    });
    this.expandedQuery.on('change', (result: mediaquery.MediaQueryResult) => {
      this.navigation.isExpandedWindow = result.matches;
    });
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.hostContext = context;
    // 中文展示字体：随包霞鹜文楷，失败时回退系统字体，不影响使用。
    try {
      this.getUIContext().getFont().registerFont({ familyName: DISPLAY_FONT_NAME, familySrc: $rawfile('fonts/LXGWWenKai-Medium.ttf') });
    } catch (_) {
    }
    this.onSystemEnvironmentChange();
    this.controller.prepare(context, (mode: string) => this.applyThemePalette(mode)).then(() => this.onPendingEntry());
  }

  // 深链 / 通知 / 系统分享：首启欢迎页完成后才处理，避免把用户从欢迎页带走。
  private onPendingEntry(): void {
    const entry = this.pendingEntry;
    if (entry === undefined || this.feedback.startup !== 'ready' || this.settings.showWelcome) return;
    this.pendingEntry = undefined;
    switch (entry.kind) {
      case EntryKind.CAPTURE_IDEA:
        this.logs.quickCategory = Category.IDEA;
        break;
      case EntryKind.CAPTURE_LOG:
        this.logs.quickCategory = Category.LOG;
        break;
      case EntryKind.SHARED:
        this.logs.quickShared = true;
        this.logs.quickText = entry.payload;
        this.logs.quickCategory = Category.IDEA;
        break;
      case EntryKind.IDEAS:
        this.logs.filterCategory = 'idea';
        this.actions.logsController.updateSearchResults();
        this.switchTab(1);
        break;
      default:
        this.switchTab(0);
    }
  }

  aboutToDisappear(): void {
    this.navigationToken++;
    this.mediumQuery?.off('change');
    this.expandedQuery?.off('change');
    this.controller.dispose();
  }

  // Detail pages live inside this component instead of the system navigation
  // stack, so the system back gesture must be routed manually: back closes
  // the detail page first, and only exits the app from the home page.
  onBackPress(): boolean {
    if (this.logs.editingLogId !== '') {
      this.actions?.logsController.requestCloseEdit();
      return true;
    }
    // 所有浮层都先响应返回：否则返回会关掉下面的页面或直接退出应用。
    if (this.logs.quickCategory !== '') {
      this.logs.quickShared = false;
      this.logs.quickCategory = '';
      return true;
    }
    if (this.calendar.editingTaskId !== '') {
      this.actions?.calendarController.closeTaskEditor();
      return true;
    }
    if (this.feedback.destructive !== undefined) {
      this.feedback.destructive = undefined;
      return true;
    }
    if (this.navigation.detail !== '') {
      this.closeDetail();
      return true;
    }
    return false;
  }

  private retryPrepare(): void {
    const context = this.hostContext ?? (this.getUIContext().getHostContext() as common.UIAbilityContext);
    this.controller.prepare(context, (mode: string) => this.applyThemePalette(mode)).catch(() => {});
  }

  private switchTab(index: number): void {
    if (index === this.navigation.activeTab && this.navigation.detail === '') return;
    const token = ++this.navigationToken;
    this.getUIContext().animateTo({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseIn }, () => {
      this.navigation.contentOpacity = 0;
      this.navigation.contentOffset = -8;
    });
    setTimeout(() => {
      if (token !== this.navigationToken) return;
      this.navigation.activeTab = index;
      this.navigation.detail = '';
      this.navigation.contentOffset = 12;
      this.getUIContext().animateTo({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut }, () => {
        this.navigation.contentOpacity = 1;
        this.navigation.contentOffset = 0;
      });
    }, motionDuration(MOTION_PRESS));
  }

  private openDetail(destination: string): void {
    const token = ++this.navigationToken;
    this.getUIContext().animateTo({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseIn }, () => {
      this.navigation.contentOpacity = 0;
      this.navigation.contentOffset = -12;
    });
    setTimeout(() => {
      if (token !== this.navigationToken) return;
      this.navigation.detail = destination;
      this.navigation.contentOffset = 18;
      this.getUIContext().animateTo({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut }, () => {
        this.navigation.contentOpacity = 1;
        this.navigation.contentOffset = 0;
      });
    }, motionDuration(MOTION_PRESS));
  }

  private closeDetail(): void {
    const token = ++this.navigationToken;
    this.getUIContext().animateTo({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseIn }, () => {
      this.navigation.contentOpacity = 0;
      this.navigation.contentOffset = 14;
    });
    setTimeout(() => {
      if (token !== this.navigationToken) return;
      this.navigation.detail = '';
      this.navigation.contentOffset = -10;
      this.getUIContext().animateTo({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut }, () => {
        this.navigation.contentOpacity = 1;
        this.navigation.contentOffset = 0;
      });
    }, motionDuration(MOTION_PRESS));
  }

  private detailTitle(): string {
    if (this.navigation.detail === 'emotion') return tr('记录情绪');
    if (this.navigation.detail === 'calendar') return tr('日历');
    if (this.navigation.detail === 'harmony') return tr('鸿蒙体验');
    if (this.navigation.detail === 'memory') return 'Memory';
    if (this.navigation.detail === 'search') return tr('搜索');
    if (this.navigation.detail === 'logflow') return tr('日志流');
    if (this.navigation.detail === 'settings-idea') return tr('灵感提醒');
    if (this.navigation.detail === 'settings-backup') return tr('备份与恢复');
    if (this.navigation.detail === 'settings-transfer') return tr('设备间传输');
    return '';
  }

  private applyThemePalette(mode: string): void {
    const dark = resolveThemeDark(mode, this.systemEnv.systemDark);
    this.theme.themeBackground = dark ? DARK_BACKGROUND : LIGHT_BACKGROUND;
    this.theme.themeSurface = dark ? DARK_SURFACE : LIGHT_SURFACE;
    this.theme.themeText = dark ? DARK_TEXT : LIGHT_TEXT;
    this.theme.themeMuted = dark ? DARK_MUTED : LIGHT_MUTED;
    this.theme.themeControl = dark ? DARK_CONTROL : LIGHT_CONTROL;
    this.theme.themeTint = dark ? DARK_TINT : LIGHT_TINT;
    this.theme.themeDanger = dark ? DARK_DANGER : LIGHT_DANGER;
    this.theme.themeNavigation = dark ? DARK_SURFACE : LIGHT_SURFACE;
  }

  private setThemeMode(mode: string): void {
    const normalized = normalizeThemeMode(mode);
    if (normalized === this.theme.themeMode) return;
    this.theme.themeMode = normalized;
    this.getUIContext().animateTo({ duration: motionDuration(MOTION_PAGE), curve: Curve.EaseInOut }, () => {
      this.applyThemePalette(normalized);
    });
    this.controller.setThemeMode(normalized).catch((error: Error) => {
      this.controller.runtime.notify(tr('主题设置保存失败：{0}', this.controller.runtime.errorMessage(error)), 'error');
    });
  }

  private onSystemEnvironmentChange(): void {
    this.navigation.statusBarHeight = this.getUIContext().px2vp(this.systemEnv.statusBarHeightPx);
    this.navigation.navigationBarHeight = this.getUIContext().px2vp(this.systemEnv.navigationBarHeightPx);
    this.navigation.foldable = this.systemEnv.foldable;
    this.navigation.foldStatus = this.systemEnv.foldStatus;
    if (this.theme.systemDark !== this.systemEnv.systemDark) {
      this.theme.systemDark = this.systemEnv.systemDark;
      if (this.theme.themeMode === 'system') this.applyThemePalette('system');
    }
  }

  private pageLayout(): string {
    return contentLayout(this.navigation.isExpandedWindow, this.navigation.foldable, this.navigation.foldStatus);
  }

  // 半折叠态强制单栏居中限宽，避让折痕区域。
  private contentMaxWidth(): number {
    if (this.pageLayout() === 'centered') return CONTENT_MAX_CENTERED;
    return this.navigation.isMediumWindow ? CONTENT_MAX_MEDIUM : 2000;
  }

  @Builder
  private currentPage() {
    if (this.navigation.detail !== '') {
      this.detailPage()
    } else if (this.navigation.activeTab === 0) {
      HomePage({ navigation: this.navigation, theme: this.theme, home: this.home, logs: this.logs, feedback: this.feedback, actions: this.actions })
    } else if (this.navigation.activeTab === 1) {
      ExplorePage({ theme: this.theme, logs: this.logs, feedback: this.feedback, actions: this.actions })
    } else if (this.navigation.activeTab === 2) {
      EmotionPage({ theme: this.theme, emotion: this.emotion, feedback: this.feedback, actions: this.actions, asTab: true })
    } else if (this.navigation.activeTab === 3) {
      StatsPage({ navigation: this.navigation, theme: this.theme, logs: this.logs, emotion: this.emotion, calendar: this.calendar, feedback: this.feedback, actions: this.actions })
    } else {
      ProfilePage({ navigation: this.navigation, theme: this.theme, backup: this.backup, feedback: this.feedback, settings: this.settings, actions: this.actions })
    }
  }

  @Builder
  private detailPage() {
    Column() {
      DetailHeader(this.theme, this.detailTitle(), () => this.closeDetail())
      if (this.navigation.detail === 'memory') MemoryPage({ theme: this.theme, logs: this.logs, emotion: this.emotion, calendar: this.calendar, actions: this.actions })
      else if (this.navigation.detail === 'search') SearchPage({ theme: this.theme, logs: this.logs, emotion: this.emotion, calendar: this.calendar, actions: this.actions })
      else if (this.navigation.detail === 'logflow') LogFlowPage({ theme: this.theme, logs: this.logs, feedback: this.feedback, actions: this.actions })
      else if (this.navigation.detail.startsWith('settings-')) ProfilePage({ navigation: this.navigation, theme: this.theme, backup: this.backup, feedback: this.feedback, settings: this.settings, actions: this.actions, section: this.navigation.detail })
      else if (this.navigation.detail === 'calendar') CalendarPage({ theme: this.theme, calendar: this.calendar, feedback: this.feedback, actions: this.actions })
      else if (this.navigation.detail === 'harmony') HarmonyFeaturesPage({ navigation: this.navigation, theme: this.theme, settings: this.settings, actions: this.actions })
    }.width('100%').height('100%')
  }

  // Idea Reminder 角标：达到阈值才显示（对齐 Android shouldShowIdeaReminder）。
  private ideaBadge(): number {
    return shouldShowIdeaReminder(this.home.unviewedIdeaCount) ? this.home.unviewedIdeaCount : 0;
  }

  @Builder
  private dockBar() {
    Column({ space: 8 }) {
      QuickCaptureBar(this.theme, () => this.logs.quickCategory = Category.IDEA)
      FlashDockBar(this.theme, this.navigation, (index: number) => this.switchTab(index), this.ideaBadge())
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 12 + this.navigation.navigationBarHeight })
  }

  @Builder
  private navigationRail() {
    Column({ space: 10 }) {
      Image($r('app.media.icon')).width(40).height(40).borderRadius(10).margin({ top: 24, bottom: 18 })
      this.railButton(0, $r('sys.symbol.house'), $r('sys.symbol.house_fill'), tr('此刻'))
      this.railButton(1, $r('sys.symbol.doc_text'), $r('sys.symbol.doc_text_fill'), tr('记录'), this.ideaBadge())
      this.railButton(2, $r('sys.symbol.face_smiling'), $r('sys.symbol.face_smiling'), tr('情绪'))
      this.railButton(3, $r('sys.symbol.clock_arrow_2_circlepath'), $r('sys.symbol.clock_arrow_2_circlepath_fill'), tr('回顾'))
      this.railButton(4, $r('sys.symbol.gearshape'), $r('sys.symbol.gearshape_fill'), tr('设置'))
      Blank()
      Text('Flash').fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted).margin({ bottom: 20 })
    }
    .width(104)
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.theme.themeNavigation)
  }

  @Builder
  private railButton(index: number, icon: Resource, activeIcon: Resource, label: string, badge: number = 0) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 5 }) {
        SymbolGlyph(this.navigation.activeTab === index ? activeIcon : icon)
          .fontSize(22)
          .fontColor([this.navigation.activeTab === index ? brandText(this.theme) : this.theme.themeMuted])
        Text(label).fontSize(TYPE_CAPTION).fontColor(this.navigation.activeTab === index ? brandText(this.theme) : this.theme.themeMuted)
          .fontWeight(this.navigation.activeTab === index ? FontWeight.Medium : FontWeight.Regular)
      }
      .width(78)
      .height(68)
      .justifyContent(FlexAlign.Center)
      if (badge > 0) {
        Text(badge > 99 ? '99+' : `${badge}`)
          .fontSize(TYPE_CAPTION)
          .fontColor(onBrandFill(this.theme))
          .textAlign(TextAlign.Center)
          .constraintSize({ minWidth: 18 })
          .height(18)
          .padding({ left: 4, right: 4 })
          .backgroundColor(brandFill(this.theme))
          .borderRadius(9)
          .translate({ x: -6, y: 4 })
      }
    }
    .backgroundColor(this.navigation.activeTab === index ? parchmentColor(this.theme) : Color.Transparent)
    .borderRadius(18)
    .accessibilityGroup(true)
    .accessibilityText(label + (this.navigation.activeTab === index ? tr('，已选中') : '') + (badge > 0 ? tr('，{0} 条未读灵感', badge) : ''))
    .stateStyles({
      normal: { .scale({ x: 1, y: 1 }) },
      pressed: { .scale({ x: 0.92, y: 0.92 }) }
    })
    .onClick(() => this.switchTab(index))
    .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
  }

  private toastIcon(level: string): Resource {
    if (level === 'success') return $r('sys.symbol.checkmark_circle');
    if (level === 'error') return $r('sys.symbol.exclamationmark_circle');
    return $r('sys.symbol.info_circle');
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.navigation.isExpandedWindow && this.navigation.detail === '') {
        Row() {
          this.navigationRail()
          Row() {
            Stack() {
              this.currentPage()
            }
            .layoutWeight(1)
            .constraintSize({ maxWidth: CONTENT_MAX_WIDE })
            .opacity(this.navigation.contentOpacity)
            .translate({ y: this.navigation.contentOffset })
          }.layoutWeight(1).height('100%').justifyContent(FlexAlign.Center)
        }.width('100%').height('100%')
      } else {
        Row() {
          Stack() {
            this.currentPage()
          }
          .layoutWeight(1)
          .constraintSize({ maxWidth: this.contentMaxWidth() })
          .opacity(this.navigation.contentOpacity)
          .translate({ y: this.navigation.contentOffset })
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)

        if (this.navigation.detail === '') {
          this.dockBar()
        }
      }

      if (this.feedback.startup !== 'ready' && !this.settings.showWelcome) {
        Column() {
          if (this.feedback.startup === 'error') {
            ErrorState(this.theme, this.feedback.startupError, () => this.retryPrepare())
          } else {
            LoadingState(this.theme, tr('正在载入本地数据…'))
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .padding(24)
        .backgroundColor(this.theme.themeBackground)
      }

      if (this.feedback.notice !== undefined) {
        Row({ space: 8 }) {
          SymbolGlyph(this.toastIcon(this.feedback.notice?.level ?? 'info'))
            .fontSize(16)
            .fontColor([toastLevelColor(this.feedback.notice?.level ?? 'info')])
          Text(this.feedback.notice?.message ?? '').fontSize(TYPE_SECONDARY).fontColor(this.theme.themeText)
          if (this.feedback.notice?.actionLabel !== undefined) {
            Text(this.feedback.notice?.actionLabel ?? '').fontSize(TYPE_SECONDARY).fontWeight(FontWeight.Medium)
              .fontColor(brandText(this.theme)).height(44).padding({ left: 8, right: 4 })
              .onClick(() => this.feedback.notice?.action?.())
          }
        }
        .padding({ left: 18, right: 18, top: 10, bottom: 10 })
        .backgroundColor(toastSurface(this.theme))
        .borderRadius(18)
        .border({ width: 0.75, color: hairlineColor(this.theme) })
        .shadow({ radius: ELEVATED_SHADOW_RADIUS, color: dockShadowColor(this.theme), offsetY: ELEVATED_SHADOW_Y })
        .margin({ bottom: (this.navigation.isExpandedWindow ? 32 : 160) + this.navigation.navigationBarHeight })
        .transition(TransitionEffect.opacity(0).combine(TransitionEffect.translate({ y: 12 }))
          .animation({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut }))
      }

      if (!this.settings.showWelcome && this.navigation.detail === '' && this.navigation.isExpandedWindow) {
        Column() {
          FabButton(this.theme, () => this.logs.quickCategory = Category.IDEA)
        }
        .width('100%')
        .alignItems(HorizontalAlign.End)
        .padding({ right: 24, bottom: 22 + this.navigation.navigationBarHeight })
      }
      if (this.logs.quickCategory !== '') {
        QuickInputDialog({ navigation: this.navigation, theme: this.theme, logs: this.logs, actions: this.actions })
          .transition(overlayTransition())
      }
      if (this.logs.editingLogId !== '') {
        EditLogDialog({ navigation: this.navigation, theme: this.theme, logs: this.logs, actions: this.actions })
          .transition(overlayTransition())
      }
      if (this.calendar.editingTaskId !== '') {
        TaskEditorDialog({ navigation: this.navigation, theme: this.theme, calendar: this.calendar, actions: this.actions })
          .transition(overlayTransition())
      }
      if (this.feedback.destructive !== undefined) {
        DestructiveConfirmDialog({ navigation: this.navigation, theme: this.theme, feedback: this.feedback, actions: this.actions })
          .transition(overlayTransition())
      }

      if (this.settings.showWelcome) {
        WelcomeOverlay({ theme: this.theme, actions: this.actions })
          .transition(overlayTransition())
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.themeBackground)
    // 纸张颗粒：三端同一张可平铺贴图（256px 对应 128vp）。
    .backgroundImage(this.theme.isDark() ? $r('app.media.paper_grain_dark') : $r('app.media.paper_grain_light'), ImageRepeat.XY)
    .backgroundImageSize({ width: 128, height: 128 })
    .padding({ top: this.navigation.statusBarHeight })
  }
}
