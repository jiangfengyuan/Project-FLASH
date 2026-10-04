import { Category, COLOR_TAGS, ColorTag, colorTagName, LogItem } from '../models/Models';
import { ThemeState, LogsState, FeedbackState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  PageHeader, FilterChip, RecordCard, FlashCard, EmptyState, DOCK_CLEARANCE, RADIUS_FOCUS, brandText,
  floatingSurface, hairlineColor, supportsBlurMaterial, scrimColor, cardShadowColor, motionDuration, MOTION_FADE,
  TYPE_GROUP, TYPE_BODY, TYPE_SECONDARY
} from '../components/CommonBuilders';

/** Lazy row source for the records list; reloaded only when the displayed
 * slice inputs (search results, sort direction, display cap) actually change. */
class DisplayedLogsSource implements IDataSource {
  private listeners: DataChangeListener[] = [];
  private items: LogItem[] = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): LogItem {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) this.listeners.push(listener);
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const index = this.listeners.indexOf(listener);
    if (index >= 0) this.listeners.splice(index, 1);
  }

  reload(items: LogItem[]): void {
    this.items = items;
    this.listeners.forEach((listener: DataChangeListener): void => listener.onDataReloaded());
  }
}

@Component
export struct ExplorePage {
  @ObjectLink @Watch('syncLogSource') logs: LogsState;
  @ObjectLink theme: ThemeState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;
  @State private filterPanelOpen: boolean = false;
  private logSource: DisplayedLogsSource = new DisplayedLogsSource();
  private syncedResults?: LogItem[];
  private syncedAscending: boolean = false;
  private syncedLimit: number = -1;

  aboutToAppear(): void {
    this.syncLogSource();
  }

  private syncLogSource(): void {
    const state = this.logs;
    if (this.syncedResults === state.searchResults && this.syncedAscending === state.sortAscending &&
      this.syncedLimit === state.logDisplayLimit) return;
    this.syncedResults = state.searchResults;
    this.syncedAscending = state.sortAscending;
    this.syncedLimit = state.logDisplayLimit;
    this.logSource.reload(requireActions(this.actions).logsController.displayedLogs());
  }

  @Builder
  private explorePage() {
    Stack({ alignContent: Alignment.Bottom }) {
      List({ space: 12 }) {
        ListItem() {
          PageHeader(this.theme, '记录', '搜索、筛选与整理所有片段')
        }
        ListItem() {
          Column({ space: 12 }) {
            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(20).fontColor([brandText(this.theme)])
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
                  .height(44).fontSize(TYPE_SECONDARY).fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint)
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
            .backgroundColor(floatingSurface(this.theme))
            .backgroundBlurStyle(supportsBlurMaterial() ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
            .borderRadius(26)
            .border({ width: 0.5, color: hairlineColor(this.theme) })
            .animation({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut })

            Text(this.summaryText()).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')

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
                .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
            }

            Row({ space: 12 }) {
              Text(this.logs.sortAscending ? '按最早记录' : '按最新记录')
                .fontSize(TYPE_SECONDARY).fontColor(brandText(this.theme))
                .height(44).padding({ left: 4, right: 4 })
                .stateStyles({
                  normal: { .opacity(1) },
                  pressed: { .opacity(0.6) }
                })
                .onClick(() => this.logs.sortAscending = !this.logs.sortAscending)
                .animation({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut })
              Blank()
              Row({ space: 4 }) {
                SymbolGlyph($r('sys.symbol.slider_vertical_3')).fontSize(16)
                  .fontColor([this.filterPanelOpen ? brandText(this.theme) : this.theme.themeMuted])
                Text('筛选').fontSize(TYPE_SECONDARY)
                  .fontColor(this.filterPanelOpen ? brandText(this.theme) : this.theme.themeMuted)
              }
              .height(44)
              .padding({ left: 12, right: 12 })
              .accessibilityGroup(true)
              .accessibilityText(this.filterPanelOpen ? '收起筛选面板' : '展开筛选面板')
              .stateStyles({
                normal: { .opacity(1) },
                pressed: { .opacity(0.6) }
              })
              .onClick(() => this.filterPanelOpen = !this.filterPanelOpen)
              .animation({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut })
            }.width('100%')

            if (this.logs.filterCategory === 'inbox' &&
              requireActions(this.actions).logsController.inboxLogs().length > 0) {
              FlashCard({ theme: this.theme, contentPadding: 12, radius: 16, space: 8 }) {
                Text('批量整理（影响全部待整理记录）').fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
                Row({ space: 8 }) {
                  Button('转为灵感', { type: ButtonType.Normal })
                    .height(44).fontSize(TYPE_SECONDARY).fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint)
                    .onClick(() => requireActions(this.actions).logsController.batchUpdateInbox(Category.IDEA, ColorTag.IDEA))
                  Button('标记备忘', { type: ButtonType.Normal })
                    .height(44).fontSize(TYPE_SECONDARY).fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint)
                    .onClick(() => requireActions(this.actions).logsController.batchUpdateInbox(Category.LOG, ColorTag.MEMO))
                  Button('标记紧急', { type: ButtonType.Normal })
                    .height(44).fontSize(TYPE_SECONDARY).fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint)
                    .onClick(() => requireActions(this.actions).logsController.batchUpdateInbox(Category.LOG, ColorTag.URGENT))
                }.width('100%')
              }
            }
          }.width('100%')
        }

        LazyForEach(this.logSource, (item: LogItem) => {
          ListItem() {
            RecordCard({ theme: this.theme, feedback: this.feedback, actions: requireActions(this.actions), item: item })
          }
        }, (item: LogItem) => item.id)

        if (requireActions(this.actions).logsController.filteredLogCount() === 0) {
          ListItem() {
            EmptyState(this.theme, '🔍', '没有找到相关记录', '清除筛选',
              () => requireActions(this.actions).logsController.clearFilters())
          }
        }
        if (requireActions(this.actions).logsController.hasMoreLogs()) {
          ListItem() {
            Button(`加载更多（剩余 ${requireActions(this.actions).logsController.filteredLogCount() - requireActions(this.actions).logsController.displayedLogs().length} 条）`)
              .width('100%').height(44).fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint)
              .onClick(() => this.logs.logDisplayLimit += 50)
          }
        }
      }
      .width('100%')
      .height('100%')
      .cachedCount(5)
      .padding({ left: 20, right: 20, bottom: DOCK_CLEARANCE })

      if (this.filterPanelOpen) {
        Column().width('100%').height('100%').backgroundColor(scrimColor(this.theme))
          .backdropBlur(supportsBlurMaterial() ? 10 : 0)
          .onClick(() => this.filterPanelOpen = false)
          .transition(TransitionEffect.opacity(0).animation({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut }))
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
        Text('筛选').fontSize(TYPE_GROUP).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
        Blank()
        Text('完成').fontSize(TYPE_BODY).fontColor(brandText(this.theme))
          .padding({ top: 12, bottom: 12 })
          .stateStyles({
            normal: { .opacity(1) },
            pressed: { .opacity(0.6) }
          })
          .onClick(() => this.filterPanelOpen = false)
          .animation({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut })
      }.width('100%')

      Text('类型').fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
      Row({ space: 8 }) {
        FilterChip(this.theme, '全部', this.logs.filterCategory === 'all', () => this.applyCategory('all'))
        FilterChip(this.theme, '日志', this.logs.filterCategory === 'log', () => this.applyCategory('log'))
        FilterChip(this.theme, '灵感', this.logs.filterCategory === 'idea', () => this.applyCategory('idea'))
      }.width('100%')

      Text('标签').fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
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

      Text('日期范围').fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
      Row({ space: 8 }) {
        FilterChip(this.theme, '全部', this.logs.filterDate === 'all', () => this.applyDate('all'))
        FilterChip(this.theme, '今天', this.logs.filterDate === 'today', () => this.applyDate('today'))
        FilterChip(this.theme, '近7天', this.logs.filterDate === 'week', () => this.applyDate('week'))
        FilterChip(this.theme, '近30天', this.logs.filterDate === 'month', () => this.applyDate('month'))
      }.width('100%')

      Text('重要度').fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
      Row({ space: 8 }) {
        FilterChip(this.theme, '全部', this.logs.filterImportance === -1, () => this.applyImportance(-1))
        FilterChip(this.theme, '有重要度', this.logs.filterImportance === 1, () => this.applyImportance(1))
        FilterChip(this.theme, '无重要度', this.logs.filterImportance === 0, () => this.applyImportance(0))
      }.width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor(floatingSurface(this.theme))
    .backgroundBlurStyle(supportsBlurMaterial() ? BlurStyle.COMPONENT_ULTRA_THICK : BlurStyle.NONE)
    .borderRadius({ topLeft: RADIUS_FOCUS, topRight: RADIUS_FOCUS })
    .border({ width: { top: 0.5 }, color: hairlineColor(this.theme) })
    .shadow({ radius: 24, color: cardShadowColor(this.theme), offsetX: 0, offsetY: -6 })
    .transition(TransitionEffect.opacity(0).combine(TransitionEffect.translate({ y: 24 }))
      .animation({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut }))
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
