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
    this.logs.editingLogId = '';
    this.logs.editText = '';
    this.logs.editCategory = '';
    this.logs.editTag = '';
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

        FormGroup(this.theme, '正文与类型')
        TextArea({ placeholder: '记录内容', text: this.logs.editText })
          .height(130).maxLength(10000).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
          .backgroundColor(this.theme.themeControl).borderRadius(14)
          .onChange((value: string) => this.logs.editText = value.slice(0, 10000))
        Text(`${this.logs.editText.length}/10000`).fontSize(11).fontColor(this.theme.themeMuted).width('100%').textAlign(TextAlign.End)
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
          FormRow(this.theme, '日期', this.editingDate())
        }.width('100%')
        Text('重要度由创建时的 !! 语法标记、日期为记录所属日，编辑时沿用原值。')
          .fontSize(11).fontColor(this.theme.themeMuted).width('100%')
      }
      .width(this.navigation.isMediumWindow ? 520 : '88%')
      .padding(22)
      .backgroundColor(this.theme.themeSurface)
      .borderRadius(RADIUS_CARD)
    }.width('100%').height('100%')
  }

  private editingImportance(): number {
    return this.logs.logs.find((item: LogItem) => item.id === this.logs.editingLogId)?.importance ?? 0;
  }

  private editingDate(): string {
    return this.logs.logs.find((item: LogItem) => item.id === this.logs.editingLogId)?.recordDate ?? '';
  }

  build() {
    this.editLogDialog()
  }
}

