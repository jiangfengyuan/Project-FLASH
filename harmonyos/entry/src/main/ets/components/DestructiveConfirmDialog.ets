import { NavigationState, ThemeState, FeedbackState, DeleteKind } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import { cardShadowColor, floatingSurface, hairlineColor, supportsBlurMaterial } from './CommonBuilders';

@Component
export struct DestructiveConfirmDialog {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;

  @Builder
  private destructiveConfirmDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#66000000')
        .backdropBlur(supportsBlurMaterial() ? 12 : 0)
        .onClick(() => requireActions(this.actions).controller.cancelDestructiveAction())
      Column({ space: 14 }) {
        Text(requireActions(this.actions).controller.destructiveTitle()).fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText).width('100%')
        Text(requireActions(this.actions).controller.destructiveMessage()).fontSize(13).fontColor(this.theme.themeMuted).lineHeight(20).width('100%')
        Row({ space: 10 }) {
          Button('取消').layoutWeight(1).height(44).fontColor(this.theme.themeMuted).backgroundColor(this.theme.themeControl)
            .onClick(() => requireActions(this.actions).controller.cancelDestructiveAction())
          Button(this.feedback.destructive?.kind === DeleteKind.ALL ? '确认清空' : '确认删除').layoutWeight(1).height(44)
            .fontColor(Color.White).backgroundColor('#D92D20').onClick(() => requireActions(this.actions).controller.confirmDestructiveAction())
        }.width('100%')
      }.width(this.navigation.isMediumWindow ? 460 : '84%').padding(22).backgroundColor(floatingSurface(this.theme)).borderRadius(24)
        .backgroundBlurStyle(supportsBlurMaterial() ? BlurStyle.COMPONENT_ULTRA_THICK : BlurStyle.NONE)
        .border({ width: 0.5, color: hairlineColor(this.theme) })
        .shadow({ radius: 24, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 10 })
    }.width('100%').height('100%')
  }

  build() {
    this.destructiveConfirmDialog()
  }
}

