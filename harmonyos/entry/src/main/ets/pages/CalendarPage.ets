import { dayString, monthTitle, shortDay, calendarWeeks } from '../data/DateUtils';
import { EmotionRecord, emotionEmoji, emotionName, LogItem, TaskDueKind, TaskItem } from '../models/Models';
import { ThemeState, CalendarState, FeedbackState, DeleteKind } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import { EmptyState, RecordRow, RADIUS_CARD, BRAND, DOCK_CLEARANCE, brandText, cardShadowColor, dangerText, hairlineColor } from '../components/CommonBuilders';

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
          Text(monthTitle(this.calendar.displayedMonth)).fontSize(18).fontWeight(FontWeight.Bold)
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
            Text(day).fontSize(12).fontColor(this.theme.themeMuted).layoutWeight(1).textAlign(TextAlign.Center)
          }, (day: string) => day)
        }.width('100%')
        Column({ space: 4 }) {
          ForEach(calendarWeeks(this.calendar.displayedMonth), (week: string[]) => {
            Row({ space: 2 }) {
              ForEach(week, (day: string) => { this.dayCell(day) }, (day: string) => day)
            }.width('100%')
          }, (week: string[]) => week[0])
        }.width('100%')
        Text('日期下数字为记录、情绪与任务总数；点选查看详情。')
          .fontSize(12).fontColor(this.theme.themeMuted).width('100%')
        ForEach([this.calendar.selectedDay], (day: string) => {
          Column({ space: 8 }) {
            Row() {
              Text(day + ' 详情').fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).layoutWeight(1)
              Button('添加任务', { type: ButtonType.Normal }).height(44).fontSize(11)
                .fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint).onClick(() => requireActions(this.actions).calendarController.openTaskEditor(undefined, day))
            }.width('100%')
            if (this.dayCount(day) === 0) {
              Text('这一天还没有计划或记录').fontSize(14).fontColor(this.theme.themeMuted).width('100%')
            }
            ForEach(this.calendar.tasksByDay.get(day) ?? [],
              (item: TaskItem) => this.taskRow(item), (item: TaskItem) => item.id)
            ForEach(this.calendar.logsByDay.get(day) ?? [],
              (item: LogItem) => RecordRow(this.theme, this.feedback, requireActions(this.actions), item), (item: LogItem) => item.id)
            ForEach(this.calendar.emotionsByDay.get(day) ?? [],
              (item: EmotionRecord) => {
                Row({ space: 8 }) {
                  Text(emotionEmoji(item.level)).fontSize(22)
                  Text(`${emotionName(item.level)} ${item.note ?? ''}`).fontSize(14).fontColor(this.theme.themeText).layoutWeight(1)
                }.width('100%')
              }, (item: EmotionRecord) => item.id)
          }.width('100%').padding(14).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)
            .border({ width: 0.5, color: hairlineColor(this.theme) })
            .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })
        }, (day: string) => day)

      }.width('100%').padding({ left: 16, right: 16, bottom: this.embedded ? DOCK_CLEARANCE : 30 })
    }.width('100%').layoutWeight(1)
  }

  private dayCount(day: string): number {
    return (this.calendar.logsByDay.get(day)?.length ?? 0) +
      (this.calendar.emotionsByDay.get(day)?.length ?? 0) + (this.calendar.tasksByDay.get(day)?.length ?? 0);
  }

  @Builder
  private dayCell(day: string) {
    Column({ space: 2 }) {
      Text(`${Number(day.slice(8, 10))}`).fontSize(14)
        .fontWeight(day === dayString() ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(day === this.calendar.selectedDay ? Color.White : this.theme.themeText)
      Text(this.dayCount(day) > 0 ? `${this.dayCount(day)}` : ' ')
        .fontSize(10).fontColor(day === this.calendar.selectedDay ? Color.White : this.theme.themeMuted)
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
    .animation({ duration: 120, curve: Curve.EaseOut })
    .accessibilityText(`${day}，${this.dayCount(day)} 项${day === this.calendar.selectedDay ? '，已选中' : ''}`)
    .onClick(() => requireActions(this.actions).calendarController.selectCalendarDay(day))
  }

  @Builder
  private taskRow(item: TaskItem) {
    Row({ space: 10 }) {
      Button(item.completedAt ? '✓' : '○', { type: ButtonType.Circle })
        .width(44).height(44).fontSize(18)
        .fontColor(item.completedAt ? Color.White : brandText(this.theme))
        .backgroundColor(item.completedAt ? '#1E9E62' : this.theme.themeTint)
        .onClick(() => requireActions(this.actions).calendarController.toggleTask(item))
      Column({ space: 3 }) {
        Text(item.title).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
          .decoration({ type: item.completedAt ? TextDecorationType.LineThrough : TextDecorationType.None })
          .maxLines(2).width('100%')
        Text(item.due.kind === TaskDueKind.ALL_DAY ? '全天' : `${item.due.at?.slice(11, 16) ?? ''} · ${item.due.timeZone ?? ''}`)
          .fontSize(11).fontColor(this.theme.themeMuted).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button('编辑', { type: ButtonType.Normal }).height(44).fontSize(11)
        .fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint).onClick(() => requireActions(this.actions).calendarController.openTaskEditor(item))
      Button('删除', { type: ButtonType.Normal }).height(44).fontSize(11)
        .fontColor(dangerText(this.theme)).backgroundColor(this.theme.themeDanger).onClick(() => this.feedback.destructive = { kind: DeleteKind.TASK, id: item.id })
    }.width('100%').padding(10).backgroundColor(this.theme.themeControl).borderRadius(14)
      .border({ width: 0.5, color: hairlineColor(this.theme) })
  }

  build() {
    this.calendarPage()
  }
}

