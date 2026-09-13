import { common } from '@kit.AbilityKit';
import { mediaquery } from '@kit.ArkUI';
import { Category } from '../models/Models';
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
const BRAND = '#6C5CE7';
const LIGHT_BACKGROUND = '#00FFFFFF';
const LIGHT_SURFACE = '#EFFFFFFF';
const LIGHT_TEXT = '#172033';
const LIGHT_MUTED = '#667085';
const DARK_BACKGROUND = '#FF101522';
const DARK_SURFACE = '#F2293040';
const DARK_TEXT = '#FFF3F5FA';
const DARK_MUTED = '#FFADB6C8';

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
    this.theme.themeControl = dark ? '#FF343C4D' : '#EEF1F6';
    this.theme.themeTint = dark ? '#FF343052' : '#EAF2FF';
    this.theme.themeDanger = dark ? '#FF4A292D' : '#FFF1F0';
    this.theme.themeNavigation = dark ? '#F21B2130' : '#F8FFFFFF';
    this.theme.themeGradientStart = dark ? '#FF15182D' : '#FFF4F0FF';
    this.theme.themeGradientMiddle = dark ? '#FF1D1933' : '#FFF1F8FF';
    this.theme.themeGradientEnd = dark ? '#FF14282B' : '#FFFFF3EC';
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
      HomePage({ navigation: this.navigation, theme: this.theme, home: this.home, feedback: this.feedback, actions: this.actions })
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
  private bottomNavigation() {
    Row() {
      this.tabButton(0, '⌂', '首页')
      this.tabButton(1, '⌕', '搜索')
      this.tabButton(2, '▥', '统计')
      this.tabButton(3, '○', '我的')
    }
    .width('100%')
    .height(68)
    .padding({ left: 8, right: 8, bottom: 8 })
    .backgroundColor(this.theme.themeNavigation)
    .backdropBlur(18)
  }

  @Builder
  private tabButton(index: number, emoji: string, label: string) {
    Column({ space: 2 }) {
      Text(emoji).fontSize(20)
      Text(label).fontSize(11).fontColor(this.navigation.activeTab === index ? BRAND : this.theme.themeMuted)
    }
    .layoutWeight(1)
    .height(56)
    .justifyContent(FlexAlign.Center)
    .onClick(() => this.switchTab(index))
  }

  @Builder
  private navigationRail() {
    Column({ space: 10 }) {
      Text('⚡').fontSize(30).margin({ top: 24, bottom: 18 })
      this.railButton(0, '⌂', '首页')
      this.railButton(1, '⌕', '搜索')
      this.railButton(2, '▥', '统计')
      this.railButton(3, '○', '我的')
      Blank()
      Text('Aero').fontSize(11).fontColor(this.theme.themeMuted).margin({ bottom: 20 })
    }
    .width(104)
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.theme.themeNavigation)
    .backdropBlur(18)
  }

  @Builder
  private railButton(index: number, emoji: string, label: string) {
    Column({ space: 5 }) {
      Text(emoji).fontSize(22).fontColor(this.navigation.activeTab === index ? BRAND : this.theme.themeMuted)
      Text(label).fontSize(11).fontColor(this.navigation.activeTab === index ? BRAND : this.theme.themeMuted)
    }
    .width(78)
    .height(68)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.navigation.activeTab === index ? this.theme.themeTint : Color.Transparent)
    .borderRadius(18)
    .onClick(() => this.switchTab(index))
  }

  @Builder
  private fabOption(label: string, icon: string, color: string, action: () => void) {
    Row({ space: 10 }) {
      Text(label).fontSize(13).fontColor(this.theme.themeText).padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .backgroundColor(this.theme.themeSurface).borderRadius(18)
      Button(icon, { type: ButtonType.Circle }).width(44).height(44).fontSize(20)
        .fontColor(Color.White).backgroundColor(color).onClick(action)
    }
  }

  @Builder
  private quickCreateFab() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.navigation.fabExpanded) {
        Column().width('100%').height('100%').backgroundColor('#52000000')
          .onClick(() => this.dismissFab())
      }
      Column({ space: 11 }) {
        if (this.navigation.fabExpanded) {
          Column({ space: 11 }) {
            this.fabOption('情绪', '♥', '#FF6B9D', () => {
              this.navigation.fabExpanded = false;
              this.navigation.fabProgress = 0;
              this.openDetail('emotion');
            })
            this.fabOption('灵感', '💡', '#F5B800', () => {
              this.navigation.fabExpanded = false;
              this.navigation.fabProgress = 0;
              this.logs.quickCategory = Category.IDEA;
            })
            this.fabOption('日志', '📖', '#8B5CF6', () => {
              this.navigation.fabExpanded = false;
              this.navigation.fabProgress = 0;
              this.logs.quickCategory = Category.LOG;
            })
            this.fabOption('日程', '📅', '#22B573', () => {
              this.navigation.fabExpanded = false;
              this.navigation.fabProgress = 0;
              this.openDetail('calendar');
            })
          }.opacity(this.navigation.fabProgress).translate({ y: 18 * (1 - this.navigation.fabProgress) })
        }
        Button('+', { type: ButtonType.Circle })
          .width(54).height(54).fontSize(28).fontColor(Color.White).backgroundColor(BRAND)
          .rotate({ angle: 45 * this.navigation.fabProgress })
          .onClick(() => this.toggleFab())
      }
      .alignItems(HorizontalAlign.End)
      .margin({ right: 18, bottom: this.navigation.isExpandedWindow ? 22 : 82 })
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
          this.bottomNavigation()
        }
      }

      if (this.feedback.notice !== undefined) {
        Text(this.feedback.notice?.message ?? '').fontSize(13).fontColor(Color.White).padding({ left: 18, right: 18, top: 10, bottom: 10 })
          .backgroundColor('#DD172033').borderRadius(18).margin({ bottom: 82 })
      }

      if (!this.settings.showWelcome && this.navigation.detail === '' && this.navigation.activeTab === 0) this.quickCreateFab()
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
    .linearGradient({
      angle: 145,
      colors: [[this.theme.themeGradientStart, 0.0], [this.theme.themeGradientMiddle, 0.48], [this.theme.themeGradientEnd, 1.0]]
    })
  }
}
