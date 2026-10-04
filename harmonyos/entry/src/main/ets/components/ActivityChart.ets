import { DailyActivity } from '../data/ReviewWindow';
import { ThemeState } from '../state/FeatureStates';
import {
  FlashCard, brandText, TYPE_GROUP, TYPE_BODY, TYPE_SECONDARY, TYPE_CAPTION
} from './CommonBuilders';

@Component
export struct ActivityChart {
  @ObjectLink theme: ThemeState;
  @Prop days: DailyActivity[] = [];
  @State expanded: boolean = false;

  private maximum(): number {
    return this.days.reduce((maximum: number, day: DailyActivity) => Math.max(maximum, day.total), 1);
  }

  private summary(): string {
    const active = this.days.filter((day: DailyActivity) => day.total > 0).length;
    const total = this.days.reduce((sum: number, day: DailyActivity) => sum + day.total, 0);
    return `${active} 个活跃日 · 共 ${total} 次`;
  }

  build() {
    FlashCard({ theme: this.theme, space: 8 }) {
      Text('记录活跃度').fontSize(TYPE_GROUP).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
      Text('每天的日志、灵感与情绪次数 · 不含任务').fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
      Text(this.summary()).fontSize(TYPE_BODY).fontColor(this.theme.themeText).width('100%')
      Text(`${this.maximum()} 次`).fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted).width('100%')
      Row({ space: 1 }) {
        ForEach(this.days, (day: DailyActivity) => {
          Column() {
            Row().width('75%').height(128 * day.total / this.maximum()).backgroundColor(brandText(this.theme))
          }.layoutWeight(1).height(128).justifyContent(FlexAlign.End)
        }, (day: DailyActivity) => day.date)
      }.width('100%').height(128).border({ width: { bottom: 1 }, color: this.theme.themeMuted })
        .accessibilityText('每日记录次数柱状图，' + this.summary() + '，可展开每日明细')
      Text('0').fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted).width('100%')
      Row() {
        Text(this.days[0]?.date ?? '').fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted)
        Blank()
        Text(this.days[this.days.length - 1]?.date ?? '').fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted)
      }.width('100%')
      Button(this.expanded ? '收起每日明细' : '查看每日明细').height(44)
        .fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint).onClick(() => this.expanded = !this.expanded)
      if (this.expanded) {
        ForEach(this.days, (day: DailyActivity) => {
          Text(`${day.date}：${day.records} 条记录 · ${day.emotions} 次情绪`)
            .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeText).width('100%')
        }, (day: DailyActivity) => day.date)
      }
    }
  }
}
