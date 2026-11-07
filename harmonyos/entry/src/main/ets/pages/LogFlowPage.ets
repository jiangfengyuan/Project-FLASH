// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { COLOR_TAGS, ColorTag, colorTagName, LogItem } from '../models/Models';
import { isValidRecordDay } from '../data/DateUtils';
import { tr } from '../data/I18n';
import { ThemeState, LogsState, FeedbackState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  RecordCard, EmptyState, FilterChip, SegmentedControl, pageGutter, TYPE_SECONDARY, RADIUS_FIELD
} from '../components/CommonBuilders';

const FLOW_SORTS: string[] = ['newest', 'oldest', 'tag'];

/** 日志流（对齐 iOS）：只含日志；已收藏、多选标签、日期上下界、三种排序。 */
@Component
export struct LogFlowPage {
  @ObjectLink theme: ThemeState;
  @ObjectLink logs: LogsState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;

  build() {
    List({ space: 12 }) {
      ListItem() {
        Column({ space: 10 }) {
          TextInput({ placeholder: tr('输入关键词或标签'), text: this.logs.flowQuery })
            .height(44).maxLength(200).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
            .backgroundColor(this.theme.themeControl).borderRadius(RADIUS_FIELD)
            .onChange((value: string) => this.logs.flowQuery = value)
          Scroll() {
            Row({ space: 8 }) {
              FilterChip(this.theme, tr('★ 已收藏'), this.logs.flowFavorites,
                () => this.logs.flowFavorites = !this.logs.flowFavorites)
              ForEach(COLOR_TAGS.filter((tag: string) => tag !== ColorTag.IDEA), (tag: string) => {
                FilterChip(this.theme, colorTagName(tag), this.logs.flowTags.includes(tag),
                  () => requireActions(this.actions).logsController.toggleFlowTag(tag))
              }, (tag: string) => tag)
            }
          }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
          Row({ space: 8 }) {
            this.dateField(tr('开始日期'), this.logs.flowStart, (value: string) => this.logs.flowStart = value)
            this.dateField(tr('结束日期'), this.logs.flowEnd, (value: string) => this.logs.flowEnd = value)
          }.width('100%')
          SegmentedControl(this.theme, [tr('最新'), tr('最早'), tr('按标签')], FLOW_SORTS.indexOf(this.logs.flowSort),
            (index: number) => this.logs.flowSort = FLOW_SORTS[index])
          Text(tr('{0} 条', requireActions(this.actions).logsController.flowLogs().length))
            .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
        }.width('100%')
      }
      if (requireActions(this.actions).logsController.flowLogs().length === 0) {
        ListItem() {
          EmptyState(this.theme, '🔍', tr('没有符合条件的日志'))
        }
      }
      ForEach(requireActions(this.actions).logsController.flowLogs().slice(0, 200), (item: LogItem) => {
        ListItem() {
          RecordCard({ theme: this.theme, feedback: this.feedback, actions: requireActions(this.actions), item: item })
        }
      }, (item: LogItem) => `${item.id}-${item.isFavorite === true}-${item.colorTag}-${item.content.length}`)
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: pageGutter(), right: pageGutter(), bottom: 32 })
  }

  // 日期输入：只接受完整有效的 yyyy-MM-dd；清空表示不限。
  @Builder
  private dateField(placeholder: string, value: string, onChange: (value: string) => void) {
    TextInput({ placeholder: placeholder, text: value })
      .layoutWeight(1).height(44).maxLength(10).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
      .backgroundColor(this.theme.themeControl).borderRadius(RADIUS_FIELD)
      .onChange((text: string) => {
        if (text === '' || isValidRecordDay(text)) onChange(text);
      })
  }
}
