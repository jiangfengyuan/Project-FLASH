import { Category, COLOR_TAGS, colorTagName, LogItem } from '../models/Models';
import { NavigationState, ThemeState, LogsState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import { BRAND, FilterChip, FormGroup, FormRow, RADIUS_CARD, SegmentedControl } from './CommonBuilders';

@Component
export struct EditLogDialog {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink logs: LogsState;
  actions?: PageActions;

  private close(): void {
    requireActions(this.actions).logsController.requestCloseEdit();
  }

  @Builder
  private editLogDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#66000000').onClick(() => this.close())
      Scroll() {
        Column({ space: 14 }) {
          Row() {
            Button('关闭', { type: ButtonType.Normal })
              .fontSize(14).fontColor(this.theme.themeMuted).backgroundColor(Color.Transparent)
              .onClick(() => this.close())
            Blank()
            Text('编辑记录').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
            Blank()
            Button(this.logs.busy ? '保存中…' : '保存', { type: ButtonType.Normal })
              .fontSize(14).fontColor(Color.White).backgroundColor(BRAND).height(44)
              .enabled(!this.logs.busy && requireActions(this.actions).logsController.editValidation() === '')
              .onClick(() => requireActions(this.actions).logsController.saveEditedLog())
          }.width('100%')

          if (this.logs.editDiscard) {
            Text('放弃未保存的修改？').fontSize(14).fontColor(this.theme.themeText)
            Row({ space: 12 }) {
              Button('继续编辑').onClick(() => this.logs.editDiscard = false)
              Button('放弃修改').onClick(() => requireActions(this.actions).logsController.closeEdit())
            }
          }
          if (this.logs.editError || requireActions(this.actions).logsController.editValidation()) {
            Text(this.logs.editError || requireActions(this.actions).logsController.editValidation())
              .fontSize(12).fontColor('#B42318').width('100%')
          }

          FormGroup(this.theme, '正文与类型')
          TextArea({ placeholder: '记录内容', text: this.logs.editText })
            .height(130).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
            .backgroundColor(this.theme.themeControl).borderRadius(14)
            .onChange((value: string) => this.logs.editText = value)
          Text(`${this.logs.editText.length}/100000`).fontSize(11).fontColor(this.theme.themeMuted).width('100%').textAlign(TextAlign.End)
          SegmentedControl(this.theme, ['日志', '灵感'], this.logs.editCategory === Category.IDEA ? 1 : 0,
            (index: number) => this.logs.editCategory = index === 1 ? Category.IDEA : Category.LOG)

          FormGroup(this.theme, '标签')
          Scroll() {
            Row({ space: 8 }) {
              ForEach(COLOR_TAGS, (tag: string) => {
                FilterChip(this.theme, colorTagName(tag), this.logs.editTag === tag,
                  () => this.logs.editTag = tag)
              }, (tag: string) => tag)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')

          FormGroup(this.theme, '重要度与日期')
          Column() {
            FormRow(this.theme, '重要度', `${this.editingImportance()}`)
            TextInput({ placeholder: '记录日期 YYYY-MM-DD', text: this.logs.editDate })
              .fontColor(this.theme.themeText).backgroundColor(this.theme.themeControl).height(44)
              .onChange((value: string) => this.logs.editDate = value)

          }.width('100%')
          Text('日期决定日历归属与回顾统计；重要度沿用原值。')
            .fontSize(11).fontColor(this.theme.themeMuted).width('100%')
        }
        .width('100%')
        .enabled(!this.logs.busy)
        .padding(22)
        .backgroundColor(this.theme.themeSurface)
        .borderRadius(RADIUS_CARD)
      }.width(this.navigation.isMediumWindow ? 520 : '88%').constraintSize({ maxHeight: '90%' })
    }.width('100%').height('100%')
  }

  private editingImportance(): number {
    return this.logs.logs.find((item: LogItem) => item.id === this.logs.editingLogId)?.importance ?? 0;
  }

  build() {
    this.editLogDialog()
  }
}

