import { tr } from '../data/I18n';
import { Category, COLOR_TAGS, ColorTag, colorTagName, LogItem } from '../models/Models';
import { ThemeState, LogsState, FeedbackState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  FilterChip, RecordCard, FlashCard, EmptyState, DOCK_CLEARANCE, RADIUS_FOCUS, RADIUS_FIELD, TOUCH_MIN, TYPE_TITLE, pageGutter, displayFontFamily, dangerText, brandText,
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
          Row({ space: 4 }) {
            Text(tr('记录')).fontSize(TYPE_TITLE).fontFamily(displayFontFamily()).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).layoutWeight(1)
            SymbolGlyph($r('sys.symbol.slider_vertical_3')).fontSize(20)
              .fontColor([this.filterPanelOpen ? brandText(this.theme) : this.theme.themeMuted])
              .width(TOUCH_MIN).height(TOUCH_MIN)
              .accessibilityText(this.filterPanelOpen ? tr('收起筛选面板') : tr('展开筛选面板'))
              .onClick(() => this.filterPanelOpen = !this.filterPanelOpen)
            Text('＋').fontSize(TYPE_TITLE - 4).fontColor(brandText(this.theme)).width(TOUCH_MIN).height(TOUCH_MIN).textAlign(TextAlign.Center)
              .accessibilityText(tr('新建'))
              .bindMenu([
                { value: tr('新建记录'), action: () => this.logs.quickCategory = Category.LOG },
                { value: tr('新建灵感'), action: () => this.logs.quickCategory = Category.IDEA },
                { value: tr('日志流'), action: () => requireActions(this.actions).openDetail('logflow') },
                { value: tr('全局搜索'), action: () => requireActions(this.actions).openDetail('search') }
              ])
          }.width('100%').padding({ top: 12, bottom: 4 })
        }
        ListItem() {
          Column({ space: 12 }) {
            Row({ space: 8 }) {
              SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(20).fontColor([brandText(this.theme)])
              TextInput({ placeholder: tr('输入关键词或标签'), text: this.logs.searchText })
                .layoutWeight(1).height(44).maxLength(200).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
                .backgroundColor(Color.Transparent)
                .onChange((value: string) => {
                  this.logs.searchText = value;
                  this.logs.logDisplayLimit = 50;
                  requireActions(this.actions).logsController.scheduleSearch();
                })
              if (this.logs.searchText !== '') {
                Button(tr('清除'), { type: ButtonType.Normal })
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
            .backgroundColor(this.theme.themeControl)
            .borderRadius(RADIUS_FIELD)
            .border({ width: 0.75, color: hairlineColor(this.theme) })
            .animation({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut })

            Text(this.summaryText()).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')

            Scroll() {
              Row({ space: 8 }) {
                FilterChip(this.theme, tr('全部'), this.logs.filterCategory === 'all',
                  () => this.applyCategory('all'))
                FilterChip(this.theme, tr('日志'), this.logs.filterCategory === 'log',
                  () => this.applyCategory('log'))
                FilterChip(this.theme, tr('灵感'), this.logs.filterCategory === 'idea',
                  () => this.applyCategory('idea'))
                FilterChip(this.theme, tr('待整理'), this.logs.filterCategory === 'inbox',
                  () => this.applyCategory('inbox'))
                FilterChip(this.theme, tr('★ 已收藏'), this.logs.favoritesOnly, () => {
                  this.logs.favoritesOnly = !this.logs.favoritesOnly;
                  this.logs.logDisplayLimit = 50;
                  requireActions(this.actions).logsController.updateSearchResults();
                })
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')

            if (this.logs.filterCategory === 'inbox') {
              Row({ space: 8 }) {
                Text(tr('待整理：使用日常标签的日志。'))
                  .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).layoutWeight(1)
                Text(this.logs.selecting ? tr('完成') : tr('选择')).fontSize(TYPE_SECONDARY).fontColor(brandText(this.theme))
                  .height(TOUCH_MIN).padding({ left: 8, right: 8 })
                  .onClick(() => {
                    if (this.logs.selecting) requireActions(this.actions).logsController.endSelection();
                    else this.logs.selecting = true;
                  })
              }.width('100%')
            }

            Row({ space: 12 }) {
              Text(this.logs.sortAscending ? tr('按最早记录') : tr('按最新记录'))
                .fontSize(TYPE_SECONDARY).fontColor(brandText(this.theme))
                .height(44).padding({ left: 4, right: 4 })
                .stateStyles({
                  normal: { .opacity(1) },
                  pressed: { .opacity(0.6) }
                })
                .onClick(() => this.logs.sortAscending = !this.logs.sortAscending)
                .animation({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut })
            }.width('100%')

            if (this.logs.selecting && this.logs.selectedIds.length > 0) {
              FlashCard({ theme: this.theme, contentPadding: 12, radius: 16, space: 8 }) {
                Text(tr('已选 {0} 项', this.logs.selectedIds.length)).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
                Row({ space: 8 }) {
                  Button(tr('标记为灵感'), { type: ButtonType.Normal })
                    .height(44).fontSize(TYPE_SECONDARY).fontColor(brandText(this.theme)).backgroundColor(this.theme.themeControl)
                    .onClick(() => requireActions(this.actions).logsController.batchUpdateSelected(Category.IDEA, ColorTag.IDEA))
                  Button(tr('标记备忘'), { type: ButtonType.Normal })
                    .height(44).fontSize(TYPE_SECONDARY).fontColor(brandText(this.theme)).backgroundColor(this.theme.themeControl)
                    .onClick(() => requireActions(this.actions).logsController.batchUpdateSelected(Category.LOG, ColorTag.MEMO))
                  Button(tr('标记紧急'), { type: ButtonType.Normal })
                    .height(44).fontSize(TYPE_SECONDARY).fontColor(brandText(this.theme)).backgroundColor(this.theme.themeControl)
                    .onClick(() => requireActions(this.actions).logsController.batchUpdateSelected(Category.LOG, ColorTag.URGENT))
                }.width('100%')
              }
            }
          }.width('100%')
        }

        LazyForEach(this.logSource, (item: LogItem) => {
          ListItem() {
            RecordCard({
              theme: this.theme, feedback: this.feedback, actions: requireActions(this.actions), item: item,
              selecting: this.logs.selecting, selected: this.logs.selectedIds.includes(item.id)
            })
          }
          // 轻扫：起始方向切换收藏，结束方向删除（4 秒可撤销）；选择模式下关闭。
          .swipeAction(this.logs.selecting ? {} : {
            start: this.swipeFavorite(item),
            end: this.swipeDelete(item)
          })
        }, (item: LogItem) => `${item.id}-${item.isFavorite === true}-${item.importance}-${item.colorTag}-${item.content.length}`)

        if (requireActions(this.actions).logsController.filteredLogCount() === 0) {
          ListItem() {
            EmptyState(this.theme, '🔍', tr('没有找到相关记录'), tr('清除筛选'),
              () => requireActions(this.actions).logsController.clearFilters())
          }
        }
        if (requireActions(this.actions).logsController.hasMoreLogs()) {
          ListItem() {
            Button(tr('加载更多（剩余 {0} 条）', requireActions(this.actions).logsController.filteredLogCount() - requireActions(this.actions).logsController.displayedLogs().length))
              .width('100%').height(44).fontColor(brandText(this.theme)).backgroundColor(this.theme.themeTint)
              .onClick(() => this.logs.logDisplayLimit += 50)
          }
        }
      }
      .width('100%')
      .height('100%')
      .cachedCount(5)
      .padding({ left: pageGutter(), right: pageGutter(), bottom: DOCK_CLEARANCE })

      if (this.filterPanelOpen) {
        Column().width('100%').height('100%').backgroundColor(scrimColor(this.theme))
          .backdropBlur(supportsBlurMaterial() ? 10 : 0)
          .onClick(() => this.filterPanelOpen = false)
          .transition(TransitionEffect.opacity(0).animation({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut }))
        this.filterPanel()
      }
    }.width('100%').height('100%')
  }

  @Builder
  private swipeFavorite(item: LogItem) {
    Stack() {
      SymbolGlyph(item.isFavorite === true ? $r('sys.symbol.star_slash') : $r('sys.symbol.star')).fontSize(22).fontColor([brandText(this.theme)])
    }
    .width(72).height('100%')
    .accessibilityText(item.isFavorite === true ? tr('取消收藏') : tr('收藏'))
    .onClick(() => requireActions(this.actions).logsController.toggleFavorite(item))
  }

  @Builder
  private swipeDelete(item: LogItem) {
    Stack() {
      SymbolGlyph($r('sys.symbol.trash')).fontSize(22).fontColor([dangerText(this.theme)])
    }
    .width(72).height('100%')
    .accessibilityText(tr('删除'))
    .onClick(() => requireActions(this.actions).logsController.deleteWithUndo(item))
  }

  private applyCategory(value: string): void {
    this.logs.filterCategory = value;
    this.logs.logDisplayLimit = 50;
    requireActions(this.actions).logsController.updateSearchResults();
    if (value !== 'inbox') requireActions(this.actions).logsController.endSelection();
  }

  private summaryText(): string {
    const total = this.logs.logs.length;
    const logCount = this.logs.logs.filter((item: LogItem) => item.category === Category.LOG).length;
    const ideaCount = total - logCount;
    return tr('共 {0} 条 · 日志 {1} · 灵感 {2}', total, logCount, ideaCount);
  }

  @Builder
  private filterPanel() {
    Column({ space: 14 }) {
      Row() {
        Text(tr('筛选')).fontSize(TYPE_GROUP).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
        Blank()
        Text(tr('完成')).fontSize(TYPE_BODY).fontColor(brandText(this.theme))
          .padding({ top: 12, bottom: 12 })
          .stateStyles({
            normal: { .opacity(1) },
            pressed: { .opacity(0.6) }
          })
          .onClick(() => this.filterPanelOpen = false)
          .animation({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut })
      }.width('100%')

      Text(tr('类型')).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
      Row({ space: 8 }) {
        FilterChip(this.theme, tr('全部'), this.logs.filterCategory === 'all', () => this.applyCategory('all'))
        FilterChip(this.theme, tr('日志'), this.logs.filterCategory === 'log', () => this.applyCategory('log'))
        FilterChip(this.theme, tr('灵感'), this.logs.filterCategory === 'idea', () => this.applyCategory('idea'))
      }.width('100%')

      Text(tr('标签')).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
      Scroll() {
        Row({ space: 8 }) {
          FilterChip(this.theme, tr('全部'), this.logs.filterTag === '', () => this.applyTag(''))
          ForEach(COLOR_TAGS, (tag: string) => {
            FilterChip(this.theme, colorTagName(tag), this.logs.filterTag === tag, () => this.applyTag(tag))
          }, (tag: string) => tag)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      Text(tr('日期范围')).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
      Row({ space: 8 }) {
        FilterChip(this.theme, tr('全部'), this.logs.filterDate === 'all', () => this.applyDate('all'))
        FilterChip(this.theme, tr('今天'), this.logs.filterDate === 'today', () => this.applyDate('today'))
        FilterChip(this.theme, tr('近7天'), this.logs.filterDate === 'week', () => this.applyDate('week'))
        FilterChip(this.theme, tr('近30天'), this.logs.filterDate === 'month', () => this.applyDate('month'))
      }.width('100%')

      Text(tr('重要度')).fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).width('100%')
      Row({ space: 8 }) {
        FilterChip(this.theme, tr('全部'), this.logs.filterImportance === -1, () => this.applyImportance(-1))
        FilterChip(this.theme, tr('有重要度'), this.logs.filterImportance === 1, () => this.applyImportance(1))
        FilterChip(this.theme, tr('无重要度'), this.logs.filterImportance === 0, () => this.applyImportance(0))
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
