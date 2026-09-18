import { Category, colorTagName, LogItem } from '../models/Models';
import { NavigationState, ThemeState, LogsState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import { BRAND, FormGroup, FormRow, RADIUS_CARD } from './CommonBuilders';

@Component
export struct EditLogDialog {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink logs: LogsState;
  actions?: PageActions;

  private editingItem(): LogItem | undefined {
    return this.logs.logs.find((item: LogItem) => item.id === this.logs.editingLogId);
  }

  private close(): void {
    this.logs.editingLogId = '';
    this.logs.editText = '';
  }

  @Builder
  private editLogDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#66000000').onClick(() => this.close())
      Column({ space: 14 }) {
        Row() {
          Button('关闭', { type: ButtonType.Normal })
            .fontSize(14).fontColor(this.theme.themeMuted).backgroundColor(Color.Transparent)
            .onClick(() => this.close())
          Blank()
          Text('编辑记录').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
          Blank()
          Button('保存', { type: ButtonType.Normal })
            .fontSize(14).fontColor(Color.White).backgroundColor(BRAND).height(36)
            .enabled(this.logs.editText.trim().length > 0)
            .onClick(() => requireActions(this.actions).logsController.saveEditedLog())
        }.width('100%')

        if (this.logs.editText.trim().length === 0) {
          Text('内容不能为空，请输入后再保存').fontSize(12).fontColor('#B42318').width('100%')
        }

        FormGroup(this.theme, '正文')
        TextArea({ placeholder: '记录内容', text: this.logs.editText })
          .height(130).maxLength(10000).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
          .backgroundColor(this.theme.themeControl).borderRadius(14)
          .onChange((value: string) => this.logs.editText = value.slice(0, 10000))
        Text(`${this.logs.editText.length}/10000`).fontSize(11).fontColor(this.theme.themeMuted).width('100%').textAlign(TextAlign.End)

        FormGroup(this.theme, '标签、重要度与日期')
        Column() {
          FormRow(this.theme, '类型', this.editingItem()?.category === Category.IDEA ? '灵感' : '日志')
          FormRow(this.theme, '标签', colorTagName(this.editingItem()?.colorTag ?? ''))
          FormRow(this.theme, '重要度', `${this.editingItem()?.importance ?? 0}`)
          FormRow(this.theme, '日期', this.editingItem()?.recordDate ?? '')
        }.width('100%')
        Text('标签、重要度与日期沿用原记录，编辑仅修改正文。')
          .fontSize(11).fontColor(this.theme.themeMuted).width('100%')
      }
      .width(this.navigation.isMediumWindow ? 520 : '88%')
      .padding(22)
      .backgroundColor(this.theme.themeSurface)
      .borderRadius(RADIUS_CARD)
    }.width('100%').height('100%')
  }

  build() {
    this.editLogDialog()
  }
}
