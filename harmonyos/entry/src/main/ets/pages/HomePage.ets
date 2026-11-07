// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { Category } from '../models/Models';
import { dayString } from '../data/DateUtils';
import { shouldShowIdeaReminder } from '../data/IdeaReminder';
import { greetingText } from '../data/AppEntry';
import { tr } from '../data/I18n';
import { NavigationState, ThemeState, HomeState, LogsState, FeedbackState, contentLayout } from '../state/FeatureStates';
import { LogItem, emotionEmoji, emotionName } from '../models/Models';
import { PageActions, requireActions } from '../state/PageActions';
import {
  FlashCard, RecordCard, EmptyState, TornSectionBreak, HandUnderline, StickyUnderSheet, DOCK_CLEARANCE, pageGutter,
  brandText, brandFill, onBrandFill, displayFontFamily, statFontFamily, hairlineColor, iconSemantic, statusText, paperShadow,
  motionDuration, MOTION_PRESS, TYPE_DISPLAY, TYPE_TITLE, TYPE_SECTION, TYPE_GROUP, TYPE_BODY, TYPE_SECONDARY, TYPE_CAPTION,
  RADIUS_CARD_SMALL, TOUCH_MIN
} from '../components/CommonBuilders';

/** 此刻页（对齐 iOS）：问候 + 新建 → 灵感提示 → 今日一览 → 断口 → 最近闪念；宽屏双栏。 */
@Component
export struct HomePage {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink home: HomeState;
  @ObjectLink logs: LogsState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;

  private isDual(): boolean {
    return contentLayout(this.navigation.isExpandedWindow, this.navigation.foldable, this.navigation.foldStatus) === 'dual';
  }

  @Builder
  private homePage() {
    Scroll() {
      Column({ space: 24 }) {
        this.greeting()
        if (shouldShowIdeaReminder(this.home.unviewedIdeaCount)) {
          this.ideaReminderRow()
        }
        if (this.isDual()) {
          Row({ space: 24 }) {
            Column() { this.todayCard() }.layoutWeight(1)
            Column() { this.recentSection() }.layoutWeight(1)
          }
          .alignItems(VerticalAlign.Top)
          .width('100%')
        } else {
          this.todayCard()
          TornSectionBreak({ theme: this.theme, seed: 'home-break' })
          this.recentSection()
        }
      }
      .width('100%')
      .padding({ left: pageGutter(), right: pageGutter(), top: 8, bottom: DOCK_CLEARANCE })
    }.width('100%').height('100%')
  }

  @Builder
  private greeting() {
    Column({ space: 6 }) {
      Row() {
        Blank()
        SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(20).fontColor([brandText(this.theme)])
          .width(TOUCH_MIN).height(TOUCH_MIN)
          .accessibilityText(tr('全局搜索'))
          .onClick(() => requireActions(this.actions).openDetail('search'))
      }.width('100%')
      Row({ space: 12 }) {
        Column({ space: 6 }) {
          Text(greetingText(new Date().getHours()))
            .fontSize(TYPE_DISPLAY).fontFamily(displayFontFamily()).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
          HandUnderline({ seed: 'greeting', color: brandText(this.theme), widthVp: 84 })
          Text(tr('今天也记录一点什么吧。')).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Button(tr('＋ 新建'))
          .height(TOUCH_MIN)
          .fontSize(TYPE_SECONDARY)
          .fontColor(onBrandFill(this.theme))
          .backgroundColor(brandFill(this.theme))
          .bindMenu([
            { value: tr('新建记录'), action: () => this.logs.quickCategory = Category.LOG },
            { value: tr('新建灵感'), action: () => this.logs.quickCategory = Category.IDEA },
            { value: tr('记录情绪'), action: () => requireActions(this.actions).switchTab(2) },
            { value: tr('新建任务'), action: () => requireActions(this.actions).calendarController.openTaskEditor(undefined, dayString()) }
          ])
      }.width('100%')
    }.width('100%')
  }

  @Builder
  private ideaReminderRow() {
    Stack() {
      StickyUnderSheet({ theme: this.theme, seed: 'idea-reminder', radius: RADIUS_CARD_SMALL })
      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.lightbulb')).fontSize(22).fontColor([statusText(this.theme, 'warn')])
        Column({ space: 2 }) {
          Text(tr('想法等待梳理')).fontSize(TYPE_BODY).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
          Text(tr('你还有 {0} 个想法，先看看最早的一条', this.home.unviewedIdeaCount))
            .fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Text(`${this.home.unviewedIdeaCount}`).fontSize(TYPE_GROUP).fontFamily(statFontFamily()).fontColor(statusText(this.theme, 'warn'))
        Text('›').fontSize(TYPE_GROUP).fontColor(this.theme.themeMuted)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(this.theme.themeSurface)
      .borderRadius(RADIUS_CARD_SMALL)
      .border({ width: 0.75, color: hairlineColor(this.theme) })
      .shadow(paperShadow(this.theme))
    }
    .width('100%')
    .accessibilityGroup(true)
    .accessibilityText(tr('{0} 个想法等待梳理，打开最早的一条', this.home.unviewedIdeaCount))
    .stateStyles({
      normal: { .opacity(1) },
      pressed: { .opacity(0.7) }
    })
    .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
    .onClick(() => {
      // 打开最早的一条未读灵感；只有真正打开的灵感才算已读。
      const ids = this.home.unviewedIdeaIds;
      if (ids.length > 0) requireActions(this.actions).logsController.openLogById(ids[ids.length - 1]);
    })
  }

  @Builder
  private todayCard() {
    FlashCard({ theme: this.theme, seed: 'today', frayed: true, folded: true }) {
      Row() {
        this.todayStat($r('sys.symbol.doc_text'), iconSemantic(this.theme, 'calendar'),
          `${this.home.todayLogCount + this.home.todayIdeaCount}`, tr('今日记录'))
        this.todayStat($r('sys.symbol.checkmark_circle'), iconSemantic(this.theme, 'task'),
          `${this.home.openTaskCount}`, tr('待办'))
        this.todayStat($r('sys.symbol.face_smiling'), iconSemantic(this.theme, 'emotion'),
          this.home.latestEmotionLevel !== undefined ? emotionEmoji(this.home.latestEmotionLevel) : '🙂',
          this.home.latestEmotionLevel !== undefined ? emotionName(this.home.latestEmotionLevel) : tr('还没有记录'))
      }.width('100%')
    }
  }

  @Builder
  private todayStat(icon: Resource, tint: string, value: string, label: string) {
    Row({ space: 6 }) {
      SymbolGlyph(icon).fontSize(16).fontColor([tint])
      Column({ space: 2 }) {
        Text(value).fontSize(TYPE_SECTION).fontFamily(statFontFamily()).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText)
        Text(label).fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted).maxLines(2)
      }.alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .accessibilityGroup(true)
    .accessibilityText(`${label} ${value}`)
  }

  @Builder
  private recentSection() {
    if (this.home.recentLogs.length > 0) {
      Column({ space: 12 }) {
        Column({ space: 2 }) {
          Text(tr('最近闪念')).fontSize(TYPE_SECTION).fontFamily(displayFontFamily()).fontColor(this.theme.themeText)
          HandUnderline({ seed: 'recent', color: iconSemantic(this.theme, 'logs'), widthVp: 72 })
        }.alignItems(HorizontalAlign.Start).width('100%')
        ForEach(this.home.recentLogs, (item: LogItem) => {
          RecordCard({
            theme: this.theme, feedback: this.feedback, actions: requireActions(this.actions), item: item,
            unread: this.home.unviewedIdeaIds.includes(item.id), sticky: item.category === Category.IDEA
          })
        }, (item: LogItem) => `${item.id}-${item.isFavorite === true}-${item.importance}-${item.content.length}`)
      }.width('100%')
    } else {
      EmptyState(this.theme, '✨', tr('今天还没有记录。'), tr('记下第一个念头'), () => this.logs.quickCategory = Category.IDEA)
    }
  }

  build() {
    this.homePage()
  }
}
