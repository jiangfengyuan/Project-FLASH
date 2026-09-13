import { NavigationState, ThemeState, LogsState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
const BRAND = '#6C5CE7';

@Component
export struct EditLogDialog {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink logs: LogsState;
  actions?: PageActions;

  @Builder
  private editLogDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#66000000').onClick(() => {
        this.logs.editingLogId = '';
        this.logs.editText = '';
      })
      Column({ space: 14 }) {
        Text('编辑记录').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText).width('100%')
        TextArea({ placeholder: '记录内容', text: this.logs.editText })
          .height(130).maxLength(10000).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
          .backgroundColor(this.theme.themeControl).borderRadius(14)
          .onChange((value: string) => this.logs.editText = value.slice(0, 10000))
        Text(`${this.logs.editText.length}/10000`).fontSize(11).fontColor(this.theme.themeMuted).width('100%').textAlign(TextAlign.End)
        Row({ space: 10 }) {
          Button('取消').layoutWeight(1).height(42).fontColor(this.theme.themeMuted).backgroundColor(this.theme.themeControl)
            .onClick(() => {
              this.logs.editingLogId = '';
              this.logs.editText = '';
            })
          Button('保存修改').layoutWeight(1).height(42).backgroundColor(BRAND)
            .enabled(this.logs.editText.trim().length > 0).onClick(() => requireActions(this.actions).logsController.saveEditedLog())
        }.width('100%')
      }.width(this.navigation.isMediumWindow ? 520 : '88%').padding(22).backgroundColor(this.theme.themeSurface).borderRadius(24)
    }.width('100%').height('100%')
  }

  build() {
    this.editLogDialog()
  }
}

