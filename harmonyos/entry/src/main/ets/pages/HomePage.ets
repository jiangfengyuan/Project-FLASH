import { Category, LogItem } from '../models/Models';
import { dayString, shortDay } from '../data/DateUtils';
import { NavigationState, ThemeState, HomeState, LogsState, FeedbackState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  PageHeader, RecordCard, SegmentedControl, DOCK_CLEARANCE, RADIUS_CARD, BRAND, brandText,
  cardShadowColor, floatingSurface, hairlineColor, supportsBlurMaterial
} from '../components/CommonBuilders';

@Component
export struct HomePage {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink home: HomeState;
  @ObjectLink logs: LogsState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;

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
              colors: [['#2E6C5CE7', 0.0], ['#1F4D96FF', 0.45], ['#006C5CE7', 1.0]]
            })
          Column() {
            PageHeader(this.theme, '此刻', this.dateSubtitle())
            Row({ space: 12 }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(20).fontColor([brandText(this.theme)])
              Text('搜索或筛选记录').fontSize(14).fontColor(this.theme.themeMuted).layoutWeight(1)
              SymbolGlyph($r('sys.symbol.slider_vertical_3')).fontSize(18).fontColor([brandText(this.theme)])
            }
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })
            .backgroundColor(floatingSurface(this.theme))
            .backgroundBlurStyle(supportsBlurMaterial() ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
            .borderRadius(26)
            .border({ width: 0.5, color: hairlineColor(this.theme) })
            .stateStyles({
              normal: { .opacity(1) },
              pressed: { .opacity(0.85) }
            })
            .accessibilityGroup(true)
            .accessibilityText('搜索或筛选记录')
            .onClick(() => requireActions(this.actions).switchTab(1))
            .animation({ duration: 180, curve: Curve.EaseOut })
            .margin({ left: 20, right: 20 })
          }.width('100%')
        }

        Column({ space: 12 }) {
          this.todayCard()
          this.captureCard()

          if (this.home.recentLogs.length > 0) {
            Column({ space: 12 }) {
              Row() {
                Text('最近闪念').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
                Blank()
                Text('全部').fontSize(12).fontColor(brandText(this.theme))
                  .height(44).padding({ left: 12 })
                  .onClick(() => requireActions(this.actions).switchTab(1))
              }.width('100%')
              ForEach(this.home.recentLogs, (item: LogItem) => {
                RecordCard({ theme: this.theme, feedback: this.feedback, actions: requireActions(this.actions), item: item })
              }, (item: LogItem) => item.id)
            }.width('100%')
          } else {
            Column({ space: 12 }) {
              Text('今天还没有记录。').fontSize(14).fontColor(this.theme.themeMuted)
              Button('记下第一个念头').height(44).backgroundColor(BRAND)
                .onClick(() => this.logs.quickCategory = Category.LOG)
            }
            .width('100%')
            .padding(24)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.theme.themeSurface)
            .borderRadius(RADIUS_CARD)
            .border({ width: 0.5, color: hairlineColor(this.theme) })
            .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })
          }
        }.padding({ left: 20, right: 20, top: 12, bottom: DOCK_CLEARANCE }).width('100%')
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
  private todayCard() {
    Column({ space: 12 }) {
      Row() {
        Text('今天的片段').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
        Blank()
        Text(shortDay(dayString())).fontSize(11).fontColor(brandText(this.theme))
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
          .backgroundColor(this.theme.themeTint).borderRadius(12)
      }.width('100%')

      if (!this.hasTodayData()) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.lightbulb')).fontSize(18).fontColor([brandText(this.theme)])
          Text('今天可以从一个念头开始').fontSize(13).fontColor(this.theme.themeMuted)
        }.width('100%')
      } else {
        Row({ space: 16 }) {
          this.todayStat($r('sys.symbol.doc_text'), '记录', `${this.home.todayLogCount + this.home.todayIdeaCount}`)
          this.todayStat($r('sys.symbol.checkmark_circle'), '待办', `${this.home.todayTaskCount}`)
        }.width('100%')
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.face_smiling')).fontSize(16).fontColor(['#E35A90'])
          Text(`情绪 ${this.home.todayEmotionCount}`).fontSize(12).fontColor(this.theme.themeText)
          Blank()
          SymbolGlyph($r('sys.symbol.checkmark_circle')).fontSize(16).fontColor(['#1E9E62'])
          Text(`已完成任务 ${this.home.todayTaskDoneCount}/${this.home.todayTaskCount}`)
            .fontSize(12).fontColor(this.theme.themeText)
        }
        .width('100%')
        .padding({ left: 12, right: 12 })
        .height(44)
        .backgroundColor(this.theme.themeControl)
        .borderRadius(16)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.theme.themeSurface)
    .borderRadius(RADIUS_CARD)
    .border({ width: 0.5, color: hairlineColor(this.theme) })
    .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })
  }

  @Builder
  private todayStat(icon: Resource, label: string, value: string) {
    Row({ space: 8 }) {
      SymbolGlyph(icon).fontSize(16).fontColor([brandText(this.theme)])
      Text(label).fontSize(12).fontColor(this.theme.themeMuted)
      Text(value).fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText)
    }
  }

  @Builder
  private captureCard() {
    Column({ space: 12 }) {
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
    .width('100%')
    .padding(16)
    .backgroundColor(this.theme.themeSurface)
    .borderRadius(RADIUS_CARD)
    .border({ width: 0.5, color: hairlineColor(this.theme) })
    .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })
  }

  build() {
    this.homePage()
  }
}
