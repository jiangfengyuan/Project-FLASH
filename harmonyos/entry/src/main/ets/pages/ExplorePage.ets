import { Category, COLOR_TAGS, ColorTag, colorTagName, LogItem } from '../models/Models';
import { ThemeState, LogsState, FeedbackState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  PageHeader, FilterChip, RecordCard, DOCK_CLEARANCE, RADIUS_CARD, RADIUS_FOCUS, BRAND
} from '../components/CommonBuilders';

@Component
export struct ExplorePage {
  @ObjectLink theme: ThemeState;
  @ObjectLink logs: LogsState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;
  @State private filterPanelOpen: boolean = false;

  @Builder
  private explorePage() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: 14 }) {
          PageHeader(this.theme, '记录', '搜索、筛选与整理所有片段')
          Column({ space: 12 }) {
            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(20).fontColor([BRAND])
              TextInput({ placeholder: '输入关键词或标签', text: this.logs.searchText })
                .layoutWeight(1).height(44).maxLength(200).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
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
            .height(52)
            .padding({ left: 16, right: 12 })
            .backgroundColor(this.theme.themeSurface)
            .borderRadius(26)
            .animation({ duration: 180, curve: Curve.EaseOut })

            Text(this.summaryText()).fontSize(12).fontColor(this.theme.themeMuted).width('100%')

            Scroll() {
              Row({ space: 8 }) {
                FilterChip(this.theme, '全部', this.logs.filterCategory === 'all',
                  () => this.applyCategory('all'))
                FilterChip(this.theme, '日志', this.logs.filterCategory === 'log',
                  () => this.applyCategory('log'))
                FilterChip(this.theme, '灵感', this.logs.filterCategory === 'idea',
                  () => this.applyCategory('idea'))
                FilterChip(this.theme, '待整理', this.logs.filterCategory === 'inbox',
                  () => this.applyCategory('inbox'))
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')

            if (this.logs.filterCategory === 'inbox') {
              Text('待整理：使用日常标签的日志。')
                .fontSize(12).fontColor(this.theme.themeMuted).width('100%')
            }

            Row({ space: 12 }) {
              Text(this.logs.sortAscending ? '按最早记录' : '按最新记录')
                .fontSize(13).fontColor(BRAND)
                .padding({ top: 12, bottom: 12 })
                .onClick(() => this.logs.sortAscending = !this.logs.sortAscending)
              Blank()
              Row({ space: 4 }) {
                SymbolGlyph($r('sys.symbol.slider_vertical_3')).fontSize(16)
                  .fontColor([this.filterPanelOpen ? BRAND : this.theme.themeMuted])
                Text('筛选').fontSize(13)
                  .fontColor(this.filterPanelOpen ? BRAND : this.theme.themeMuted)
              }
              .height(44)
              .padding({ left: 12, right: 12 })
              .onClick(() => this.filterPanelOpen = !this.filterPanelOpen)
            }.width('100%')

            if (this.logs.filterCategory === 'inbox' &&
              requireActions(this.actions).logsController.inboxLogs().length > 0) {
              Column({ space: 8 }) {
                Text('批量整理（影响全部待整理记录）').fontSize(12).fontColor(this.theme.themeMuted).width('100%')
                Row({ space: 8 }) {
                  Button('转为灵感', { type: ButtonType.Normal })
                    .height(36).fontSize(12).fontColor(BRAND).backgroundColor(this.theme.themeTint)
                    .onClick(() => requireActions(this.actions).logsController.batchUpdateInbox(Category.IDEA, ColorTag.IDEA))
                  Button('标记备忘', { type: ButtonType.Normal })
                    .height(36).fontSize(12).fontColor(BRAND).backgroundColor(this.theme.themeTint)
                    .onClick(() => requireActions(this.actions).logsController.batchUpdateInbox(Category.LOG, ColorTag.MEMO))
                  Button('标记紧急', { type: ButtonType.Normal })
                    .height(36).fontSize(12).fontColor(BRAND).backgroundColor(this.theme.themeTint)
                    .onClick(() => requireActions(this.actions).logsController.batchUpdateInbox(Category.LOG, ColorTag.URGENT))
                }.width('100%')
              }
              .width('100%')
              .padding(12)
              .backgroundColor(this.theme.themeSurface)
              .borderRadius(16)
            }

            Column({ space: 12 }) {
              ForEach(requireActions(this.actions).logsController.displayedLogs(), (item: LogItem) => {
                RecordCard({ theme: this.theme, feedback: this.feedback, actions: requireActions(this.actions), item: item })
              }, (item: LogItem) => item.id)
            }.width('100%')

            if (requireActions(this.actions).logsController.filteredLogCount() === 0) {
              Column({ space: 12 }) {
                Text('没有找到相关记录').fontSize(14).fontColor(this.theme.themeMuted)
                Button('清除筛选').height(44).backgroundColor(BRAND)
                  .onClick(() => requireActions(this.actions).logsController.clearFilters())
              }
              .width('100%')
              .padding(24)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(this.theme.themeSurface)
              .borderRadius(RADIUS_CARD)
            }
            if (requireActions(this.actions).logsController.hasMoreLogs()) {
              Button(`加载更多（剩余 ${requireActions(this.actions).logsController.filteredLogCount() - requireActions(this.actions).logsController.displayedLogs().length} 条）`)
                .width('100%').height(40).fontColor(BRAND).backgroundColor(this.theme.themeTint)
                .onClick(() => this.logs.logDisplayLimit += 50)
            }
          }.width('100%').padding({ left: 20, right: 20, bottom: DOCK_CLEARANCE })
        }.width('100%')
      }.width('100%').height('100%')

      if (this.filterPanelOpen) {
        Column().width('100%').height('100%').backgroundColor('#66000000')
          .onClick(() => this.filterPanelOpen = false)
        this.filterPanel()
      }
    }.width('100%').height('100%').backgroundColor(this.theme.themeBackground)
  }

  private applyCategory(value: string): void {
    this.logs.filterCategory = value;
    this.logs.logDisplayLimit = 50;
    requireActions(this.actions).logsController.updateSearchResults();
  }

  private summaryText(): string {
    const total = this.logs.logs.length;
    const logCount = this.logs.logs.filter((item: LogItem) => item.category === Category.LOG).length;
    const ideaCount = total - logCount;
    return `共 ${total} 条 · 日志 ${logCount} · 灵感 ${ideaCount}`;
  }

  @Builder
  private filterPanel() {
    Column({ space: 14 }) {
      Row() {
        Text('筛选').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
        Blank()
        Text('完成').fontSize(14).fontColor(BRAND)
          .padding({ top: 12, bottom: 12 })
          .onClick(() => this.filterPanelOpen = false)
      }.width('100%')

      Text('类型').fontSize(12).fontColor(this.theme.themeMuted).width('100%')
      Row({ space: 8 }) {
        FilterChip(this.theme, '全部', this.logs.filterCategory === 'all', () => this.applyCategory('all'))
        FilterChip(this.theme, '日志', this.logs.filterCategory === 'log', () => this.applyCategory('log'))
        FilterChip(this.theme, '灵感', this.logs.filterCategory === 'idea', () => this.applyCategory('idea'))
      }.width('100%')

      Text('标签').fontSize(12).fontColor(this.theme.themeMuted).width('100%')
      Scroll() {
        Row({ space: 8 }) {
          FilterChip(this.theme, '全部', this.logs.filterTag === '', () => this.applyTag(''))
          ForEach(COLOR_TAGS, (tag: string) => {
            FilterChip(this.theme, colorTagName(tag), this.logs.filterTag === tag, () => this.applyTag(tag))
          }, (tag: string) => tag)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      Text('日期范围').fontSize(12).fontColor(this.theme.themeMuted).width('100%')
      Row({ space: 8 }) {
        FilterChip(this.theme, '全部', this.logs.filterDate === 'all', () => this.applyDate('all'))
        FilterChip(this.theme, '今天', this.logs.filterDate === 'today', () => this.applyDate('today'))
        FilterChip(this.theme, '近7天', this.logs.filterDate === 'week', () => this.applyDate('week'))
        FilterChip(this.theme, '近30天', this.logs.filterDate === 'month', () => this.applyDate('month'))
      }.width('100%')

      Text('重要度').fontSize(12).fontColor(this.theme.themeMuted).width('100%')
      Row({ space: 8 }) {
        FilterChip(this.theme, '全部', this.logs.filterImportance === -1, () => this.applyImportance(-1))
        FilterChip(this.theme, '有重要度', this.logs.filterImportance === 1, () => this.applyImportance(1))
        FilterChip(this.theme, '无重要度', this.logs.filterImportance === 0, () => this.applyImportance(0))
      }.width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor(this.theme.themeSurface)
    .borderRadius({ topLeft: RADIUS_FOCUS, topRight: RADIUS_FOCUS })
  }

  private applyTag(value: string): void {
    this.logs.filterTag = value;
    this.logs.logDisplayLimit = 50;
    requireActions(this.actions).logsController.updateSearchResults();
  }

  private applyDate(value: string): void {
    this.logs.filterDate = value;
    this.logs.logDisplayLimit = 50;
    requireActions(this.actions).logsController.updateSearchResults();
  }

  private applyImportance(value: number): void {
    this.logs.filterImportance = value;
    this.logs.logDisplayLimit = 50;
    requireActions(this.actions).logsController.updateSearchResults();
  }

  build() {
    this.explorePage()
  }
}
