import { ActivityChart } from '../components/ActivityChart';
import { CalendarPage } from './CalendarPage';
import { reviewDays, dailyActivity, reviewComparison, emotionDistribution, ReviewComparison, EmotionDistribution, SubEmotionSlice } from '../data/ReviewWindow';
import { shortDay } from '../data/DateUtils';
import { Category, LogItem, EmotionRecord } from '../models/Models';
import { ThemeState, LogsState, EmotionState, CalendarState, FeedbackState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import { PageHeader, DOCK_CLEARANCE, RADIUS_CARD, FilterChip, brandText, cardShadowColor, hairlineColor } from '../components/CommonBuilders';

@Component
export struct StatsPage {
  @ObjectLink theme: ThemeState;
  @ObjectLink logs: LogsState;
  @ObjectLink emotion: EmotionState;
  @ObjectLink calendar: CalendarState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;
  @State showCalendar: boolean = false;
  @State window: string = 'week';

  private days(): string[] { return reviewDays(this.window); }
  private periodLogs(): LogItem[] {
    const days = this.days();
    return this.logs.logs.filter((item: LogItem) => days.includes(item.recordDate));
  }
  private periodEmotions(): EmotionRecord[] {
    const days = this.days();
    return this.emotion.emotions.filter((item: EmotionRecord) => days.includes(item.recordDate));
  }
  private activeDays(): number {
    const days = this.periodLogs().map((item: LogItem) => item.recordDate)
      .concat(this.periodEmotions().map((item: EmotionRecord) => item.recordDate));
    return new Set<string>(days).size;
  }
  private periodAverage(): string {
    const items = this.periodEmotions();
    return items.length === 0 ? '—' :
      (items.reduce((sum: number, item: EmotionRecord) => sum + item.level, 0) / items.length).toFixed(1);
  }
  private comparison(): ReviewComparison {
    return reviewComparison(this.logs.logs, this.emotion.emotions, this.window);
  }
  private distribution(): EmotionDistribution {
    return emotionDistribution(this.emotion.emotions, this.days());
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
        Column({ space: 8 }) {
          Text(this.comparison().conclusion)
            .fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          Text(`${this.days()[0]} — ${this.days()[this.days().length - 1]}`)
            .fontSize(12).fontColor(this.theme.themeMuted).width('100%')
          if (this.comparison().insufficient) {
            Text(`这段时间有 ${this.periodLogs().length} 条记录 · ${this.periodEmotions().length} 次情绪`)
              .fontSize(14).fontColor(this.theme.themeText).width('100%')
          } else {
            Text(`${this.comparison().currentLabel} ${this.comparison().currentCount} 条 · ${this.comparison().previousLabel} ${this.comparison().previousCount} 条`)
              .fontSize(14).fontColor(this.theme.themeText).width('100%')
            Text(`活跃 ${this.activeDays()} 天 · 平均情绪 ${this.periodAverage()}`)
              .fontSize(14).fontColor(this.theme.themeText).width('100%')
          }
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)
          .border({ width: 0.5, color: hairlineColor(this.theme) })
          .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })
        ActivityChart({ theme: this.theme, days: dailyActivity(this.logs.logs, this.emotion.emotions, this.days()) })
        Row({ space: 10 }) {
          this.metric(`${this.periodLogs().length}`, '范围内记录', this.theme.themeTint)
          this.metric(`${this.periodAverage()}`, '平均情绪', this.theme.themeTint)
        }.width('100%')
        Column({ space: 12 }) {
          Text('情绪趋势 · 日均值').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          Text('-3 至 +3，0 为中性；— 表示当日未记录')
            .fontSize(12).fontColor(this.theme.themeMuted).width('100%')
          if (this.periodEmotions().length === 0) {
            Text('时间范围内暂无情绪记录').fontSize(14).fontColor(this.theme.themeMuted)
          }
          ForEach(this.days(), (day: string) => {
            Row({ space: 10 }) {
              Text(shortDay(day)).fontSize(12).fontColor(this.theme.themeMuted).width(58)
              Stack({ alignContent: Alignment.Start }) {
                Row().height(10).width('100%').backgroundColor(this.theme.themeControl).borderRadius(5)
                Row().height(10).width(`${requireActions(this.actions).emotionController.dayBar(day)}%`).backgroundColor(brandText(this.theme)).borderRadius(5)
              }.layoutWeight(1).height(12)
              Text(requireActions(this.actions).emotionController.dayEmotionLabel(day)).fontSize(12).fontColor(this.theme.themeText).width(34)
            }.width('100%')
          }, (day: string) => day)
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)
          .border({ width: 0.5, color: hairlineColor(this.theme) })
          .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })

        Column({ space: 12 }) {
          Text('情绪分布').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          Text('时间范围内开心 / 中性 / 不开心的次数，条形长度按比例')
            .fontSize(12).fontColor(this.theme.themeMuted).width('100%')
          if (this.distribution().total === 0) {
            Text('时间范围内暂无情绪记录，分布会慢慢成形').fontSize(14).fontColor(this.theme.themeMuted).width('100%')
          } else {
            this.distributionRow('开心', this.distribution().positive, this.distribution().total)
            this.distributionRow('中性', this.distribution().neutral, this.distribution().total)
            this.distributionRow('不开心', this.distribution().negative, this.distribution().total)
            if (this.distribution().subEmotions.length > 0) {
              Text('不开心时的具体感受').fontSize(12).fontColor(this.theme.themeMuted).width('100%')
              ForEach(this.distribution().subEmotions, (slice: SubEmotionSlice) => {
                this.distributionRow(slice.name, slice.count, this.distribution().negative)
              }, (slice: SubEmotionSlice) => slice.key)
            }
          }
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)
          .border({ width: 0.5, color: hairlineColor(this.theme) })
          .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })

        Column({ space: 10 }) {
          Text('累计构成 · 全部时间').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          this.statLine('日志', this.logs.logs.filter((item: LogItem) => item.category === Category.LOG).length, '#5A88E8')
          this.statLine('灵感', this.logs.logs.filter((item: LogItem) => item.category === Category.IDEA).length, '#C87D2A')
          this.statLine('情绪', this.emotion.emotions.length, '#9A74EA')
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)
          .border({ width: 0.5, color: hairlineColor(this.theme) })
          .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })
      }.width('100%').padding({ left: 20, right: 20, bottom: DOCK_CLEARANCE })
    }.width('100%').layoutWeight(1).backgroundColor(this.theme.themeBackground)
  }

  @Builder
  private metric(value: string, label: string, background: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(28).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText)
      Text(label).fontSize(12).fontColor(this.theme.themeMuted)
    }.layoutWeight(1).height(88).justifyContent(FlexAlign.Center).backgroundColor(background).borderRadius(18)
      .border({ width: 0.5, color: hairlineColor(this.theme) })
  }

  @Builder
  private statLine(label: string, value: number, color: string) {
    Row({ space: 10 }) {
      Row().width(10).height(10).borderRadius(5).backgroundColor(color)
      Text(label).fontSize(14).fontColor(this.theme.themeText).layoutWeight(1)
      Text(`${value}`).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
    }.width('100%')
  }

  @Builder
  private distributionRow(label: string, count: number, total: number) {
    Row({ space: 10 }) {
      Text(label).fontSize(12).fontColor(this.theme.themeMuted).width(58)
      Stack({ alignContent: Alignment.Start }) {
        Row().height(10).width('100%').backgroundColor(this.theme.themeControl).borderRadius(5)
        if (count > 0 && total > 0) {
          Row().height(10).width(`${Math.max(4, Math.round(100 * count / total))}%`).backgroundColor(brandText(this.theme)).borderRadius(5)
        }
      }.layoutWeight(1).height(12)
      Text(`${count} 次`).fontSize(12).fontColor(this.theme.themeText).width(48).textAlign(TextAlign.End)
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

