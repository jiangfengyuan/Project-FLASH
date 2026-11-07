let captureStorage = new LocalStorage();

/** 2×4 卡片（对齐 iOS 中号小组件）：今日计数 + 「灵感 / 日志」按钮。只显示计数，不显示内容。 */
@Entry(captureStorage)
@Component
struct TodayCaptureCard {
  @LocalStorageProp('records') records: string = '0';
  @LocalStorageProp('tasks') tasks: string = '0';

  @Builder
  private action(label: Resource, entry: string) {
    Text(label)
      .fontSize(14)
      .fontColor($r('app.color.form_ink'))
      .textAlign(TextAlign.Center)
      .width(84)
      .height(44)
      .backgroundColor($r('app.color.form_oat'))
      .borderRadius(12)
      .onClick(() => {
        postCardAction(this, { action: 'router', abilityName: 'EntryAbility', params: { flashEntry: entry } });
      })
  }

  build() {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text($r('app.string.form_today_title')).fontSize(13).fontColor($r('app.color.form_accent_records'))
        Text(this.records).fontSize(30).fontWeight(FontWeight.Bold).fontColor($r('app.color.form_ink'))
        Text($r('app.string.form_stat_records')).fontSize(12).fontColor($r('app.color.form_ink_secondary'))
        Row({ space: 4 }) {
          Text(this.tasks).fontSize(12).fontColor($r('app.color.form_ink_secondary'))
          Text($r('app.string.form_stat_tasks')).fontSize(12).fontColor($r('app.color.form_ink_secondary'))
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        postCardAction(this, { action: 'router', abilityName: 'EntryAbility', params: { flashEntry: 'today' } });
      })
      Column({ space: 8 }) {
        this.action($r('app.string.form_action_idea'), 'capture-idea')
        this.action($r('app.string.form_action_log'), 'capture-log')
      }
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .backgroundColor($r('app.color.form_paper'))
    .border({ width: 0.75, color: $r('app.color.form_border') })
    .borderRadius(20)
  }
}
