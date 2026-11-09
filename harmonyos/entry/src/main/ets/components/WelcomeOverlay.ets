// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { NavigationState, SettingsState, ThemeState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  ONBOARDING_STEPS, OnboardingRow, OnboardingStepContent, isFirstStep, isLastStep, nextStep, previousStep,
  stepAnnouncement
} from '../state/Onboarding';
import {
  BRAND, FlashCard, SegmentedControl, brandText, hairlineColor, iconSemantic, motionDuration,
  CARD_INSET, CONTENT_MAX_CENTERED, ICON_COLUMN, MOTION_PAGE, PAGE_GUTTER, TOUCH_MIN,
  TYPE_BODY, TYPE_SECONDARY, TYPE_TITLE
} from './CommonBuilders';

// 首次安装的欢迎与新手引导（也可从「设置 › 辅助功能」重新打开），覆盖全屏。
// 交互：每步可「跳过」；左右轻扫或「上一步 / 下一步」翻页；系统返回键回到上一步（Index.onBackPress）；
// 最后一步就地设置外观与减少动态效果，立即生效。
// 读屏：步骤指示朗读「第 n 步，共 4 步」，说明行合并为一句，装饰图标不朗读。
// 减少动态效果时翻页动画时长归零（motionDuration）。
@Component
export struct WelcomeOverlay {
  @ObjectLink theme: ThemeState;
  @ObjectLink settings: SettingsState;
  @ObjectLink navigation: NavigationState;
  actions?: PageActions;

  private finish(): void {
    requireActions(this.actions).controller.finishWelcome();
  }

  private symbol(key: string): Resource {
    switch (key) {
      case 'bolt': return $r('sys.symbol.bolt');
      case 'lightbulb': return $r('sys.symbol.lightbulb');
      case 'record': return $r('sys.symbol.doc_text');
      case 'emotion': return $r('sys.symbol.face_smiling');
      case 'calendar': return $r('sys.symbol.calendar');
      case 'review': return $r('sys.symbol.clock_arrow_2_circlepath');
      case 'device': return $r('sys.symbol.house');
      case 'backup': return $r('sys.symbol.folder');
      case 'caution': return $r('sys.symbol.exclamationmark_circle');
      default: return $r('sys.symbol.slider_vertical_3');
    }
  }

  private rowTint(key: string): string {
    switch (key) {
      case 'record': return iconSemantic(this.theme, 'logs');
      case 'emotion': return iconSemantic(this.theme, 'emotion');
      case 'calendar': return iconSemantic(this.theme, 'calendar');
      case 'review': return iconSemantic(this.theme, 'appearance');
      default: return iconSemantic(this.theme, 'safe');
    }
  }

  private themeModeIndex(): number {
    if (this.theme.themeMode === 'dark') return 1;
    if (this.theme.themeMode === 'system') return 2;
    return 0;
  }

  @Builder
  private infoRow(row: OnboardingRow) {
    Row({ space: 12 }) {
      SymbolGlyph(this.symbol(row.icon)).fontSize(20).fontColor([this.rowTint(row.icon)]).width(ICON_COLUMN)
      Column({ space: 2 }) {
        Text(row.title).fontSize(TYPE_BODY).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
        Text(row.detail).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).lineHeight(19).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 8, bottom: 8 })
    .accessibilityGroup(true)
    .accessibilityText(`${row.title}，${row.detail}`)
  }

  @Builder
  private preferencesCard() {
    FlashCard({ theme: this.theme, space: 12 }) {
      Text('外观').fontSize(TYPE_BODY).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
      SegmentedControl(this.theme, ['浅色', '深色', '跟随系统'], this.themeModeIndex(),
        (index: number) => requireActions(this.actions).setThemeMode(['light', 'dark', 'system'][index]))
      Divider().color(hairlineColor(this.theme))
      Row({ space: 12 }) {
        Column({ space: 2 }) {
          Text('减少动态效果').fontSize(TYPE_BODY).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          Text('关闭页面切换、弹出与按压缩放动画。').fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.settings.reduceMotion })
          .accessibilityText('减少动态效果')
          .onChange((value: boolean) => {
            requireActions(this.actions).controller.setReduceMotion(value);
          })
      }.width('100%').constraintSize({ minHeight: TOUCH_MIN })
      Divider().color(hairlineColor(this.theme))
      Text('文字大小跟随系统的字体大小设置。').fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
    }
  }

  @Builder
  private stepPage(step: OnboardingStepContent) {
    Scroll() {
      Column({ space: 12 }) {
        // 图标仅作装饰，信息由标题承载
        Stack() {
          SymbolGlyph(this.symbol(step.icon)).fontSize(step.key === 'welcome' ? 56 : 40).fontColor([brandText(this.theme)])
        }
        .width(step.key === 'welcome' ? 112 : 88)
        .height(step.key === 'welcome' ? 112 : 88)
        .borderRadius(step.key === 'welcome' ? 56 : 44)
        .backgroundColor(this.theme.themeTint)
        .margin({ top: step.key === 'welcome' ? 40 : 8, bottom: 8 })
        .accessibilityLevel('no')
        Text(step.title).fontSize(TYPE_TITLE).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText)
          .textAlign(TextAlign.Center)
        Text(step.subtitle).fontSize(TYPE_BODY).fontColor(this.theme.themeMuted).lineHeight(22)
          .textAlign(TextAlign.Center)
        if (step.rows.length > 0) {
          FlashCard({ theme: this.theme, space: 0 }) {
            ForEach(step.rows, (row: OnboardingRow) => {
              this.infoRow(row)
            }, (row: OnboardingRow) => row.title)
          }
          .margin({ top: 12 })
        }
        if (step.key === 'preferences') {
          Column() {
            this.preferencesCard()
          }.width('100%').margin({ top: 12 })
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: CONTENT_MAX_CENTERED })
      .padding({ left: PAGE_GUTTER, right: PAGE_GUTTER, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
  }

  @Builder
  private stepIndicator() {
    Row({ space: 6 }) {
      ForEach(ONBOARDING_STEPS, (step: OnboardingStepContent, index: number) => {
        Row()
          .width(index === this.settings.welcomeStep ? 20 : 8)
          .height(8)
          .borderRadius(4)
          .backgroundColor(index === this.settings.welcomeStep ? BRAND : this.theme.themeControl)
          .border({ width: 0.5, color: hairlineColor(this.theme) })
      }, (step: OnboardingStepContent) => step.key)
    }
    .accessibilityGroup(true)
    .accessibilityText(stepAnnouncement(this.settings.welcomeStep))
    .animation({ duration: motionDuration(200), curve: Curve.EaseOut })
  }

  build() {
    Column() {
      // 顶部：跳过（最后一步不显示，由「开始使用」完成）
      Row() {
        Blank()
        if (!isLastStep(this.settings.welcomeStep)) {
          Text('跳过')
            .fontSize(TYPE_BODY)
            .fontColor(this.theme.themeMuted)
            .height(TOUCH_MIN)
            .padding({ left: 12 })
            .accessibilityText('跳过介绍，直接开始使用')
            .stateStyles({
              normal: { .opacity(1) },
              pressed: { .opacity(0.6) }
            })
            .onClick(() => this.finish())
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: PAGE_GUTTER, right: PAGE_GUTTER })

      Swiper() {
        ForEach(ONBOARDING_STEPS, (step: OnboardingStepContent) => {
          this.stepPage(step)
        }, (step: OnboardingStepContent) => step.key)
      }
      .index(this.settings.welcomeStep)
      .loop(false)
      .indicator(false)
      .duration(motionDuration(MOTION_PAGE))
      .curve(Curve.EaseOut)
      .onChange((index: number) => this.settings.welcomeStep = index)
      .layoutWeight(1)
      .width('100%')

      // 底部：步骤指示居中（Stack），上一步 / 下一步贴左右页边距
      Stack() {
        this.stepIndicator()
        Row() {
          if (!isFirstStep(this.settings.welcomeStep)) {
            Button('上一步', { type: ButtonType.Normal })
              .height(TOUCH_MIN)
              .fontColor(this.theme.themeText)
              .backgroundColor(this.theme.themeControl)
              .borderRadius(TOUCH_MIN / 2)
              .onClick(() => this.settings.welcomeStep = previousStep(this.settings.welcomeStep))
          }
          Blank()
          Button(isLastStep(this.settings.welcomeStep) ? '开始使用' : '下一步', { type: ButtonType.Normal })
            .height(TOUCH_MIN)
            .fontColor(Color.White)
            .backgroundColor(BRAND)
            .borderRadius(TOUCH_MIN / 2)
            .onClick(() => {
              if (isLastStep(this.settings.welcomeStep)) {
                this.finish();
              } else {
                this.settings.welcomeStep = nextStep(this.settings.welcomeStep);
              }
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: PAGE_GUTTER, right: PAGE_GUTTER, top: CARD_INSET, bottom: CARD_INSET + this.navigation.navigationBarHeight })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.themeBackground)
  }
}
