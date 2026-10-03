let storage = new LocalStorage();

@Entry(storage)
@Component
struct TodaySummaryCard {
  @LocalStorageProp('records') records: string = '0';
  @LocalStorageProp('ideas') ideas: string = '0';
  @LocalStorageProp('tasks') tasks: string = '0';

  build() {
    Column({ space: 10 }) {
      Row() {
        Text($r('app.string.form_today_title'))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
        Blank()
        Stack()
          .width(8)
          .height(8)
          .borderRadius(4)
          .backgroundColor($r('app.color.form_accent_records'))
      }
      .width('100%')

      Row() {
        Column({ space: 2 }) {
          Text(this.records)
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.form_accent_records'))
          Text($r('app.string.form_stat_records'))
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column({ space: 2 }) {
          Text(this.ideas)
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.form_accent_ideas'))
          Text($r('app.string.form_stat_ideas'))
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column({ space: 2 }) {
          Text(this.tasks)
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.form_accent_tasks'))
          Text($r('app.string.form_stat_tasks'))
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .borderRadius(16)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility'
      });
    })
  }
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
