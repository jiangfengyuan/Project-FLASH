import { dayString, monthTitle, shortDay } from '../data/DateUtils';
import { EmotionRecord, emotionEmoji, emotionName, LogItem, TaskDueKind, TaskItem } from '../models/Models';
import { ThemeState, CalendarState, FeedbackState, DeleteKind } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import { EmptyState, RecordRow } from '../components/CommonBuilders';
const BRAND = '#6C5CE7';

@Component
export struct CalendarPage {
  @ObjectLink theme: ThemeState;
  @ObjectLink calendar: CalendarState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;

  @Builder
  private calendarPage() {
    Scroll() {
      Column({ space: 12 }) {
        Row({ space: 10 }) {
          Text(monthTitle(dayString())).fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText).layoutWeight(1)
          Button('＋ 新建任务').height(38).fontColor(Color.White).backgroundColor(BRAND)
            .onClick(() => requireActions(this.actions).calendarController.openTaskEditor(undefined, dayString()))
        }.width('100%')
        ForEach(requireActions(this.actions).calendarController.displayedActivityDays(), (day: string) => {
          Column({ space: 8 }) {
            Row() {
              Text(shortDay(day)).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).layoutWeight(1)
              Button('添加任务', { type: ButtonType.Normal }).height(30).fontSize(11)
                .fontColor(BRAND).backgroundColor(this.theme.themeTint).onClick(() => requireActions(this.actions).calendarController.openTaskEditor(undefined, day))
            }.width('100%')
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
          }.width('100%').padding(14).backgroundColor(this.theme.themeSurface).borderRadius(18)
        }, (day: string) => day)
        if (this.calendar.activityDays.length === 0) EmptyState(this.theme, '📅', '还没有记录或任务')
        if (this.calendar.activityDays.length > this.calendar.calendarDayLimit) {
          Button(`加载更早日期（剩余 ${this.calendar.activityDays.length - this.calendar.calendarDayLimit} 天）`)
            .width('100%').height(42).fontColor(BRAND).backgroundColor(this.theme.themeTint)
            .onClick(() => this.calendar.calendarDayLimit += 30)
        }
      }.width('100%').padding({ left: 16, right: 16, bottom: 30 })
    }.width('100%').layoutWeight(1)
  }

  @Builder
  private taskRow(item: TaskItem) {
    Row({ space: 10 }) {
      Button(item.completedAt ? '✓' : '○', { type: ButtonType.Circle })
        .width(34).height(34).fontSize(18)
        .fontColor(item.completedAt ? Color.White : BRAND)
        .backgroundColor(item.completedAt ? '#22B573' : this.theme.themeTint)
        .onClick(() => requireActions(this.actions).calendarController.toggleTask(item))
      Column({ space: 3 }) {
        Text(item.title).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
          .decoration({ type: item.completedAt ? TextDecorationType.LineThrough : TextDecorationType.None })
          .maxLines(2).width('100%')
        Text(item.due.kind === TaskDueKind.ALL_DAY ? '全天' : `${item.due.at?.slice(11, 16) ?? ''} · ${item.due.timeZone ?? ''}`)
          .fontSize(11).fontColor(this.theme.themeMuted).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Button('编辑', { type: ButtonType.Normal }).height(28).fontSize(11)
        .fontColor(BRAND).backgroundColor(this.theme.themeTint).onClick(() => requireActions(this.actions).calendarController.openTaskEditor(item))
      Button('删除', { type: ButtonType.Normal }).height(28).fontSize(11)
        .fontColor('#B42318').backgroundColor(this.theme.themeDanger).onClick(() => this.feedback.destructive = { kind: DeleteKind.TASK, id: item.id })
    }.width('100%').padding(10).backgroundColor(this.theme.themeControl).borderRadius(14)
  }

  build() {
    this.calendarPage()
  }
}

