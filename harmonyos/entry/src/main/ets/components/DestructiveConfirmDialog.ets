import { NavigationState, ThemeState, FeedbackState, DeleteKind } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';

@Component
export struct DestructiveConfirmDialog {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;

  @Builder
  private destructiveConfirmDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#66000000').onClick(() => requireActions(this.actions).controller.cancelDestructiveAction())
      Column({ space: 14 }) {
        Text(requireActions(this.actions).controller.destructiveTitle()).fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText).width('100%')
        Text(requireActions(this.actions).controller.destructiveMessage()).fontSize(13).fontColor(this.theme.themeMuted).lineHeight(20).width('100%')
        Row({ space: 10 }) {
          Button('取消').layoutWeight(1).height(42).fontColor(this.theme.themeMuted).backgroundColor(this.theme.themeControl)
            .onClick(() => requireActions(this.actions).controller.cancelDestructiveAction())
          Button(this.feedback.destructive?.kind === DeleteKind.ALL ? '确认清空' : '确认删除').layoutWeight(1).height(42)
            .fontColor(Color.White).backgroundColor('#D92D20').onClick(() => requireActions(this.actions).controller.confirmDestructiveAction())
        }.width('100%')
      }.width(this.navigation.isMediumWindow ? 460 : '84%').padding(22).backgroundColor(this.theme.themeSurface).borderRadius(24)
    }.width('100%').height('100%')
  }

  build() {
    this.destructiveConfirmDialog()
  }
}

