import { ThemeState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import { cardShadowColor, floatingSurface, hairlineColor, supportsBlurMaterial } from './CommonBuilders';
const BRAND = '#6C5CE7';

@Component
export struct WelcomeOverlay {
  @ObjectLink theme: ThemeState;
  actions?: PageActions;

  @Builder
  private welcomeOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#99000000')
        .backdropBlur(supportsBlurMaterial() ? 16 : 0)
      Column({ space: 16 }) {
        Text('⚡').fontSize(56).accessibilityLevel('no')
        Text('欢迎来到 Flash Aero').fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText)
        Text('捕捉日志、灵感与情绪，让每一次闪念都有落点。')
          .fontSize(14).fontColor(this.theme.themeMuted).textAlign(TextAlign.Center).lineHeight(22)
        Button('开始使用').width('100%').height(46).backgroundColor(BRAND).onClick(() => requireActions(this.actions).controller.finishWelcome())
      }.width('84%').padding(24).backgroundColor(floatingSurface(this.theme)).borderRadius(26)
        .backgroundBlurStyle(supportsBlurMaterial() ? BlurStyle.COMPONENT_ULTRA_THICK : BlurStyle.NONE)
        .border({ width: 0.5, color: hairlineColor(this.theme) })
        .shadow({ radius: 28, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 12 })
    }.width('100%').height('100%')
  }

  build() {
    this.welcomeOverlay()
  }
}

