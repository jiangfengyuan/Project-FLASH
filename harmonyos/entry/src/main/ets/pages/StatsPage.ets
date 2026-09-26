import { ActivityChart } from '../components/ActivityChart';
import { CalendarPage } from './CalendarPage';
import { reviewDays, dailyActivity } from '../data/ReviewWindow';
import { shortDay } from '../data/DateUtils';
import { Category, LogItem, EmotionRecord } from '../models/Models';
import { ThemeState, LogsState, EmotionState, CalendarState, FeedbackState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import { PageHeader, DOCK_CLEARANCE, RADIUS_CARD, BRAND, FilterChip } from '../components/CommonBuilders';

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
          Text(this.activeDays() === 0 ? '继续记录，回顾会慢慢清晰' : `这段时间，你留下了 ${this.activeDays()} 天的记录`)
            .fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          Text(`${this.days()[0]} — ${this.days()[this.days().length - 1]}`)
            .fontSize(12).fontColor(this.theme.themeMuted).width('100%')
          Text(`${this.periodLogs().length} 条记录 · ${this.periodEmotions().length} 次情绪`)
            .fontSize(14).fontColor(this.theme.themeText).width('100%')
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)
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
                Row().height(10).width(`${requireActions(this.actions).emotionController.dayBar(day)}%`).backgroundColor(BRAND).borderRadius(5)
              }.layoutWeight(1).height(12)
              Text(requireActions(this.actions).emotionController.dayEmotionLabel(day)).fontSize(12).fontColor(this.theme.themeText).width(34)
            }.width('100%')
          }, (day: string) => day)
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)

        Column({ space: 10 }) {
          Text('累计构成 · 全部时间').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          this.statLine('日志', this.logs.logs.filter((item: LogItem) => item.category === Category.LOG).length, '#4D96FF')
          this.statLine('灵感', this.logs.logs.filter((item: LogItem) => item.category === Category.IDEA).length, '#FF9F43')
          this.statLine('情绪', this.emotion.emotions.length, '#9B59B6')
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)
      }.width('100%').padding({ left: 20, right: 20, bottom: DOCK_CLEARANCE })
    }.width('100%').layoutWeight(1).backgroundColor(this.theme.themeBackground)
  }

  @Builder
  private metric(value: string, label: string, background: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(28).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText)
      Text(label).fontSize(12).fontColor(this.theme.themeMuted)
    }.layoutWeight(1).height(88).justifyContent(FlexAlign.Center).backgroundColor(background).borderRadius(18)
  }

  @Builder
  private statLine(label: string, value: number, color: string) {
    Row({ space: 10 }) {
      Row().width(10).height(10).borderRadius(5).backgroundColor(color)
      Text(label).fontSize(14).fontColor(this.theme.themeText).layoutWeight(1)
      Text(`${value}`).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
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

