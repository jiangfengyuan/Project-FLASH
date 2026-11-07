// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { dayString, shortDay } from '../data/DateUtils';
import { tr } from '../data/I18n';
import { HapticEvent, playHaptic } from '../data/Haptics';
import { EmotionRecord, emotionEmoji, emotionName, SubEmotion, subEmotionName } from '../models/Models';
import { ThemeState, EmotionState, FeedbackState, DeleteKind } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  FlashCard, EmptyState, FilterChip, HandUnderline, TornDivider, brandText, brandFill, onBrandFill, dangerText, hairlineColor, emotionColor, moodColor,
  chipSelected, chipSelectedText, displayFontFamily, pageGutter, statusText, DOCK_CLEARANCE, TOUCH_MIN, TYPE_TITLE,
  motionDuration, MOTION_PRESS,
  TYPE_SECTION, TYPE_GROUP, TYPE_BODY, TYPE_SECONDARY, TYPE_CAPTION
} from '../components/CommonBuilders';

// 「当前状态」快捷输入：chip 一键填入，自由文本可覆盖（≤50 字，随情绪记录保存）。
const QUICK_STATUSES: string[] = ['疲惫', '专注', '放松'];
const WEEKDAY_LABELS: string[] = ['一', '二', '三', '四', '五', '六', '日'];

// 保存成功礼花粒子：固定编排，避免每次渲染重建。
interface FlashParticle {
  emoji: string;
  dx: number;
  dist: number;
}

const FLASH_PARTICLES: FlashParticle[] = [
  { emoji: '✨', dx: -56, dist: 1.0 },
  { emoji: '🎉', dx: -20, dist: 0.8 },
  { emoji: '✨', dx: 16, dist: 1.1 },
  { emoji: '💜', dx: 52, dist: 0.9 },
  { emoji: '✨', dx: -36, dist: 0.6 },
  { emoji: '🎈', dx: 34, dist: 0.7 }
];

const SAVED_FLASH_MS = 600;

@Component
export struct EmotionPage {
  @ObjectLink theme: ThemeState;
  @ObjectLink @Watch('onEmotionMutated') emotion: EmotionState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;
  // 作为一级 Tab 时带标题并为底栏留白。
  asTab: boolean = false;
  @State private flashVisible: boolean = false;
  @State private flashProgress: number = 1;
  private lastFlash: number = 0;

  // EmotionState 变化频繁（滑杆逐点触发），只在保存信号递增时播动效。
  private onEmotionMutated(): void {
    if (this.emotion.savedFlash === this.lastFlash) return;
    this.lastFlash = this.emotion.savedFlash;
    this.playSavedFeedback();
  }

  private playSavedFeedback(): void {
    this.flashVisible = true;
    this.flashProgress = 0;
    this.getUIContext().animateTo({ duration: motionDuration(SAVED_FLASH_MS), curve: Curve.EaseOut }, () => {
      this.flashProgress = 1;
    });
    setTimeout(() => {
      this.flashVisible = false;
    }, motionDuration(SAVED_FLASH_MS));
  }

  private intensityLabel(item: EmotionRecord): string {
    return item.intensity ? tr('强度 {0}', item.intensity) : '';
  }

  private emotionSymbol(level: number): Resource {
    if (level < 0) return $r('sys.symbol.face_sading');
    if (level > 0) return $r('sys.symbol.face_laughing');
    return $r('sys.symbol.face_smiling');
  }

  @Builder
  private emotionPage() {
    Scroll() {
      Column({ space: 16 }) {
        if (this.asTab) {
          Text(tr('情绪')).fontSize(TYPE_TITLE).fontFamily(displayFontFamily()).fontWeight(FontWeight.Medium)
            .fontColor(this.theme.themeText).width('100%').padding({ top: 12 })
        }
        FlashCard({ theme: this.theme, seed: 'emotion-hero', frayed: true, space: 14 }) {
          Text(emotionEmoji(this.emotion.emotionLevel)).fontSize(64)
          Text(emotionName(this.emotion.emotionLevel)).fontSize(TYPE_SECTION).fontFamily(displayFontFamily())
            .fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
          HandUnderline({ seed: 'mood', color: moodColor(this.theme, this.emotion.emotionLevel), widthVp: 64 })
          Slider({ value: this.emotion.emotionLevel, min: -3, max: 3, step: 1, style: SliderStyle.OutSet })
            .blockColor(brandText(this.theme)).selectedColor(moodColor(this.theme, this.emotion.emotionLevel)).trackColor(this.theme.themeControl)
            .accessibilityText(emotionName(this.emotion.emotionLevel))
            .onChange((value: number) => {
              const next = Math.round(value);
              if (next !== this.emotion.emotionLevel) playHaptic(HapticEvent.SELECTION);
              this.emotion.emotionLevel = next;
            })
          Row({ space: 4 }) {
            Text(tr('强度')).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).margin({ right: 8 })
            ForEach([1, 2, 3, 4, 5], (value: number) => {
              Stack() {
                Circle().width(16).height(16)
                  .fill(this.emotion.emotionIntensity >= value ? brandText(this.theme) : this.theme.themeControl)
                  .stroke(hairlineColor(this.theme)).strokeWidth(1)
              }
              .width(TOUCH_MIN).height(TOUCH_MIN)
              .accessibilityText(tr('强度 {0}', value))
              .onClick(() => requireActions(this.actions).emotionController.selectIntensity(value))
            }, (value: number) => `${value}`)
          }.width('100%')
        }

        if (this.emotion.emotionLevel < 0) {
          FlashCard({ theme: this.theme, space: 12 }) {
            Text(tr('更接近哪种感受？')).fontSize(TYPE_GROUP).fontColor(this.theme.themeText).width('100%')
            Row({ space: 8 }) {
              this.subEmotionChip(SubEmotion.SAD)
              this.subEmotionChip(SubEmotion.ANGRY)
              this.subEmotionChip(SubEmotion.UNCOMFORTABLE)
            }.width('100%')
          }
        }

        FlashCard({ theme: this.theme, space: 12 }) {
          Text(tr('当前状态（可选）')).fontSize(TYPE_GROUP).fontColor(this.theme.themeText).width('100%')
          Row({ space: 8 }) {
            ForEach(QUICK_STATUSES, (status: string) => {
              FilterChip(this.theme, tr(status), this.emotion.emotionStatus === tr(status),
                () => this.emotion.emotionStatus = this.emotion.emotionStatus === tr(status) ? '' : tr(status))
            }, (status: string) => status)
          }.width('100%')
          TextInput({ placeholder: tr('自定义状态，如：期待、平静'), text: this.emotion.emotionStatus })
            .height(44).maxLength(50).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
            .backgroundColor(this.theme.themeControl).borderRadius(14)
            .onChange((value: string) => this.emotion.emotionStatus = value.slice(0, 50))
        }

        TextArea({ placeholder: tr('想补充些什么？（可选）'), text: this.emotion.emotionNote })
          .height(90).maxLength(2000).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
          .backgroundColor(this.theme.themeSurface).borderRadius(16)
          .border({ width: 0.5, color: hairlineColor(this.theme) })
          .onChange((value: string) => this.emotion.emotionNote = value.slice(0, 2000))
        Button(this.emotion.busy ? tr('保存中…') : tr('记录情绪')).width('100%').height(46)
          .fontColor(onBrandFill(this.theme)).backgroundColor(brandFill(this.theme))
          .enabled(!this.emotion.busy)
          .onClick(() => {
            playHaptic(HapticEvent.SUCCESS);
            requireActions(this.actions).emotionController.saveEmotion();
          })

        this.weekRowCard()
        this.weekTrendCard()

        if (this.emotion.emotions.length > 0) {
          FlashCard({ theme: this.theme, space: 4 }) {
            Text(tr('近期记录')).fontSize(TYPE_GROUP).fontFamily(displayFontFamily()).fontColor(this.theme.themeText).width('100%')
            ForEach(this.emotion.emotions.slice(0, 20), (item: EmotionRecord) => {
              Row({ space: 12 }) {
                Text(emotionEmoji(item.level)).fontSize(24)
                Column({ space: 4 }) {
                  Text(`${emotionName(item.level)} ${subEmotionName(item.subEmotion)} ${this.intensityLabel(item)}`).fontSize(TYPE_BODY).fontColor(this.theme.themeText)
                  Text(this.emotionSubtitle(item)).fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted).maxLines(1)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                SymbolGlyph(item.isFavorite === true ? $r('sys.symbol.star_fill') : $r('sys.symbol.star')).fontSize(18)
                  .fontColor([item.isFavorite === true ? statusText(this.theme, 'warn') : this.theme.themeMuted])
                  .width(TOUCH_MIN).height(TOUCH_MIN)
                  .accessibilityText(item.isFavorite === true ? tr('取消收藏') : tr('收藏'))
                  .onClick(() => requireActions(this.actions).emotionController.toggleFavorite(item))
                Button(tr('删除'), { type: ButtonType.Normal }).fontSize(TYPE_CAPTION).fontColor(dangerText(this.theme))
                  .backgroundColor(this.theme.themeDanger).onClick(() => this.feedback.destructive = { kind: DeleteKind.EMOTION, id: item.id })
              }.width('100%').padding({ top: 8, bottom: 8 })
            }, (item: EmotionRecord) => `${item.id}-${item.isFavorite === true}`)
          }
        } else {
          EmptyState(this.theme, '🌱', tr('还没有情绪记录，从当下的感受开始'))
        }
      }.width('100%').padding({ left: pageGutter(), right: pageGutter(), bottom: this.asTab ? DOCK_CLEARANCE : 30 })
    }.width('100%').height('100%')
  }

  private emotionSubtitle(item: EmotionRecord): string {
    const parts: string[] = [shortDay(item.recordDate)];
    if (item.status) parts.push(item.status);
    if (item.note) parts.push(item.note);
    return parts.join(' · ');
  }

  // 本周情绪趋势：近 7 天日均值轻量 sparkline（复用 EmotionController 的日聚合 memo）。
  @Builder
  private weekRowCard() {
    FlashCard({ theme: this.theme, seed: 'emotion-week', space: 8 }) {
      Text(tr('本周趋势')).fontSize(TYPE_GROUP).fontFamily(displayFontFamily()).fontColor(this.theme.themeText).width('100%')
      Row() {
        ForEach(requireActions(this.actions).emotionController.currentWeekDays(), (day: string, index: number) => {
          Column({ space: 4 }) {
            if (requireActions(this.actions).emotionController.latestLevel(day) !== undefined) {
              Text(emotionEmoji(requireActions(this.actions).emotionController.latestLevel(day) as number)).fontSize(22)
            } else {
              Circle().width(22).height(22).fillOpacity(0).stroke(hairlineColor(this.theme)).strokeWidth(1).strokeDashArray([3, 3])
            }
            Text(tr(WEEKDAY_LABELS[index])).fontSize(TYPE_CAPTION)
              .fontColor(day === dayString() ? brandText(this.theme) : this.theme.themeMuted)
          }.layoutWeight(1)
        }, (day: string) => day)
      }.width('100%')
      TornDivider({ theme: this.theme, seed: 'emotion-week-divider' })
      Text(tr(requireActions(this.actions).emotionController.weekSummary())).fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted).width('100%')
    }
  }

  @Builder
  private weekTrendCard() {
    FlashCard({ theme: this.theme, space: 8 }) {
      Text(tr('本周情绪')).fontSize(TYPE_GROUP).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
      Text(tr('近 7 天日均值 · — 表示当日未记录')).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
      Row({ space: 6 }) {
        ForEach(requireActions(this.actions).emotionController.lastSevenDays(), (day: string) => {
          Column({ space: 4 }) {
            Column() {
              if (requireActions(this.actions).emotionController.dayAverage(day) !== undefined) {
                Row()
                  .width('55%')
                  .height(this.trendBarHeight(day))
                  .borderRadius(4)
                  .backgroundColor(emotionColor(this.theme, Math.round(requireActions(this.actions).emotionController.dayAverage(day)!)))
              }
            }
            .width('100%')
            .height(64)
            .justifyContent(FlexAlign.End)
            .alignItems(HorizontalAlign.Center)
            Text(`${Number(day.slice(8, 10))}`).fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted)
            Text(requireActions(this.actions).emotionController.dayEmotionLabel(day))
              .fontSize(TYPE_CAPTION).fontColor(this.theme.themeText)
          }.layoutWeight(1).alignItems(HorizontalAlign.Center)
        }, (day: string) => day)
      }
      .width('100%')
      .accessibilityGroup(true)
      .accessibilityText(tr('近 7 天情绪日均值柱状图'))
    }
  }

  private trendBarHeight(day: string): number {
    const average = requireActions(this.actions).emotionController.dayAverage(day);
    if (average === undefined) return 0;
    // -3..+3 映射到 8..64，0（中性）居中偏上。
    return Math.max(8, Math.round((average + 3) / 6 * 64));
  }

  // 保存成功差异化反馈：正面礼花粒子上升，负面柔和涟漪扩散，≤600ms。
  @Builder
  private savedFeedbackOverlay() {
    if (this.emotion.savedLevel > 0) {
      Stack() {
        ForEach(FLASH_PARTICLES, (particle: FlashParticle) => {
          Text(particle.emoji)
            .fontSize(24)
            .translate({ x: particle.dx * this.flashProgress, y: -140 * this.flashProgress * particle.dist })
            .opacity(1 - this.flashProgress)
        }, (particle: FlashParticle) => particle.emoji + `${particle.dx}`)
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)
    } else if (this.emotion.savedLevel < 0) {
      Column()
        .width(160)
        .height(160)
        .borderRadius(80)
        .border({ width: 2, color: emotionColor(this.theme, -1) })
        .scale({ x: 0.3 + 0.7 * this.flashProgress, y: 0.3 + 0.7 * this.flashProgress })
        .opacity(0.6 * (1 - this.flashProgress))
        .hitTestBehavior(HitTestMode.None)
    } else {
      SymbolGlyph($r('sys.symbol.checkmark_circle'))
        .fontSize(56)
        .fontColor([emotionColor(this.theme, 0)])
        .opacity(1 - this.flashProgress)
        .hitTestBehavior(HitTestMode.None)
    }
  }

  @Builder
  private subEmotionChip(value: string) {
    Text(subEmotionName(value)).fontSize(TYPE_SECONDARY)
      .fontColor(this.emotion.selectedSubEmotion === value ? chipSelectedText(this.theme) : this.theme.themeText)
      .textAlign(TextAlign.Center).layoutWeight(1).height(44)
      .backgroundColor(this.emotion.selectedSubEmotion === value ? chipSelected(this.theme) : this.theme.themeControl).borderRadius(22)
      .stateStyles({
        normal: { .opacity(1) },
        pressed: { .opacity(0.7) }
      })
      .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
      .onClick(() => this.emotion.selectedSubEmotion = value)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      this.emotionPage()
      if (this.flashVisible) {
        this.savedFeedbackOverlay()
      }
    }.width('100%').layoutWeight(1)
  }
}
