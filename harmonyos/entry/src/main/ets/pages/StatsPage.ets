import { shortDay } from '../data/DateUtils';
import { Category, LogItem } from '../models/Models';
import { ThemeState, LogsState, EmotionState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import { PageHeader, DOCK_CLEARANCE } from '../components/CommonBuilders';
const BRAND = '#6C5CE7';

@Component
export struct StatsPage {
  @ObjectLink theme: ThemeState;
  @ObjectLink logs: LogsState;
  @ObjectLink emotion: EmotionState;
  actions?: PageActions;

  @Builder
  private statsPage() {
    Scroll() {
      Column({ space: 14 }) {
        PageHeader(this.theme, '回顾', '看见记录背后的节奏与情绪')
        Row({ space: 10 }) {
          this.metric(`${this.logs.logs.length}`, '全部记录', this.theme.themeTint)
          this.metric(`${requireActions(this.actions).emotionController.averageEmotion()}`, '平均情绪', this.theme.themeTint)
        }.width('100%')
        Column({ space: 12 }) {
          Text('近 7 天情绪').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          ForEach(requireActions(this.actions).emotionController.lastSevenDays(), (day: string) => {
            Row({ space: 10 }) {
              Text(shortDay(day)).fontSize(12).fontColor(this.theme.themeMuted).width(58)
              Stack({ alignContent: Alignment.Start }) {
                Row().height(10).width('100%').backgroundColor(this.theme.themeControl).borderRadius(5)
                Row().height(10).width(`${requireActions(this.actions).emotionController.dayBar(day)}%`).backgroundColor(BRAND).borderRadius(5)
              }.layoutWeight(1).height(12)
              Text(requireActions(this.actions).emotionController.dayEmotionLabel(day)).fontSize(12).fontColor(this.theme.themeText).width(34)
            }.width('100%')
          }, (day: string) => day)
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(20)

        Column({ space: 10 }) {
          Text('记录构成').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          this.statLine('日志', this.logs.logs.filter((item: LogItem) => item.category === Category.LOG).length, '#4D96FF')
          this.statLine('灵感', this.logs.logs.filter((item: LogItem) => item.category === Category.IDEA).length, '#FF9F43')
          this.statLine('情绪', this.emotion.emotions.length, '#9B59B6')
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(20)
      }.width('100%').padding({ left: 20, right: 20, bottom: DOCK_CLEARANCE })
    }.width('100%').height('100%').backgroundColor(this.theme.themeBackground)
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
    this.statsPage()
  }
}

