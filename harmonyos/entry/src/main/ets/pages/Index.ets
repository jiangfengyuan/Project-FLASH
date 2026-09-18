import { common } from '@kit.AbilityKit';
import { mediaquery } from '@kit.ArkUI';
import { Category } from '../models/Models';
import { dayString } from '../data/DateUtils';
import { AppController } from '../state/AppController';
import { PageActions } from '../state/PageActions';
import { NavigationState, ThemeState, HomeState, LogsState, EmotionState, CalendarState, BackupState, SettingsState, FeedbackState } from '../state/FeatureStates';
import { HomePage } from '../pages/HomePage';
import { ExplorePage } from '../pages/ExplorePage';
import { StatsPage } from '../pages/StatsPage';
import { ProfilePage } from '../pages/ProfilePage';
import { EmotionPage } from '../pages/EmotionPage';
import { CalendarPage } from '../pages/CalendarPage';
import { LogManagerPage } from '../pages/LogManagerPage';
import { SettingsPage } from '../pages/SettingsPage';
import { HarmonyFeaturesPage } from '../pages/HarmonyFeaturesPage';
import { QuickInputDialog } from '../components/QuickInputDialog';
import { EditLogDialog } from '../components/EditLogDialog';
import { TaskEditorDialog } from '../components/TaskEditorDialog';
import { DestructiveConfirmDialog } from '../components/DestructiveConfirmDialog';
import { WelcomeOverlay } from '../components/WelcomeOverlay';
import {
  BRAND, FabButton, FabOption, FlashDockBar, FAB_SIZE,
  PAGE_BACKGROUND_LIGHT, PAGE_BACKGROUND_DARK, CARD_SURFACE_LIGHT, CARD_SURFACE_DARK,
  TEXT_PRIMARY_LIGHT, TEXT_PRIMARY_DARK, TEXT_MUTED_LIGHT, TEXT_MUTED_DARK,
  WEAK_SURFACE_LIGHT
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
// 深色卡片与弱表面统一为 WEAK_SURFACE_DARK 后，控件层与品牌弱高亮需抬升以保持层次可读。
const LIGHT_CONTROL = WEAK_SURFACE_LIGHT;
const DARK_CONTROL = '#FF484C72';
const LIGHT_TINT = '#FFEAF2FF';
const DARK_TINT = '#FF4A4478';
const LIGHT_DANGER = '#FFFFF1F0';
const DARK_DANGER = '#FF4A292D';

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
  private actions: PageActions = new PageActions(this.controller,
    (index: number) => this.switchTab(index), (destination: string) => this.openDetail(destination),
    (mode: string) => this.setThemeMode(mode));
  private mediumQuery?: mediaquery.MediaQueryListener;
  private expandedQuery?: mediaquery.MediaQueryListener;
  private navigationToken: number = 0;
  private fabToken: number = 0;

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
    this.controller.prepare(context, (mode: string) => this.applyThemePalette(mode === 'dark'));
  }

  aboutToDisappear(): void {
    this.navigationToken++;
    this.fabToken++;
    this.mediumQuery?.off('change');
    this.expandedQuery?.off('change');
    this.controller.dispose();
  }

  // Detail pages live inside this component instead of the system navigation
  // stack, so the system back gesture must be routed manually: back closes
  // the detail page first, and only exits the app from the home page.
  onBackPress(): boolean {
    if (this.navigation.fabExpanded) {
      this.dismissFab();
      return true;
    }
    if (this.navigation.detail !== '') {
      this.closeDetail();
      return true;
    }
    return false;
  }

  private switchTab(index: number): void {
    if (index === this.navigation.activeTab && this.navigation.detail === '') return;
    const token = ++this.navigationToken;
    this.fabToken++;
    this.navigation.fabExpanded = false;
    this.navigation.fabProgress = 0;
    this.getUIContext().animateTo({ duration: 110, curve: Curve.EaseIn }, () => {
      this.navigation.contentOpacity = 0;
      this.navigation.contentOffset = -8;
    });
    setTimeout(() => {
      if (token !== this.navigationToken) return;
      this.navigation.activeTab = index;
      this.navigation.detail = '';
      this.navigation.contentOffset = 12;
      this.getUIContext().animateTo({ duration: 230, curve: Curve.EaseOut }, () => {
        this.navigation.contentOpacity = 1;
        this.navigation.contentOffset = 0;
      });
    }, 110);
  }

  private openDetail(destination: string): void {
    const token = ++this.navigationToken;
    this.fabToken++;
    this.navigation.fabExpanded = false;
    this.navigation.fabProgress = 0;
    this.getUIContext().animateTo({ duration: 120, curve: Curve.EaseIn }, () => {
      this.navigation.contentOpacity = 0;
      this.navigation.contentOffset = -12;
    });
    setTimeout(() => {
      if (token !== this.navigationToken) return;
      this.navigation.detail = destination;
      this.navigation.contentOffset = 18;
      this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
        this.navigation.contentOpacity = 1;
        this.navigation.contentOffset = 0;
      });
    }, 120);
  }

  private closeDetail(): void {
    const token = ++this.navigationToken;
    this.getUIContext().animateTo({ duration: 110, curve: Curve.EaseIn }, () => {
      this.navigation.contentOpacity = 0;
      this.navigation.contentOffset = 14;
    });
    setTimeout(() => {
      if (token !== this.navigationToken) return;
      this.navigation.detail = '';
      this.navigation.contentOffset = -10;
      this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.navigation.contentOpacity = 1;
        this.navigation.contentOffset = 0;
      });
    }, 110);
  }

  private toggleFab(): void {
    const token = ++this.fabToken;
    if (!this.navigation.fabExpanded) {
      this.navigation.fabExpanded = true;
      this.navigation.fabProgress = 0;
      this.getUIContext().animateTo({ duration: 210, curve: Curve.EaseOut }, () => this.navigation.fabProgress = 1);
    } else {
      this.getUIContext().animateTo({ duration: 160, curve: Curve.EaseIn }, () => this.navigation.fabProgress = 0);
      setTimeout(() => {
        if (token === this.fabToken) this.navigation.fabExpanded = false;
      }, 160);
    }
  }

  private dismissFab(): void {
    if (!this.navigation.fabExpanded) return;
    this.toggleFab();
  }

  private detailTitle(): string {
    if (this.navigation.detail === 'emotion') return '记录情绪';
    if (this.navigation.detail === 'calendar') return '日历';
    if (this.navigation.detail === 'logs') return '记录管理';
    if (this.navigation.detail === 'harmony') return '鸿蒙体验';
    return '设置与备份';
  }

  private applyThemePalette(dark: boolean): void {
    this.theme.themeBackground = dark ? DARK_BACKGROUND : LIGHT_BACKGROUND;
    this.theme.themeSurface = dark ? DARK_SURFACE : LIGHT_SURFACE;
    this.theme.themeText = dark ? DARK_TEXT : LIGHT_TEXT;
    this.theme.themeMuted = dark ? DARK_MUTED : LIGHT_MUTED;
    this.theme.themeControl = dark ? DARK_CONTROL : LIGHT_CONTROL;
    this.theme.themeTint = dark ? DARK_TINT : LIGHT_TINT;
    this.theme.themeDanger = dark ? DARK_DANGER : LIGHT_DANGER;
    this.theme.themeNavigation = dark ? DARK_SURFACE : LIGHT_SURFACE;
    this.theme.themeGradientStart = dark ? DARK_BACKGROUND : LIGHT_BACKGROUND;
    this.theme.themeGradientMiddle = dark ? DARK_BACKGROUND : LIGHT_BACKGROUND;
    this.theme.themeGradientEnd = dark ? DARK_BACKGROUND : LIGHT_BACKGROUND;
  }

  private setThemeMode(mode: string): void {
    if (mode === this.theme.themeMode) return;
    this.theme.themeMode = mode;
    this.getUIContext().animateTo({ duration: 320, curve: Curve.EaseInOut }, () => {
      this.applyThemePalette(mode === 'dark');
    });
    this.controller.saveTheme(mode).catch((error: Error) => {
      this.controller.runtime.notify(`主题设置保存失败：${this.controller.runtime.errorMessage(error)}`);
    });
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
      StatsPage({ theme: this.theme, logs: this.logs, emotion: this.emotion, actions: this.actions })
    } else {
      ProfilePage({ theme: this.theme, actions: this.actions })
    }
  }

  @Builder
  private detailPage() {
    Column() {
      Row({ space: 10 }) {
        Button('‹ 返回', { type: ButtonType.Normal }).fontColor(BRAND).backgroundColor(Color.Transparent)
          .onClick(() => this.closeDetail())
        Text(this.detailTitle()).fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText)
      }.width('100%').height(60).padding({ left: 8, right: 16 })
      if (this.navigation.detail === 'emotion') EmotionPage({ theme: this.theme, emotion: this.emotion, feedback: this.feedback, actions: this.actions })
      else if (this.navigation.detail === 'calendar') CalendarPage({ theme: this.theme, calendar: this.calendar, feedback: this.feedback, actions: this.actions })
      else if (this.navigation.detail === 'logs') LogManagerPage({ theme: this.theme, logs: this.logs, feedback: this.feedback, actions: this.actions })
      else if (this.navigation.detail === 'harmony') HarmonyFeaturesPage({ navigation: this.navigation, theme: this.theme, settings: this.settings, actions: this.actions })
      else SettingsPage({ theme: this.theme, backup: this.backup, feedback: this.feedback, actions: this.actions })
    }.width('100%').height('100%').backgroundColor(this.theme.themeBackground)
  }

  @Builder
  private dockBar() {
    Row({ space: 12 }) {
      FlashDockBar(this.theme, this.navigation, (index: number) => this.switchTab(index))
      FabButton(this.navigation, () => this.toggleFab())
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 16 })
  }

  @Builder
  private navigationRail() {
    Column({ space: 10 }) {
      Image($r('app.media.icon')).width(40).height(40).borderRadius(10).margin({ top: 24, bottom: 18 })
      this.railButton(0, $r('sys.symbol.house'), $r('sys.symbol.house_fill'), '此刻')
      this.railButton(1, $r('sys.symbol.doc_text'), $r('sys.symbol.doc_text_fill'), '记录')
      this.railButton(2, $r('sys.symbol.clock_arrow_2_circlepath'), $r('sys.symbol.clock_arrow_2_circlepath_fill'), '回顾')
      this.railButton(3, $r('sys.symbol.gearshape'), $r('sys.symbol.gearshape_fill'), '设置')
      Blank()
      Text('Flash').fontSize(11).fontColor(this.theme.themeMuted).margin({ bottom: 20 })
    }
    .width(104)
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.theme.themeNavigation)
  }

  @Builder
  private railButton(index: number, icon: Resource, activeIcon: Resource, label: string) {
    Column({ space: 5 }) {
      SymbolGlyph(this.navigation.activeTab === index ? activeIcon : icon)
        .fontSize(22)
        .fontColor([this.navigation.activeTab === index ? BRAND : this.theme.themeMuted])
      Text(label).fontSize(11).fontColor(this.navigation.activeTab === index ? BRAND : this.theme.themeMuted)
        .fontWeight(this.navigation.activeTab === index ? FontWeight.Medium : FontWeight.Regular)
    }
    .width(78)
    .height(68)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.navigation.activeTab === index ? this.theme.themeTint : Color.Transparent)
    .borderRadius(18)
    .onClick(() => this.switchTab(index))
    .animation({ duration: 200, curve: Curve.EaseOut })
  }

  private fabBottomGap(): number {
    return (this.navigation.isExpandedWindow ? 22 : 16) + FAB_SIZE + 12;
  }

  @Builder
  private fabOverlay() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.navigation.fabExpanded) {
        Column().width('100%').height('100%').backgroundColor('#52000000')
          .opacity(this.navigation.fabProgress)
          .onClick(() => this.dismissFab())
        Column({ space: 12 }) {
          FabOption(this.theme, '记录', $r('sys.symbol.square_and_pencil'), '#8B5CF6', () => {
            this.navigation.fabExpanded = false;
            this.navigation.fabProgress = 0;
            this.logs.quickCategory = Category.LOG;
          })
          FabOption(this.theme, '灵感', $r('sys.symbol.lightbulb'), '#F5B800', () => {
            this.navigation.fabExpanded = false;
            this.navigation.fabProgress = 0;
            this.logs.quickCategory = Category.IDEA;
          })
          FabOption(this.theme, '情绪', $r('sys.symbol.face_smiling'), '#FF6B9D', () => {
            this.navigation.fabExpanded = false;
            this.navigation.fabProgress = 0;
            this.openDetail('emotion');
          })
          FabOption(this.theme, '任务', $r('sys.symbol.checkmark_circle'), '#22B573', () => {
            this.navigation.fabExpanded = false;
            this.navigation.fabProgress = 0;
            this.actions.calendarController.openTaskEditor(undefined, dayString());
          })
        }
        .alignItems(HorizontalAlign.End)
        .opacity(this.navigation.fabProgress)
        .translate({ y: 18 * (1 - this.navigation.fabProgress) })
        .margin({ right: this.navigation.isExpandedWindow ? 24 : 20, bottom: this.fabBottomGap() })
      }
      if (this.navigation.isExpandedWindow) {
        Column() {
          FabButton(this.navigation, () => this.toggleFab())
        }.margin({ right: 24, bottom: 22 })
      }
    }.width('100%').height('100%')
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
            .constraintSize({ maxWidth: 980 })
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
          .constraintSize({ maxWidth: this.navigation.isMediumWindow ? 760 : 2000 })
          .opacity(this.navigation.contentOpacity)
          .translate({ y: this.navigation.contentOffset })
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)

        if (this.navigation.detail === '') {
          this.dockBar()
        }
      }

      if (this.feedback.notice !== undefined) {
        Text(this.feedback.notice?.message ?? '').fontSize(13).fontColor(Color.White).padding({ left: 18, right: 18, top: 10, bottom: 10 })
          .backgroundColor('#DD172033').borderRadius(18).margin({ bottom: this.navigation.isExpandedWindow ? 32 : 96 })
      }

      if (!this.settings.showWelcome && this.navigation.detail === '') this.fabOverlay()
      if (this.logs.quickCategory !== '') QuickInputDialog({ navigation: this.navigation, theme: this.theme, logs: this.logs, actions: this.actions })
      if (this.logs.editingLogId !== '') EditLogDialog({ navigation: this.navigation, theme: this.theme, logs: this.logs, actions: this.actions })
      if (this.calendar.editingTaskId !== '') TaskEditorDialog({ navigation: this.navigation, theme: this.theme, calendar: this.calendar, actions: this.actions })
      if (this.feedback.destructive !== undefined) {
        DestructiveConfirmDialog({ navigation: this.navigation, theme: this.theme, feedback: this.feedback, actions: this.actions })
      }

      if (this.settings.showWelcome) WelcomeOverlay({ theme: this.theme, actions: this.actions })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.themeBackground)
  }
}
