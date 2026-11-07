import { dayString, monthTitle } from '../data/DateUtils';
import { tr } from '../data/I18n';
import { DayMarkers } from '../data/CalendarMarkers';
import { EmotionRecord, emotionEmoji, emotionName, LogItem, TaskDueKind, TaskItem } from '../models/Models';
import { ThemeState, CalendarState, FeedbackState, DeleteKind } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  RecordRow, FlashCard, DOCK_CLEARANCE, brandText, brandFill, onBrandFill, chipSelected, chipSelectedText, iconSemantic, successText, pageGutter, dangerText, hairlineColor, successFill,
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
            .accessibilityText(tr('上一月')).onClick(() => requireActions(this.actions).calendarController.shiftMonth(-1))
          Text(monthTitle(this.calendar.displayedMonth)).fontSize(TYPE_SECTION).fontWeight(FontWeight.Bold)
            .fontColor(this.theme.themeText).layoutWeight(1).textAlign(TextAlign.Center)
          Button('›').height(44).width(44).fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint)
            .accessibilityText(tr('下一月')).onClick(() => requireActions(this.actions).calendarController.shiftMonth(1))
        }.width('100%')
        Row({ space: 12 }) {
          Button(tr('回到今天')).height(44).fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint)
            .onClick(() => requireActions(this.actions).calendarController.backToToday())
          Button(tr('新建任务')).height(44).fontColor(onBrandFill(this.theme)).backgroundColor(brandFill(this.theme))
            .onClick(() => requireActions(this.actions).calendarController.openTaskEditor(undefined, this.calendar.selectedDay))
        }.width('100%')
        Row() {
          ForEach([tr('一'), tr('二'), tr('三'), tr('四'), tr('五'), tr('六'), tr('日')], (day: string) => {
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
        ForEach([this.calendar.selectedDay], (day: string) => {
          FlashCard({ theme: this.theme, contentPadding: 14, space: 8 }) {
            Row() {
              Text(tr('{0} 详情', day)).fontSize(TYPE_BODY).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).layoutWeight(1)
              Button(tr('添加任务'), { type: ButtonType.Normal }).height(44).fontSize(TYPE_CAPTION)
                .fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint).onClick(() => requireActions(this.actions).calendarController.openTaskEditor(undefined, day))
            }.width('100%')
            if (this.dayCount(day) === 0) {
              Text(tr('这一天还没有计划或记录')).fontSize(TYPE_BODY).fontColor(this.theme.themeMuted).width('100%')
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

      }.width('100%').padding({ left: pageGutter(), right: pageGutter(), bottom: this.embedded ? DOCK_CLEARANCE : 30 })
    }.width('100%').layoutWeight(1)
  }

  private dayCount(day: string): number {
    return requireActions(this.actions).calendarController.dayCount(day);
  }

  @Builder
  private dayCell(day: string) {
    Column({ space: 2 }) {
      Row({ space: 3 }) {
        Text(`${Number(day.slice(8, 10))}`).fontSize(TYPE_BODY)
          .fontWeight(day === dayString() ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(day === this.calendar.selectedDay ? chipSelectedText(this.theme) : this.theme.themeText)
      }.justifyContent(FlexAlign.Center)
      // 记录数 · 任务数 + 当天第一个情绪 emoji（对齐 iOS）。
      Row({ space: 3 }) {
        if ((this.calendar.logsByDay.get(day) ?? []).length > 0) {
          Text(`${(this.calendar.logsByDay.get(day) ?? []).length}`).fontSize(TYPE_CAPTION).lineHeight(12)
            .fontColor(day === this.calendar.selectedDay ? chipSelectedText(this.theme) : iconSemantic(this.theme, 'calendar'))
        }
        if (this.openTasks(day) > 0) {
          Text(`${this.openTasks(day)}`).fontSize(TYPE_CAPTION).lineHeight(12)
            .fontColor(day === this.calendar.selectedDay ? chipSelectedText(this.theme) : successText(this.theme))
        }
      }.justifyContent(FlexAlign.Center).height(12)
      Text(this.firstEmoji(day)).fontSize(TYPE_CAPTION).lineHeight(14).height(14)
    }
    .layoutWeight(1).constraintSize({ minHeight: 64 }).justifyContent(FlexAlign.Center)
    .borderRadius(10)
    .backgroundColor(day === this.calendar.selectedDay ? chipSelected(this.theme) : this.theme.themeSurface)
    .border({ width: day === this.calendar.selectedDay ? 0 : 0.5, color: hairlineColor(this.theme) })
    .opacity(day.slice(0, 7) === this.calendar.displayedMonth.slice(0, 7) ? 1 : 0.55)
    .stateStyles({
      normal: { .scale({ x: 1, y: 1 }) },
      pressed: { .scale({ x: 0.94, y: 0.94 }) }
    })
    .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
    .accessibilityText(tr('{0}，{1} 项', day, this.dayCount(day)) +
      (this.dayMarkers(day).emotionLevel !== undefined ? tr('，当日有情绪记录') : '') +
      (day === this.calendar.selectedDay ? tr('，已选中') : ''))
    .onClick(() => requireActions(this.actions).calendarController.selectCalendarDay(day))
  }

  // 灵感转的任务：来源还在时显示回链（日历按日分组里查）。
  private sourceExists(item: TaskItem): boolean {
    const id = item.sourceLogId;
    if (typeof id !== 'string' || id === '') return false;
    let found = false;
    this.calendar.logsByDay.forEach((entries: LogItem[]) => {
      if (!found && entries.some((log: LogItem) => log.id === id)) found = true;
    });
    return found;
  }

  private openTasks(day: string): number {
    return (this.calendar.tasksByDay.get(day) ?? []).filter((item: TaskItem) => !item.completedAt).length;
  }

  private firstEmoji(day: string): string {
    const first = (this.calendar.emotionsByDay.get(day) ?? [])[0];
    return first === undefined ? '' : emotionEmoji(first.level);
  }

  private dayMarkers(day: string): DayMarkers {
    return requireActions(this.actions).calendarController.dayMarkers(day);
  }

  @Builder
  private taskRow(item: TaskItem) {
    Row({ space: 10 }) {
      Button(item.completedAt ? '✓' : '○', { type: ButtonType.Circle })
        .width(44).height(44).fontSize(18)
        .fontColor(item.completedAt ? onBrandFill(this.theme) : brandText(this.theme))
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
        // 全天任务不显示时刻；定时任务按任务时区显示（不把 UTC 当本地）。
        Text(item.due.kind === TaskDueKind.ALL_DAY ? tr('全天') : requireActions(this.actions).calendarController.taskTimeLabel(item))
          .fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted).width('100%')
        if (this.sourceExists(item)) {
          Text(tr('查看灵感')).fontSize(TYPE_CAPTION).fontColor(brandText(this.theme)).height(32)
            .onClick(() => requireActions(this.actions).logsController.openLogById(item.sourceLogId as string))
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button(tr('编辑'), { type: ButtonType.Normal }).height(44).fontSize(TYPE_CAPTION)
        .fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint).onClick(() => requireActions(this.actions).calendarController.openTaskEditor(item))
      Button(tr('删除'), { type: ButtonType.Normal }).height(44).fontSize(TYPE_CAPTION)
        .fontColor(dangerText(this.theme)).backgroundColor(this.theme.themeDanger).onClick(() => this.feedback.destructive = { kind: DeleteKind.TASK, id: item.id })
    }.width('100%').padding(10).backgroundColor(this.theme.themeControl).borderRadius(14)
      .border({ width: 0.5, color: hairlineColor(this.theme) })
  }

  build() {
    this.calendarPage()
  }
}
