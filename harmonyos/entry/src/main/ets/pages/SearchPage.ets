// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { EmotionRecord, LogItem, TaskItem } from '../models/Models';
import { dayString } from '../data/DateUtils';
import { tr } from '../data/I18n';
import { highlightParts, globalSearch, HighlightPart, SearchMatch, SearchMatchKind, searchKindName } from '../data/GlobalSearch';
import { ThemeState, LogsState, EmotionState, CalendarState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  EmptyState, brandText, hairlineColor, iconSemantic, pageGutter, tertiaryText, paperShadow,
  TYPE_BODY, TYPE_SECONDARY, TYPE_CAPTION, RADIUS_FIELD, RADIUS_ROW
} from '../components/CommonBuilders';

interface SearchGroup {
  kind: SearchMatchKind;
  items: SearchMatch[];
}

/** 全局搜索（对齐 iOS）：跨日志 / 灵感 / 情绪 / 任务，200ms 防抖，分组，命中词高亮，跨 Tab 定位。 */
@Component
export struct SearchPage {
  @ObjectLink theme: ThemeState;
  @ObjectLink logs: LogsState;
  @ObjectLink emotion: EmotionState;
  @ObjectLink calendar: CalendarState;
  actions?: PageActions;
  @State private query: string = '';
  @State private applied: string = '';
  private timer: number = 0;

  aboutToDisappear(): void {
    clearTimeout(this.timer);
  }

  private matches(): SearchMatch[] {
    return globalSearch(this.logs.logs, this.emotion.emotions, this.calendar.tasks, this.applied);
  }

  private groups(): SearchGroup[] {
    const all = this.matches();
    const out: SearchGroup[] = [];
    [SearchMatchKind.LOG, SearchMatchKind.EMOTION, SearchMatchKind.TASK].forEach((kind: SearchMatchKind) => {
      const items = all.filter((item: SearchMatch) => item.kind === kind);
      if (items.length > 0) out.push({ kind: kind, items: items });
    });
    return out;
  }

  private open(match: SearchMatch): void {
    const actions = requireActions(this.actions);
    if (match.kind === SearchMatchKind.LOG) {
      actions.logsController.openLogById(match.id);
    } else if (match.kind === SearchMatchKind.EMOTION) {
      actions.switchTab(2);
    } else {
      const task = this.calendar.tasks.find((item: TaskItem) => item.id === match.id);
      if (task) actions.calendarController.selectCalendarDay(actions.calendarController.taskCalendarDay(task));
      actions.openDetail('calendar');
    }
  }

  private relativeDay(createdAt: string): string {
    const day = createdAt.slice(0, 10);
    if (day === dayString()) return tr('今天');
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    if (day === dayString(yesterday)) return tr('昨天');
    return day;
  }

  private kindSymbol(kind: SearchMatchKind): Resource {
    if (kind === SearchMatchKind.EMOTION) return $r('sys.symbol.face_smiling');
    if (kind === SearchMatchKind.TASK) return $r('sys.symbol.checkmark_circle');
    return $r('sys.symbol.doc_text');
  }

  private kindColor(kind: SearchMatchKind): string {
    if (kind === SearchMatchKind.EMOTION) return iconSemantic(this.theme, 'emotion');
    if (kind === SearchMatchKind.TASK) return iconSemantic(this.theme, 'task');
    return iconSemantic(this.theme, 'calendar');
  }

  @Builder
  private row(match: SearchMatch) {
    Row({ space: 12 }) {
      SymbolGlyph(this.kindSymbol(match.kind)).fontSize(18).fontColor([this.kindColor(match.kind)])
      Text() {
        ForEach(highlightParts(match.title, this.applied), (part: HighlightPart, index: number) => {
          Span(part.text)
            .fontColor(part.hit ? brandText(this.theme) : this.theme.themeText)
            .fontWeight(part.hit ? FontWeight.Medium : FontWeight.Regular)
        }, (part: HighlightPart, index: number) => `${index}-${part.text}`)
      }
      .fontSize(TYPE_BODY).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
      Text(this.relativeDay(match.createdAt)).fontSize(TYPE_CAPTION).fontColor(tertiaryText(this.theme))
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.theme.themeSurface)
    .borderRadius(RADIUS_ROW)
    .border({ width: 0.75, color: hairlineColor(this.theme) })
    .shadow(paperShadow(this.theme))
    .accessibilityGroup(true)
    .onClick(() => this.open(match))
  }

  build() {
    Column({ space: 12 }) {
      TextInput({ placeholder: tr('关键词或标签'), text: this.query })
        .height(44).maxLength(200).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
        .backgroundColor(this.theme.themeControl).borderRadius(RADIUS_FIELD)
        .defaultFocus(true)
        .onChange((value: string) => {
          this.query = value;
          clearTimeout(this.timer);
          if (value.trim() === '') {
            this.applied = '';
          } else {
            this.timer = setTimeout(() => this.applied = value, 200);
          }
        })
      if (this.applied.trim() === '') {
        EmptyState(this.theme, '🔍', tr('搜索记录、灵感、情绪与任务'))
        Text(tr('输入关键词或标签名')).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted)
      } else if (this.matches().length === 0) {
        EmptyState(this.theme, '🔍', tr('没有找到相关记录'))
      } else {
        List({ space: 8 }) {
          ForEach(this.groups(), (group: SearchGroup) => {
            ListItem() {
              Text(`${searchKindName(group.kind)} · ${group.items.length}`)
                .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).padding({ top: 8 })
            }
            ForEach(group.items, (match: SearchMatch) => {
              ListItem() {
                this.row(match)
              }
            }, (match: SearchMatch) => `${match.kind}-${match.id}`)
          }, (group: SearchGroup) => group.kind)
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: pageGutter(), right: pageGutter() })
  }
}
