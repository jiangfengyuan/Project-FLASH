import { dayString, monthTitle } from '../data/DateUtils';
import { EmotionRecord, emotionEmoji, emotionName, LogItem, TaskDueKind, TaskItem } from '../models/Models';
import { ThemeState, CalendarState, FeedbackState, DeleteKind } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  RecordRow, FlashCard, BRAND, DOCK_CLEARANCE, brandText, dangerText, hairlineColor, successFill,
  motionDuration, MOTION_PRESS, TYPE_SECTION, TYPE_BODY, TYPE_SECONDARY, TYPE_CAPTION
} from '../components/CommonBuilders';

@Component
export struct CalendarPage {
  @ObjectLink theme: ThemeState;
  @ObjectLink calendar: CalendarState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;
  @Prop embedded: boolean = false;

  @Builder
  private calendarPage() {
    Scroll() {
      Column({ space: 12 }) {
        Row({ space: 4 }) {
          Button('‹').height(44).width(44).fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint)
            .accessibilityText('上一月').onClick(() => requireActions(this.actions).calendarController.shiftMonth(-1))
          Text(monthTitle(this.calendar.displayedMonth)).fontSize(TYPE_SECTION).fontWeight(FontWeight.Bold)
            .fontColor(this.theme.themeText).layoutWeight(1).textAlign(TextAlign.Center)
          Button('›').height(44).width(44).fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint)
            .accessibilityText('下一月').onClick(() => requireActions(this.actions).calendarController.shiftMonth(1))
        }.width('100%')
        Row({ space: 12 }) {
          Button('今天').height(44).fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint)
            .onClick(() => requireActions(this.actions).calendarController.backToToday())
          Button('新建任务').height(44).fontColor(Color.White).backgroundColor(BRAND)
            .onClick(() => requireActions(this.actions).calendarController.openTaskEditor(undefined, this.calendar.selectedDay))
        }.width('100%')
        Row() {
          ForEach(['一', '二', '三', '四', '五', '六', '日'], (day: string) => {
            Text(day).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).layoutWeight(1).textAlign(TextAlign.Center)
          }, (day: string) => day)
        }.width('100%')
        Column({ space: 4 }) {
          ForEach(requireActions(this.actions).calendarController.monthWeeks(), (week: string[]) => {
            Row({ space: 2 }) {
              ForEach(week, (day: string) => { this.dayCell(day) }, (day: string) => day)
            }.width('100%')
          }, (week: string[]) => week[0])
        }.width('100%')
        Text('日期下数字为记录、情绪与任务总数；点选查看详情。')
          .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
        ForEach([this.calendar.selectedDay], (day: string) => {
          FlashCard({ theme: this.theme, contentPadding: 14, space: 8 }) {
            Row() {
              Text(day + ' 详情').fontSize(TYPE_BODY).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).layoutWeight(1)
              Button('添加任务', { type: ButtonType.Normal }).height(44).fontSize(TYPE_CAPTION)
                .fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint).onClick(() => requireActions(this.actions).calendarController.openTaskEditor(undefined, day))
            }.width('100%')
            if (this.dayCount(day) === 0) {
              Text('这一天还没有计划或记录').fontSize(TYPE_BODY).fontColor(this.theme.themeMuted).width('100%')
            }
            ForEach(this.calendar.tasksByDay.get(day) ?? [],
              (item: TaskItem) => this.taskRow(item), (item: TaskItem) => item.id)
            ForEach(this.calendar.logsByDay.get(day) ?? [],
              (item: LogItem) => RecordRow(this.theme, this.feedback, requireActions(this.actions), item), (item: LogItem) => item.id)
            ForEach(this.calendar.emotionsByDay.get(day) ?? [],
              (item: EmotionRecord) => {
                Row({ space: 8 }) {
                  Text(emotionEmoji(item.level)).fontSize(TYPE_SECTION)
                  Text(`${emotionName(item.level)} ${item.note ?? ''}`).fontSize(TYPE_BODY).fontColor(this.theme.themeText).layoutWeight(1)
                }.width('100%')
              }, (item: EmotionRecord) => item.id)
          }
        }, (day: string) => day)

      }.width('100%').padding({ left: 16, right: 16, bottom: this.embedded ? DOCK_CLEARANCE : 30 })
    }.width('100%').layoutWeight(1)
  }

  private dayCount(day: string): number {
    return requireActions(this.actions).calendarController.dayCount(day);
  }

  @Builder
  private dayCell(day: string) {
    Column({ space: 2 }) {
      Text(`${Number(day.slice(8, 10))}`).fontSize(TYPE_BODY)
        .fontWeight(day === dayString() ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(day === this.calendar.selectedDay ? Color.White : this.theme.themeText)
      Text(this.dayCount(day) > 0 ? `${this.dayCount(day)}` : ' ')
        .fontSize(TYPE_CAPTION).fontColor(day === this.calendar.selectedDay ? Color.White : this.theme.themeMuted)
    }
    .layoutWeight(1).constraintSize({ minHeight: 48 }).justifyContent(FlexAlign.Center)
    .borderRadius(10)
    .backgroundColor(day === this.calendar.selectedDay ? BRAND : this.theme.themeSurface)
    .border({ width: day === this.calendar.selectedDay ? 0 : 0.5, color: hairlineColor(this.theme) })
    .opacity(day.slice(0, 7) === this.calendar.displayedMonth.slice(0, 7) ? 1 : 0.55)
    .stateStyles({
      normal: { .scale({ x: 1, y: 1 }) },
      pressed: { .scale({ x: 0.94, y: 0.94 }) }
    })
    .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
    .accessibilityText(`${day}，${this.dayCount(day)} 项${day === this.calendar.selectedDay ? '，已选中' : ''}`)
    .onClick(() => requireActions(this.actions).calendarController.selectCalendarDay(day))
  }

  @Builder
  private taskRow(item: TaskItem) {
    Row({ space: 10 }) {
      Button(item.completedAt ? '✓' : '○', { type: ButtonType.Circle })
        .width(44).height(44).fontSize(18)
        .fontColor(item.completedAt ? Color.White : brandText(this.theme))
        .backgroundColor(item.completedAt ? successFill() : this.theme.themeTint)
        .stateStyles({
          normal: { .scale({ x: 1, y: 1 }) },
          pressed: { .scale({ x: 0.9, y: 0.9 }) }
        })
        .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
        .onClick(() => requireActions(this.actions).calendarController.toggleTask(item))
      Column({ space: 3 }) {
        Text(item.title).fontSize(TYPE_BODY).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
          .decoration({ type: item.completedAt ? TextDecorationType.LineThrough : TextDecorationType.None })
          .maxLines(2).width('100%')
        Text(item.due.kind === TaskDueKind.ALL_DAY ? '全天' : `${item.due.at?.slice(11, 16) ?? ''} · ${item.due.timeZone ?? ''}`)
          .fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button('编辑', { type: ButtonType.Normal }).height(44).fontSize(TYPE_CAPTION)
        .fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint).onClick(() => requireActions(this.actions).calendarController.openTaskEditor(item))
      Button('删除', { type: ButtonType.Normal }).height(44).fontSize(TYPE_CAPTION)
        .fontColor(dangerText(this.theme)).backgroundColor(this.theme.themeDanger).onClick(() => this.feedback.destructive = { kind: DeleteKind.TASK, id: item.id })
    }.width('100%').padding(10).backgroundColor(this.theme.themeControl).borderRadius(14)
      .border({ width: 0.5, color: hairlineColor(this.theme) })
  }

  build() {
    this.calendarPage()
  }
}
