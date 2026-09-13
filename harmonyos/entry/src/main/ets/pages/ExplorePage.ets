import { LogItem } from '../models/Models';
import { ThemeState, LogsState, FeedbackState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import { PageHeader, EmptyState, RecordRow, DOCK_CLEARANCE } from '../components/CommonBuilders';
const BRAND = '#6C5CE7';

@Component
export struct ExplorePage {
  @ObjectLink theme: ThemeState;
  @ObjectLink logs: LogsState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;

  @Builder
  private explorePage() {
    Scroll() {
      Column({ space: 14 }) {
        PageHeader(this.theme, '记录', '按关键词或标签查找，也可以继续记录新灵感')
        Column({ space: 10 }) {
          TextArea({ placeholder: '记录一个新灵感…', text: this.logs.ideaText })
            .height(76).maxLength(10000).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
            .backgroundColor(this.theme.themeControl).borderRadius(14)
            .onChange((value: string) => this.logs.ideaText = value.slice(0, 10000))
          Button('保存灵感').width('100%').height(42).backgroundColor('#FF9F43').onClick(() => requireActions(this.actions).logsController.saveIdea())
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(20)

        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(22).fontColor([BRAND])
          TextInput({ placeholder: '输入关键词或标签', text: this.logs.searchText })
            .layoutWeight(1).height(50).maxLength(200).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
            .backgroundColor(Color.Transparent)
            .onChange((value: string) => {
              this.logs.searchText = value;
              this.logs.logDisplayLimit = 50;
              requireActions(this.actions).logsController.scheduleSearch();
            })
          if (this.logs.searchText !== '') {
            Button('清除', { type: ButtonType.Normal })
              .height(34).fontSize(12).fontColor(BRAND).backgroundColor(this.theme.themeTint)
              .onClick(() => {
                this.logs.searchText = '';
                this.logs.logDisplayLimit = 50;
                requireActions(this.actions).logsController.updateSearchResults();
              })
          }
        }
        .width('100%')
        .height(60)
        .padding({ left: 16, right: 12 })
        .backgroundColor(this.theme.themeSurface)
        .border({ width: 1.5, color: '#B9A8FF' })
        .borderRadius(30)
        .animation({ duration: 180, curve: Curve.EaseOut })

        Column() {
          ForEach(requireActions(this.actions).logsController.displayedLogs(), (item: LogItem) => RecordRow(this.theme, this.feedback, requireActions(this.actions), item), (item: LogItem) => item.id)
          if (requireActions(this.actions).logsController.filteredLogCount() === 0) {
            EmptyState(this.theme, '🔎', '没有找到匹配的内容')
          }
          if (requireActions(this.actions).logsController.hasMoreLogs()) {
            Button(`加载更多（剩余 ${requireActions(this.actions).logsController.filteredLogCount() - requireActions(this.actions).logsController.displayedLogs().length} 条）`)
              .width('100%').height(40).fontColor(BRAND).backgroundColor(this.theme.themeTint)
              .onClick(() => this.logs.logDisplayLimit += 50)
          }
        }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(20)
      }.width('100%').padding({ left: 20, right: 20, bottom: DOCK_CLEARANCE })
    }.width('100%').height('100%').backgroundColor(this.theme.themeBackground)
  }

  build() {
    this.explorePage()
  }
}

