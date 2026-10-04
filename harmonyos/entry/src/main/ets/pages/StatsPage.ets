import { ActivityChart } from '../components/ActivityChart';
import { CalendarPage } from './CalendarPage';
import { ReviewComparison, EmotionDistribution, SubEmotionSlice } from '../data/ReviewWindow';
import { shortDay } from '../data/DateUtils';
import { Category, LogItem, EmotionRecord } from '../models/Models';
import { NavigationState, ThemeState, LogsState, EmotionState, CalendarState, FeedbackState, contentLayout } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import { StatsController } from '../state/StatsController';
import {
  PageHeader, DOCK_CLEARANCE, FilterChip, FlashCard, brandText, hairlineColor, statLineColor,
  TYPE_TITLE, TYPE_GROUP, TYPE_BODY, TYPE_SECONDARY
} from '../components/CommonBuilders';

@Component
export struct StatsPage {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink logs: LogsState;
  @ObjectLink emotion: EmotionState;
  @ObjectLink calendar: CalendarState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;
  @State showCalendar: boolean = false;
  @State window: string = 'week';

  private stats(): StatsController { return requireActions(this.actions).statsController; }
  private days(): string[] { return this.stats().days(this.window); }
  private periodLogs(): LogItem[] { return this.stats().periodLogs(this.window); }
  private periodEmotions(): EmotionRecord[] { return this.stats().periodEmotions(this.window); }
  private activeDays(): number { return this.stats().activeDays(this.window); }
  private periodAverage(): string { return this.stats().periodAverage(this.window); }
  private comparison(): ReviewComparison { return this.stats().comparison(this.window); }
  private distribution(): EmotionDistribution { return this.stats().distribution(this.window); }

  // 840vp 或折叠屏展开态：总览与图表在左，趋势与分布在右。
  private isDual(): boolean {
    return contentLayout(this.navigation.isExpandedWindow, this.navigation.foldable, this.navigation.foldStatus) === 'dual';
  }

  @Builder
  private statsPage() {
    Scroll() {
      Column({ space: 14 }) {
        Scroll() {
          Row({ space: 8 }) {
            FilterChip(this.theme, '本周', this.window === 'week', () => this.window = 'week')
            FilterChip(this.theme, '本月', this.window === 'month', () => this.window = 'month')
            FilterChip(this.theme, '近30天', this.window === '30', () => this.window = '30')
            FilterChip(this.theme, '近90天', this.window === '90', () => this.window = '90')
          }
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
        if (this.isDual()) {
          Row({ space: 14 }) {
            Column({ space: 14 }) {
              this.comparisonCard()
              ActivityChart({ theme: this.theme, days: this.stats().activity(this.window) })
              Row({ space: 10 }) {
                this.metric(`${this.periodLogs().length}`, '范围内记录', this.theme.themeTint)
                this.metric(`${this.periodAverage()}`, '平均情绪', this.theme.themeTint)
              }.width('100%')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Column({ space: 14 }) {
              this.trendCard()
              this.distributionCard()
              this.compositionCard()
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          }.alignItems(VerticalAlign.Top).width('100%')
        } else {
          this.comparisonCard()
          ActivityChart({ theme: this.theme, days: this.stats().activity(this.window) })
          Row({ space: 10 }) {
            this.metric(`${this.periodLogs().length}`, '范围内记录', this.theme.themeTint)
            this.metric(`${this.periodAverage()}`, '平均情绪', this.theme.themeTint)
          }.width('100%')
          this.trendCard()
          this.distributionCard()
          this.compositionCard()
        }
      }.width('100%').padding({ left: 20, right: 20, bottom: DOCK_CLEARANCE })
    }.width('100%').layoutWeight(1).backgroundColor(this.theme.themeBackground)
  }

  @Builder
  private comparisonCard() {
    FlashCard({ theme: this.theme, space: 8 }) {
      Text(this.comparison().conclusion)
        .fontSize(TYPE_GROUP).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
      Text(`${this.days()[0]} — ${this.days()[this.days().length - 1]}`)
        .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
      if (this.comparison().insufficient) {
        Text(`这段时间有 ${this.periodLogs().length} 条记录 · ${this.periodEmotions().length} 次情绪`)
          .fontSize(TYPE_BODY).fontColor(this.theme.themeText).width('100%')
      } else {
        Text(`${this.comparison().currentLabel} ${this.comparison().currentCount} 条 · ${this.comparison().previousLabel} ${this.comparison().previousCount} 条`)
          .fontSize(TYPE_BODY).fontColor(this.theme.themeText).width('100%')
        Text(`活跃 ${this.activeDays()} 天 · 平均情绪 ${this.periodAverage()}`)
          .fontSize(TYPE_BODY).fontColor(this.theme.themeText).width('100%')
      }
    }
  }

  @Builder
  private trendCard() {
    FlashCard({ theme: this.theme, space: 12 }) {
      Text('情绪趋势 · 日均值').fontSize(TYPE_GROUP).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
      Text('-3 至 +3，0 为中性；— 表示当日未记录')
        .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
      if (this.periodEmotions().length === 0) {
        Text('时间范围内暂无情绪记录').fontSize(TYPE_BODY).fontColor(this.theme.themeMuted)
      }
      ForEach(this.days(), (day: string) => {
        Row({ space: 10 }) {
          Text(shortDay(day)).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width(58)
          Stack({ alignContent: Alignment.Start }) {
            Row().height(10).width('100%').backgroundColor(this.theme.themeControl).borderRadius(5)
            Row().height(10).width(`${requireActions(this.actions).emotionController.dayBar(day)}%`).backgroundColor(brandText(this.theme)).borderRadius(5)
          }.layoutWeight(1).height(12)
          Text(requireActions(this.actions).emotionController.dayEmotionLabel(day)).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeText).width(34)
        }.width('100%')
      }, (day: string) => day)
    }
  }

  @Builder
  private distributionCard() {
    FlashCard({ theme: this.theme, space: 12 }) {
      Text('情绪分布').fontSize(TYPE_GROUP).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
      Text('时间范围内开心 / 中性 / 不开心的次数，条形长度按比例')
        .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
      if (this.distribution().total === 0) {
        Text('时间范围内暂无情绪记录，分布会慢慢成形').fontSize(TYPE_BODY).fontColor(this.theme.themeMuted).width('100%')
      } else {
        this.distributionRow('开心', this.distribution().positive, this.distribution().total)
        this.distributionRow('中性', this.distribution().neutral, this.distribution().total)
        this.distributionRow('不开心', this.distribution().negative, this.distribution().total)
        if (this.distribution().subEmotions.length > 0) {
          Text('不开心时的具体感受').fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
          ForEach(this.distribution().subEmotions, (slice: SubEmotionSlice) => {
            this.distributionRow(slice.name, slice.count, this.distribution().negative)
          }, (slice: SubEmotionSlice) => slice.key)
        }
      }
    }
  }

  @Builder
  private compositionCard() {
    FlashCard({ theme: this.theme, space: 10 }) {
      Text('累计构成 · 全部时间').fontSize(TYPE_GROUP).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
      this.statLine('日志', this.logs.logs.filter((item: LogItem) => item.category === Category.LOG).length, statLineColor(this.theme, 'log'))
      this.statLine('灵感', this.logs.logs.filter((item: LogItem) => item.category === Category.IDEA).length, statLineColor(this.theme, 'idea'))
      this.statLine('情绪', this.emotion.emotions.length, statLineColor(this.theme, 'emotion'))
    }
  }

  @Builder
  private metric(value: string, label: string, background: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(TYPE_TITLE).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText)
      Text(label).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted)
    }.layoutWeight(1).height(88).justifyContent(FlexAlign.Center).backgroundColor(background).borderRadius(18)
      .border({ width: 0.5, color: hairlineColor(this.theme) })
  }

  @Builder
  private statLine(label: string, value: number, color: string) {
    Row({ space: 10 }) {
      Row().width(10).height(10).borderRadius(5).backgroundColor(color)
      Text(label).fontSize(TYPE_BODY).fontColor(this.theme.themeText).layoutWeight(1)
      Text(`${value}`).fontSize(TYPE_BODY).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
    }.width('100%')
  }

  @Builder
  private distributionRow(label: string, count: number, total: number) {
    Row({ space: 10 }) {
      Text(label).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width(58)
      Stack({ alignContent: Alignment.Start }) {
        Row().height(10).width('100%').backgroundColor(this.theme.themeControl).borderRadius(5)
        if (count > 0 && total > 0) {
          Row().height(10).width(`${Math.max(4, Math.round(100 * count / total))}%`).backgroundColor(brandText(this.theme)).borderRadius(5)
        }
      }.layoutWeight(1).height(12)
      Text(`${count} 次`).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeText).width(48).textAlign(TextAlign.End)
    }.width('100%')
  }

  build() {
    Column({ space: 12 }) {
      Column({ space: 12 }) {
        PageHeader(this.theme, '回顾', '看见记录背后的节奏与情绪')
        Row({ space: 12 }) {
          FilterChip(this.theme, '趋势', !this.showCalendar, () => this.showCalendar = false)
          FilterChip(this.theme, '日历', this.showCalendar, () => this.showCalendar = true)
        }.width('100%')
      }.width('100%').padding({ left: 20, right: 20 })
      if (this.showCalendar) {
        CalendarPage({ theme: this.theme, calendar: this.calendar, feedback: this.feedback, actions: this.actions, embedded: true })
      } else {
        this.statsPage()
      }
    }.width('100%').height('100%').backgroundColor(this.theme.themeBackground)
  }
}
