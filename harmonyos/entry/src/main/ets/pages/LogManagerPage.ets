import { LogItem } from '../models/Models';
import { ThemeState, LogsState, FeedbackState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import { RecordRow, brandText, hairlineColor } from '../components/CommonBuilders';

@Component
export struct LogManagerPage {
  @ObjectLink theme: ThemeState;
  @ObjectLink logs: LogsState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;

  @Builder
  private logManagerPage() {
    Column({ space: 12 }) {
      TextInput({ placeholder: '搜索记录', text: this.logs.searchText })
        .height(44).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
        .backgroundColor(this.theme.themeSurface).borderRadius(14)
        .border({ width: 0.5, color: hairlineColor(this.theme) })
        .onChange((value: string) => {
          this.logs.searchText = value;
          this.logs.logDisplayLimit = 50;
          requireActions(this.actions).logsController.scheduleSearch();
        })
      List({ space: 8 }) {
        ForEach(requireActions(this.actions).logsController.displayedLogs(), (item: LogItem) => {
          ListItem() { RecordRow(this.theme, this.feedback, requireActions(this.actions), item) }
            .padding({ left: 14, right: 14 }).backgroundColor(this.theme.themeSurface).borderRadius(14)
            .border({ width: 0.5, color: hairlineColor(this.theme) })
        }, (item: LogItem) => item.id)
        if (requireActions(this.actions).logsController.hasMoreLogs()) {
          ListItem() {
            Button(`加载更多（剩余 ${requireActions(this.actions).logsController.filteredLogCount() - requireActions(this.actions).logsController.displayedLogs().length} 条）`)
              .width('100%').height(44).fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint)
              .onClick(() => this.logs.logDisplayLimit += 50)
          }
        }
      }.layoutWeight(1).width('100%')
    }.width('100%').layoutWeight(1).padding({ left: 16, right: 16, bottom: 16 })
  }

  build() {
    this.logManagerPage()
  }
}

