import { NavigationState, ThemeState, CalendarState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import { cardShadowColor, floatingSurface, hairlineColor, supportsBlurMaterial } from './CommonBuilders';
const BRAND = '#6C5CE7';

@Component
export struct TaskEditorDialog {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink calendar: CalendarState;
  actions?: PageActions;

  @Builder
  private taskEditorDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#66000000')
        .backdropBlur(supportsBlurMaterial() ? 12 : 0)
        .onClick(() => requireActions(this.actions).calendarController.closeTaskEditor())
      Scroll() {
        Column({ space: 12 }) {
          Text(this.calendar.editingTaskId === 'new' ? '新建任务' : '编辑任务')
            .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText).width('100%')
          TextInput({ placeholder: '任务标题', text: this.calendar.taskTitle })
            .height(44).maxLength(200).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
            .backgroundColor(this.theme.themeControl).borderRadius(12)
            .onChange((value: string) => this.calendar.taskTitle = value.slice(0, 200))
          TextArea({ placeholder: '备注（可选）', text: this.calendar.taskNotes })
            .height(80).maxLength(100000).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
            .backgroundColor(this.theme.themeControl).borderRadius(12)
            .onChange((value: string) => this.calendar.taskNotes = value.slice(0, 100000))
          Row() {
            Text('全天任务').fontSize(14).fontColor(this.theme.themeText).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.calendar.taskAllDay })
              .onChange((value: boolean) => this.calendar.taskAllDay = value)
          }.width('100%')
          Row({ space: 8 }) {
            TextInput({ placeholder: 'YYYY-MM-DD', text: this.calendar.taskDate })
              .layoutWeight(1).height(44).maxLength(10).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
              .backgroundColor(this.theme.themeControl).borderRadius(12)
              .onChange((value: string) => this.calendar.taskDate = value.slice(0, 10))
            if (!this.calendar.taskAllDay) {
              TextInput({ placeholder: 'HH:mm', text: this.calendar.taskTime })
                .width(100).height(44).maxLength(5).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
                .backgroundColor(this.theme.themeControl).borderRadius(12)
                .onChange((value: string) => this.calendar.taskTime = value.slice(0, 5))
            }
          }.width('100%')
          Text('本地提醒').fontSize(13).fontColor(this.theme.themeText).width('100%')
          Column({ space: 7 }) {
            Row({ space: 7 }) {
              this.reminderChip(-1, '不提醒')
              this.reminderChip(0, '到期时')
              this.reminderChip(15, '提前15分钟')
            }.width('100%')
            Row({ space: 7 }) {
              this.reminderChip(60, '提前1小时')
              this.reminderChip(1440, '提前1天')
              if (this.isCustomReminder()) {
                this.reminderChip(this.calendar.taskReminderMinutes, this.customReminderLabel())
              }
            }.width('100%')
          }.width('100%')
          Text('提醒由 HarmonyOS 系统后台托管；首次启用会请求通知权限。')
            .fontSize(11).fontColor(this.theme.themeMuted).width('100%')
          Row({ space: 10 }) {
            Button('取消').layoutWeight(1).height(44).fontColor(this.theme.themeMuted).backgroundColor(this.theme.themeControl)
              .onClick(() => requireActions(this.actions).calendarController.closeTaskEditor())
            Button('保存').layoutWeight(1).height(44).backgroundColor(BRAND)
              .enabled(this.calendar.taskTitle.trim().length > 0).onClick(() => requireActions(this.actions).calendarController.saveTaskEditor())
          }.width('100%')
        }.width('100%').padding(22)
      }
      .width(this.navigation.isMediumWindow ? 540 : '90%')
      .constraintSize({ maxHeight: '86%' })
      .backgroundColor(floatingSurface(this.theme))
      .backgroundBlurStyle(supportsBlurMaterial() ? BlurStyle.COMPONENT_ULTRA_THICK : BlurStyle.NONE)
      .borderRadius(24)
      .border({ width: 0.5, color: hairlineColor(this.theme) })
      .shadow({ radius: 24, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 10 })
    }.width('100%').height('100%')
  }

  @Builder
  private reminderChip(minutes: number, label: string) {
    Button(label, { type: ButtonType.Normal }).height(44).fontSize(11)
      .fontColor(this.calendar.taskReminderMinutes === minutes ? Color.White : this.theme.themeText)
      .backgroundColor(this.calendar.taskReminderMinutes === minutes ? BRAND : this.theme.themeControl)
      .onClick(() => this.calendar.taskReminderMinutes = minutes)
  }

  // Offsets outside the presets can arrive from another device; echo them as
  // an extra chip so saving the editor does not silently rewrite the reminder.
  private isCustomReminder(): boolean {
    const minutes = this.calendar.taskReminderMinutes;
    return minutes > 0 && ![15, 60, 1440].includes(minutes);
  }

  private customReminderLabel(): string {
    const minutes = this.calendar.taskReminderMinutes;
    if (minutes % 1440 === 0) return `提前${minutes / 1440}天`;
    if (minutes % 60 === 0) return `提前${minutes / 60}小时`;
    return `提前${minutes}分钟`;
  }

  build() {
    this.taskEditorDialog()
  }
}

