import { Category, LogItem } from '../models/Models';
import { dayString, shortDay } from '../data/DateUtils';
import { NavigationState, ThemeState, HomeState, LogsState, FeedbackState, contentLayout } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  PageHeader, RecordCard, SegmentedControl, FlashCard, EmptyState, DOCK_CLEARANCE, BRAND, brandText,
  floatingSurface, hairlineColor, supportsBlurMaterial, iconSemantic, motionDuration, MOTION_FADE,
  TYPE_GROUP, TYPE_BODY, TYPE_SECONDARY, TYPE_CAPTION,
  HOME_HALO_TOP, HOME_HALO_MID, HOME_HALO_OUTER
} from '../components/CommonBuilders';

@Component
export struct HomePage {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink home: HomeState;
  @ObjectLink logs: LogsState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;

  // 840vp 或折叠屏展开态：快速记录卡与最近闪念左右双栏。
  private isDual(): boolean {
    return contentLayout(this.navigation.isExpandedWindow, this.navigation.foldable, this.navigation.foldStatus) === 'dual';
  }

  @Builder
  private homePage() {
    Scroll() {
      Column() {
        Stack({ alignContent: Alignment.Top }) {
          // 仅此页允许的极克制蓝紫光晕，向下消散为页面底色。
          Column()
            .width('100%')
            .height(190)
            .linearGradient({
              angle: 180,
              colors: [[HOME_HALO_TOP, 0.0], [HOME_HALO_MID, 0.45], [HOME_HALO_OUTER, 1.0]]
            })
          Column() {
            PageHeader(this.theme, '此刻', this.dateSubtitle())
            Row({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(20).fontColor([brandText(this.theme)])
              Text('搜索或筛选记录').fontSize(TYPE_BODY).fontColor(this.theme.themeMuted).layoutWeight(1)
              SymbolGlyph($r('sys.symbol.slider_vertical_3')).fontSize(18).fontColor([brandText(this.theme)])
            }
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })
            .backgroundColor(floatingSurface(this.theme))
            .backgroundBlurStyle(supportsBlurMaterial() ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
            .borderRadius(26)
            .border({ width: 0.5, color: hairlineColor(this.theme) })
            .hoverEffect(HoverEffect.Highlight)
            .stateStyles({
              normal: { .opacity(1) },
              pressed: { .opacity(0.85) }
            })
            .accessibilityGroup(true)
            .accessibilityText('搜索或筛选记录')
            .onClick(() => requireActions(this.actions).switchTab(1))
            .animation({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut })
            .margin({ left: 20, right: 20 })
          }.width('100%')
        }

        if (this.isDual()) {
          Row({ space: 12 }) {
            Column({ space: 12 }) {
              this.todayCard()
              this.captureCard()
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Column({ space: 12 }) {
              this.recentSection()
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }
          .alignItems(VerticalAlign.Top)
          .padding({ left: 20, right: 20, top: 12, bottom: DOCK_CLEARANCE })
          .width('100%')
        } else {
          Column({ space: 12 }) {
            this.todayCard()
            this.captureCard()
            this.recentSection()
          }.padding({ left: 20, right: 20, top: 12, bottom: DOCK_CLEARANCE }).width('100%')
        }
      }.width('100%')
    }.width('100%').height('100%').backgroundColor(this.theme.themeBackground)
  }

  private dateSubtitle(): string {
    const now = new Date();
    const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `${shortDay(dayString(now))} · ${weekdays[now.getDay()]}`;
  }

  private hasTodayData(): boolean {
    return this.home.todayLogCount + this.home.todayIdeaCount +
      this.home.todayEmotionCount + this.home.todayTaskCount > 0;
  }

  @Builder
  private recentSection() {
    if (this.home.recentLogs.length > 0) {
      Column({ space: 12 }) {
        Row() {
          Text('最近闪念').fontSize(TYPE_GROUP).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
          Blank()
          Text('全部').fontSize(TYPE_SECONDARY).fontColor(brandText(this.theme))
            .height(44).padding({ left: 12 })
            .stateStyles({
              normal: { .opacity(1) },
              pressed: { .opacity(0.6) }
            })
            .onClick(() => requireActions(this.actions).switchTab(1))
            .animation({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut })
        }.width('100%')
        ForEach(this.home.recentLogs, (item: LogItem) => {
          RecordCard({ theme: this.theme, feedback: this.feedback, actions: requireActions(this.actions), item: item })
        }, (item: LogItem) => item.id)
      }.width('100%')
    } else {
      EmptyState(this.theme, '✨', '今天还没有记录。', '记下第一个念头', () => this.logs.quickCategory = Category.LOG)
    }
  }

  @Builder
  private todayCard() {
    FlashCard({ theme: this.theme, space: 12 }) {
      Row() {
        Text('今天的片段').fontSize(TYPE_GROUP).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
        Blank()
        Text(shortDay(dayString())).fontSize(TYPE_CAPTION).fontColor(brandText(this.theme))
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
          .backgroundColor(this.theme.themeTint).borderRadius(12)
      }.width('100%')

      if (!this.hasTodayData()) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.lightbulb')).fontSize(18).fontColor([brandText(this.theme)])
          Text('今天可以从一个念头开始').fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted)
        }.width('100%')
      } else {
        Row({ space: 16 }) {
          this.todayStat($r('sys.symbol.doc_text'), '记录', `${this.home.todayLogCount + this.home.todayIdeaCount}`)
          this.todayStat($r('sys.symbol.checkmark_circle'), '待办', `${this.home.todayTaskCount}`)
        }.width('100%')
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.face_smiling')).fontSize(16).fontColor([iconSemantic(this.theme, 'emotion')])
          Text(`情绪 ${this.home.todayEmotionCount}`).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeText)
          Blank()
          SymbolGlyph($r('sys.symbol.checkmark_circle')).fontSize(16).fontColor([iconSemantic(this.theme, 'task')])
          Text(`已完成任务 ${this.home.todayTaskDoneCount}/${this.home.todayTaskCount}`)
            .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeText)
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .height(44)
        .backgroundColor(this.theme.themeControl)
        .borderRadius(16)
      }
    }
  }

  @Builder
  private todayStat(icon: Resource, label: string, value: string) {
    Row({ space: 8 }) {
      SymbolGlyph(icon).fontSize(16).fontColor([brandText(this.theme)])
      Text(label).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted)
      Text(value).fontSize(TYPE_GROUP).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText)
    }
  }

  @Builder
  private captureCard() {
    FlashCard({ theme: this.theme, space: 12 }) {
      TextArea({ placeholder: '写下刚刚闪过的念头……', text: this.logs.captureText })
        .height(76).maxLength(10000).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
        .backgroundColor(this.theme.themeControl).borderRadius(14)
        .onChange((value: string) => this.logs.captureText = value.slice(0, 10000))
      SegmentedControl(this.theme, ['日志', '灵感'], this.logs.captureCategory === Category.IDEA ? 1 : 0,
        (index: number) => this.logs.captureCategory = index === 1 ? Category.IDEA : Category.LOG)
      Button('保存')
        .width('100%').height(44).backgroundColor(BRAND)
        .enabled(this.logs.captureText.trim().length > 0)
        .onClick(() => requireActions(this.actions).logsController.saveCapture())
    }
  }

  build() {
    this.homePage()
  }
}
