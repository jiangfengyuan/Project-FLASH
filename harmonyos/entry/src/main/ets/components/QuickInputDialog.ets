import { Category } from '../models/Models';
import { NavigationState, ThemeState, LogsState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import { BRAND, cardShadowColor, floatingSurface, hairlineColor, supportsBlurMaterial } from './CommonBuilders';

@Component
export struct QuickInputDialog {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink logs: LogsState;
  actions?: PageActions;

  @Builder
  private quickInputDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#66000000')
        .backdropBlur(supportsBlurMaterial() ? 12 : 0)
        .onClick(() => {
          this.logs.quickCategory = '';
          this.logs.quickText = '';
        })
      Column({ space: 14 }) {
        Text(this.logs.quickCategory === Category.IDEA ? '记录灵感' : '记录日志')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText).width('100%')
        TextArea({
          placeholder: this.logs.quickCategory === Category.IDEA ? '此刻的想法是…' : '闪过即留…',
          text: this.logs.quickText
        })
          .height(110).maxLength(140).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
          .backgroundColor(this.theme.themeControl).borderRadius(14)
          .onChange((value: string) => this.logs.quickText = value.slice(0, 140))
        Text(`${this.logs.quickText.length}/140`).fontSize(11).fontColor(this.theme.themeMuted).width('100%').textAlign(TextAlign.End)
        Row({ space: 10 }) {
          Button('取消').layoutWeight(1).height(44).fontColor(this.theme.themeMuted).backgroundColor(this.theme.themeControl)
            .onClick(() => {
              this.logs.quickCategory = '';
              this.logs.quickText = '';
            })
          Button('保存').layoutWeight(1).height(44).backgroundColor(BRAND)
            .enabled(this.logs.quickText.trim().length > 0).onClick(() => requireActions(this.actions).logsController.saveQuickCategory())
        }.width('100%')
      }.width(this.navigation.isMediumWindow ? 460 : '84%').padding(22).backgroundColor(floatingSurface(this.theme)).borderRadius(24)
        .backgroundBlurStyle(supportsBlurMaterial() ? BlurStyle.COMPONENT_ULTRA_THICK : BlurStyle.NONE)
        .border({ width: 0.5, color: hairlineColor(this.theme) })
        .shadow({ radius: 24, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 10 })
    }.width('100%').height('100%')
  }

  build() {
    this.quickInputDialog()
  }
}

