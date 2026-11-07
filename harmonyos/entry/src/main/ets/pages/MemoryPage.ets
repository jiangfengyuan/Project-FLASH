// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { tr } from '../data/I18n';
import { weeklyReport, WeeklyReport } from '../data/WeeklyMemory';
import { TaskItem } from '../models/Models';
import { ThemeState, LogsState, EmotionState, CalendarState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  FlashCard, EmptyState, brandText, displayFontFamily, statFontFamily, iconSemantic, pageGutter,
  TYPE_SECTION, TYPE_GROUP, TYPE_BODY, TYPE_SECONDARY, TYPE_CAPTION, RADIUS_CARD_SMALL, TOUCH_MIN
} from '../components/CommonBuilders';

/** Memory 周报（对齐 iOS）：周导航、四类计数、本周情绪、亮点；不进入未来周。 */
@Component
export struct MemoryPage {
  @ObjectLink theme: ThemeState;
  @ObjectLink logs: LogsState;
  @ObjectLink emotion: EmotionState;
  @ObjectLink calendar: CalendarState;
  actions?: PageActions;
  @State private weekOffset: number = 0;

  private report(): WeeklyReport {
    const base = new Date();
    base.setDate(base.getDate() + this.weekOffset * 7);
    const controller = requireActions(this.actions).calendarController;
    return weeklyReport(this.logs.logs, this.emotion.emotions, this.calendar.tasks, base,
      (task: TaskItem) => controller.taskCalendarDay(task));
  }

  @Builder
  private countCard(title: string, value: number, icon: Resource, tint: string) {
    FlashCard({ theme: this.theme, contentPadding: 12, radius: RADIUS_CARD_SMALL, seed: `memory-${title}`, space: 4 }) {
      SymbolGlyph(icon).fontSize(18).fontColor([tint])
      Text(`${value}`).fontSize(TYPE_SECTION).fontFamily(statFontFamily()).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText)
      Text(title).fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
  }

  build() {
    Scroll() {
      Column({ space: 24 }) {
        Row({ space: 4 }) {
          Button('‹', { type: ButtonType.Normal }).width(TOUCH_MIN).height(TOUCH_MIN).fontColor(brandText(this.theme))
            .backgroundColor(Color.Transparent).accessibilityText(tr('上一周'))
            .onClick(() => this.weekOffset -= 1)
          Button(tr('回到本周'), { type: ButtonType.Normal }).height(TOUCH_MIN).fontSize(TYPE_SECONDARY)
            .fontColor(brandText(this.theme)).backgroundColor(Color.Transparent)
            .enabled(this.weekOffset !== 0).onClick(() => this.weekOffset = 0)
          Button('›', { type: ButtonType.Normal }).width(TOUCH_MIN).height(TOUCH_MIN).fontColor(brandText(this.theme))
            .backgroundColor(Color.Transparent).accessibilityText(tr('下一周'))
            .enabled(this.weekOffset !== 0).onClick(() => this.weekOffset += 1)
          Blank()
          Text(`${this.report().weekStart} — ${this.report().weekEnd}`).fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted)
        }.width('100%')

        if (!this.report().hasData) {
          EmptyState(this.theme, '✦', tr('再记录一点，未来的你会看到。'))
        } else {
          Column({ space: 8 }) {
            Text(tr('You recorded')).fontSize(TYPE_GROUP).fontFamily(displayFontFamily()).fontColor(this.theme.themeText).width('100%')
            Row({ space: 8 }) {
              Column() { this.countCard(tr('moments'), this.report().moments, $r('sys.symbol.doc_text'), iconSemantic(this.theme, 'calendar')) }.layoutWeight(1)
              Column() { this.countCard(tr('ideas'), this.report().ideas, $r('sys.symbol.lightbulb'), iconSemantic(this.theme, 'logs')) }.layoutWeight(1)
              Column() { this.countCard(tr('tasks'), this.report().tasks, $r('sys.symbol.checkmark_circle'), iconSemantic(this.theme, 'task')) }.layoutWeight(1)
              Column() { this.countCard(tr('emotions'), this.report().emotions, $r('sys.symbol.face_smiling'), iconSemantic(this.theme, 'emotion')) }.layoutWeight(1)
            }.width('100%').alignItems(VerticalAlign.Top)
          }.width('100%')

          if (this.report().mood !== undefined) {
            FlashCard({ theme: this.theme, seed: 'memory-mood', space: 8 }) {
              Text(tr('This week felt...')).fontSize(TYPE_GROUP).fontFamily(displayFontFamily()).fontColor(this.theme.themeText).width('100%')
              Row({ space: 12 }) {
                Text(this.report().mood?.emoji ?? '').fontSize(28)
                Text(this.report().mood?.text ?? '').fontSize(TYPE_SECONDARY).fontColor(this.theme.themeText)
              }.width('100%')
            }
          }

          if (this.report().highlights.length > 0) {
            FlashCard({ theme: this.theme, seed: 'memory-highlights', frayed: true, space: 8 }) {
              Text(tr('Highlights')).fontSize(TYPE_GROUP).fontFamily(displayFontFamily()).fontColor(this.theme.themeText).width('100%')
              ForEach(this.report().highlights, (title: string, index: number) => {
                Row({ space: 8 }) {
                  Text('•').fontSize(TYPE_BODY).fontColor(this.theme.themeMuted)
                  // 单行关键摘录：展示字体。
                  Text(title).fontSize(TYPE_BODY).fontFamily(displayFontFamily()).fontColor(this.theme.themeText)
                    .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                }.width('100%').alignItems(VerticalAlign.Top)
              }, (title: string, index: number) => `${index}-${title}`)
            }
          }

          Text(tr('A week worth remembering. ✦')).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted)
        }
      }
      .width('100%')
      .padding({ left: pageGutter(), right: pageGutter(), bottom: 32 })
    }
    .width('100%')
    .layoutWeight(1)
  }
}
