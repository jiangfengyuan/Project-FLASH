// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { Category, colorTagName, LogItem } from '../models/Models';
import { shareLog } from '../data/ShareService';
import { NavigationState, ThemeState, LogsState, FeedbackState, SettingsState, DeleteKind } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  BRAND, FormGroup, FormRow, RADIUS_CARD, brandText, cardShadowColor, colorTagLabelColor, dangerText,
  floatingSurface, hairlineColor, importanceText, scrimColor, supportsBlurMaterial,
  DIALOG_WIDTH_FORM, DIALOG_WIDTH_PERCENT, TYPE_BODY, TYPE_SECONDARY, TYPE_CAPTION, TYPE_GROUP
} from './CommonBuilders';

/** 记录详情弹层：完整内容、元数据与操作（编辑/删除/分享）。
 * 卡片点击统一进入本视图，编辑仍在 EditLogDialog 内完成。 */
@Component
export struct RecordDetailDialog {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink logs: LogsState;
  @ObjectLink feedback: FeedbackState;
  @ObjectLink settings: SettingsState;
  actions?: PageActions;

  private close(): void {
    requireActions(this.actions).logsController.closeLogDetail();
  }

  private item(): LogItem | undefined {
    return requireActions(this.actions).logsController.detailLog();
  }

  private share(item: LogItem): void {
    const runtime = requireActions(this.actions).controller.runtime;
    try {
      const context = runtime.context();
      shareLog(context, item).catch((error: Error) => {
        runtime.notify(`分享失败：${runtime.errorMessage(error)}`, 'error');
      });
    } catch (error) {
      runtime.notify(`分享失败：${runtime.errorMessage(error as Error)}`, 'error');
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor(scrimColor(this.theme))
        .backdropBlur(supportsBlurMaterial() ? 12 : 0)
        .onClick(() => this.close())
      Scroll() {
        Column({ space: 14 }) {
          this.headerRow()
          if (!this.item()) {
            Text('这条记录已不存在').fontSize(TYPE_BODY).fontColor(this.theme.themeMuted).width('100%')
              .textAlign(TextAlign.Center).padding({ top: 24, bottom: 24 })
            Button('返回', { type: ButtonType.Normal }).width('100%').height(44)
              .fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint)
              .onClick(() => this.close())
          } else {
            this.detailBody(this.item()!)
          }
        }
        .width('100%')
        .padding(22)
      }
      .width(this.navigation.isMediumWindow ? DIALOG_WIDTH_FORM : DIALOG_WIDTH_PERCENT)
      .constraintSize({ maxHeight: '90%' })
      .backgroundColor(floatingSurface(this.theme))
      .backgroundBlurStyle(supportsBlurMaterial() ? BlurStyle.COMPONENT_ULTRA_THICK : BlurStyle.NONE)
      .borderRadius(RADIUS_CARD)
      .border({ width: 0.5, color: hairlineColor(this.theme) })
      .shadow({ radius: 24, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 10 })
    }.width('100%').height('100%')
  }

  @Builder
  private headerRow() {
    Row() {
      Button('关闭', { type: ButtonType.Normal })
        .fontSize(TYPE_BODY).fontColor(this.theme.themeMuted).backgroundColor(Color.Transparent).height(44)
        .onClick(() => this.close())
      Blank()
      Text(this.item()?.category === Category.IDEA ? '灵感详情' : '记录详情')
        .fontSize(TYPE_GROUP).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
      Blank()
      // 受限能力：设备不支持系统分享时不渲染入口（不留虚假按钮，占位保持标题居中）。
      if (this.settings.systemShareSupported && this.item()) {
        Button('分享', { type: ButtonType.Normal })
          .fontSize(TYPE_BODY).fontColor(brandText(this.theme)).backgroundColor(Color.Transparent).height(44)
          .accessibilityText('分享这条记录')
          .onClick(() => this.share(this.item()!))
      } else {
        Text(' ').width(56)
      }
    }.width('100%')
  }

  @Builder
  private detailBody(item: LogItem) {
    Row({ space: 8 }) {
      this.metaChip(item.category === Category.IDEA ? '灵感' : '日志')
      this.metaChip(colorTagName(item.colorTag))
      if (item.importance > 0) {
        Text(`重要度 ${'!'.repeat(item.importance)}`).fontSize(TYPE_CAPTION).fontColor(importanceText(this.theme))
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(this.theme.themeTint).borderRadius(16)
      }
    }.width('100%')

    Column() {
      Text(item.content).fontSize(TYPE_BODY).fontColor(this.theme.themeText).lineHeight(24).width('100%')
        .copyOption(CopyOptions.LocalDevice)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.theme.themeControl)
    .borderRadius(16)

    FormGroup(this.theme, '元数据')
    Column({ space: 2 }) {
      FormRow(this.theme, '记录日期', item.recordDate)
      FormRow(this.theme, '创建时间', `${item.createdAt.slice(0, 10)} ${item.createdAt.slice(11, 16)} UTC`)
      FormRow(this.theme, '重要度', `${item.importance}`)
    }.width('100%')

    Row({ space: 12 }) {
      Button('编辑', { type: ButtonType.Normal }).layoutWeight(1).height(44)
        .fontColor(Color.White).backgroundColor(BRAND)
        .onClick(() => requireActions(this.actions).logsController.startEditLog(item))
      Button('删除', { type: ButtonType.Normal }).layoutWeight(1).height(44)
        .fontColor(dangerText(this.theme)).backgroundColor(this.theme.themeDanger)
        .onClick(() => this.feedback.destructive = { kind: DeleteKind.LOG, id: item.id })
    }.width('100%')
  }

  @Builder
  private metaChip(label: string) {
    Text(label).fontSize(TYPE_CAPTION).fontColor(colorTagLabelColor(this.theme, ''))
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.theme.themeControl).borderRadius(16)
  }
}
