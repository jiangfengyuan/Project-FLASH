import { Category } from '../models/Models';
import { isTypedTrailingReturn } from '../data/AppEntry';
import { tr } from '../data/I18n';
import { HapticEvent, playHaptic } from '../data/Haptics';
import { NavigationState, ThemeState, LogsState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  SegmentedControl, floatingSurface, hairlineColor, scrimColor, dockShadowColor, brandFill, onBrandFill, dangerText,
  DIALOG_WIDTH_FORM, RADIUS_FOCUS, RADIUS_FIELD, TYPE_CAPTION, TYPE_BODY, TOUCH_MIN, ELEVATED_SHADOW_RADIUS, pageGutter
} from './CommonBuilders';

const MAX_CAPTURE = 100000;

/**
 * 快速记录面板（对齐 iOS）：底部硫酸纸面板，默认灵感可切日志；回车即存，粘贴多行保留换行；
 * 保存成功关闭并有触感，失败保留输入；未提交的内容留作草稿。系统分享的文字由用户确认后才保存。
 */
@Component
export struct QuickInputDialog {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink logs: LogsState;
  actions?: PageActions;

  aboutToAppear(): void {
    if (!this.logs.quickShared && this.logs.quickText === '') {
      this.logs.quickText = requireActions(this.actions).controller.draft();
    }
  }

  private dismiss(): void {
    if (!this.logs.quickShared) requireActions(this.actions).controller.saveDraft(this.logs.quickText);
    this.logs.quickShared = false;
    this.logs.quickCategory = '';
    this.logs.quickText = '';
  }

  private async save(): Promise<void> {
    const actions = requireActions(this.actions);
    const shared = this.logs.quickShared;
    if (this.logs.quickText.trim() === '' || this.logs.quickText.length > MAX_CAPTURE) return;
    await actions.logsController.saveQuickCategory();
    if (this.logs.quickCategory === '') {
      playHaptic(HapticEvent.SUCCESS);
      if (!shared) actions.controller.saveDraft('');
    }
  }

  private remainingHint(): string {
    const remaining = MAX_CAPTURE - this.logs.quickText.length;
    if (remaining < 0) return tr('超出 {0} 字', -remaining);
    if (remaining <= MAX_CAPTURE / 10) return tr('还可输入 {0} 字', remaining);
    return '';
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column().width('100%').height('100%').backgroundColor(scrimColor(this.theme))
        .onClick(() => this.dismiss())
      Column({ space: 12 }) {
        SegmentedControl(this.theme, [tr('灵感'), tr('日志')], this.logs.quickCategory === Category.LOG ? 1 : 0,
          (index: number) => this.logs.quickCategory = index === 1 ? Category.LOG : Category.IDEA)
        Row({ space: 12 }) {
          TextArea({ placeholder: tr('现在想记录什么？'), text: this.logs.quickText })
            .layoutWeight(1).constraintSize({ minHeight: 52, maxHeight: 140 })
            .fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
            .backgroundColor(this.theme.themeControl).borderRadius(RADIUS_FIELD)
            .defaultFocus(true)
            .onChange((value: string) => {
              if (isTypedTrailingReturn(this.logs.quickText, value)) {
                this.save();
              } else {
                this.logs.quickText = value;
              }
            })
          Button('↑').width(52).height(52).fontColor(onBrandFill(this.theme)).backgroundColor(brandFill(this.theme))
            .accessibilityText(tr('保存'))
            .enabled(!this.logs.busy && this.logs.quickText.trim().length > 0 && this.logs.quickText.length <= MAX_CAPTURE)
            .onClick(() => this.save())
        }.width('100%').alignItems(VerticalAlign.Bottom)
        if (this.remainingHint() !== '') {
          Text(this.remainingHint()).fontSize(TYPE_CAPTION).width('100%')
            .fontColor(this.logs.quickText.length > MAX_CAPTURE ? dangerText(this.theme) : this.theme.themeMuted)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: DIALOG_WIDTH_FORM })
      .padding({ left: pageGutter(), right: pageGutter(), top: 20, bottom: 20 + this.navigation.navigationBarHeight })
      .backgroundColor(floatingSurface(this.theme))
      .borderRadius({ topLeft: RADIUS_FOCUS, topRight: RADIUS_FOCUS })
      .border({ width: { top: 0.75 }, color: hairlineColor(this.theme) })
      .shadow({ radius: ELEVATED_SHADOW_RADIUS, color: dockShadowColor(this.theme), offsetY: -6 })
    }.width('100%').height('100%')
  }
}
