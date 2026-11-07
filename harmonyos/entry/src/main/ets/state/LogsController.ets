import { Category, ColorTag, colorTagName, LogItem } from '../models/Models';
import { dayOffset, dayString, isValidRecordDay } from '../data/DateUtils';
import { LogsState } from '../state/FeatureStates';
import { FlashStore, LogMetaEdit } from '../data/FlashStore';
import { ControllerRuntime } from './ControllerRuntime';
import { tr } from '../data/I18n';

export class LogsController {
  private state: LogsState;
  private store: FlashStore;
  private runtime: ControllerRuntime;
  constructor(state: LogsState, runtime: ControllerRuntime, store: FlashStore = FlashStore.instance) {
    this.state = state;
    this.store = store;
    this.runtime = runtime;
  }
  private searchTimer: number = 0;
  dispose(): void { clearTimeout(this.searchTimer); }
  async saveQuickCategory(): Promise<void> {
    if (!this.state.quickText.trim() || this.state.quickCategory === '' || this.state.busy) return;
    this.state.busy = true;
    try {
      const isIdea = this.state.quickCategory === Category.IDEA;
      await this.store.addLog(this.state.quickText, isIdea ? Category.IDEA : Category.LOG,
        isIdea ? ColorTag.IDEA : ColorTag.DAILY);
      this.state.quickText = '';
      this.state.quickCategory = '';
      this.state.quickShared = false;
      this.runtime.notify(isIdea ? tr('✓ 已保存到灵感') : tr('✓ 已保存到日志'), 'success');
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error), 'error');
    } finally {
      this.state.busy = false;
    }
  }

  /** 此刻页快速捕捉卡：与 FAB 轻输入共用 addLog 数据路径，保存后由 Store
   * 发布驱动今日一览与最近闪念立即更新。 */
  async saveCapture(): Promise<void> {
    if (!this.state.captureText.trim() || this.state.busy) return;
    this.state.busy = true;
    try {
      const isIdea = this.state.captureCategory === Category.IDEA;
      await this.store.addLog(this.state.captureText, isIdea ? Category.IDEA : Category.LOG,
        isIdea ? ColorTag.IDEA : ColorTag.DAILY);
      this.state.captureText = '';
      this.runtime.notify(isIdea ? tr('灵感已保存') : tr('日志已记录'), 'success');
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error), 'error');
    } finally {
      this.state.busy = false;
    }
  }

  async removeLog(id: string): Promise<void> {
    await this.store.deleteLog(id);
  }

  /** 点按记录直接进入编辑（对齐 iOS）；打开灵感即视为已读。 */
  openLog(item: LogItem): void {
    if (item.category === Category.IDEA) {
      this.store.markIdeaViewed(item.id).catch(() => {});
    }
    this.startEditLog(item);
  }

  openLogById(id: string): void {
    const item = this.state.logs.find((log: LogItem) => log.id === id);
    if (item) this.openLog(item);
  }

  async toggleFavorite(item: LogItem): Promise<void> {
    try {
      await this.store.setLogFavorite(item.id, item.isFavorite !== true);
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error), 'error');
    }
  }

  /** 删除即生效，4 秒内可撤销（恢复记录与已读状态）。 */
  async deleteWithUndo(item: LogItem): Promise<void> {
    const wasViewed = this.store.isIdeaViewed(item.id);
    try {
      await this.store.deleteLog(item.id);
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error), 'error');
      return;
    }
    this.runtime.notifyUndo(tr('已删除'), tr('撤销'), () => {
      this.store.restoreLog(item, wasViewed).catch((error: Error) => {
        this.runtime.notify(this.runtime.errorMessage(error), 'error');
      });
    });
  }

  startEditLog(item: LogItem): void {
    this.state.editingLogId = item.id;
    this.state.editText = item.content;
    this.state.editCategory = item.category;
    this.state.editTag = item.colorTag;
    this.state.editDate = item.recordDate;
    this.state.editImportance = item.importance;
    this.state.editFavorite = item.isFavorite === true;
    this.state.editError = '';
    this.state.editDiscard = false;
  }

  closeEdit(): void {
    if (this.state.busy) return;
    this.state.editingLogId = '';
    this.state.editText = '';
    this.state.editCategory = '';
    this.state.editTag = '';
    this.state.editDate = '';
    this.state.editImportance = 0;
    this.state.editError = '';
    this.state.editDiscard = false;
  }

  requestCloseEdit(): void {
    if (this.state.busy) return;
    const item = this.state.logs.find((log: LogItem) => log.id === this.state.editingLogId);
    if (!item || item.content !== this.state.editText || item.category !== this.state.editCategory ||
      item.colorTag !== this.state.editTag || item.recordDate !== this.state.editDate ||
      item.importance !== this.state.editImportance || (item.isFavorite === true) !== this.state.editFavorite) {
      this.state.editDiscard = true;
    } else {
      this.closeEdit();
    }
  }

  editValidation(): string {
    if (!this.state.editText.trim()) return tr('内容不能为空，请输入后再保存');
    if (this.state.editText.length > 100000) return tr('内容超过 100000 字符，请删减后保存');
    if (!isValidRecordDay(this.state.editDate)) return tr('请输入有效日期（YYYY-MM-DD）');
    return '';
  }

  async saveEditedLog(): Promise<void> {
    if (!this.state.editingLogId || !this.state.editText.trim() || this.state.busy) return;
    this.state.editError = this.editValidation();
    if (this.state.editError) return;
    this.state.busy = true;
    try {
      const id = this.state.editingLogId;
      await this.store.updateLog(id, this.state.editText, this.state.editCategory, this.state.editTag,
        this.state.editDate, this.state.editImportance, this.favoriteForSave(id));
      this.state.editingLogId = '';
      this.state.editText = '';
      this.state.editCategory = '';
      this.state.editTag = '';
      this.state.editDate = '';
      this.state.editImportance = 0;
      this.state.editError = '';
      this.runtime.notify(tr('记录已更新'), 'success');
    } catch (error) {
      this.state.editError = this.runtime.errorMessage(error as Error);
      this.runtime.notify(this.state.editError, 'error');
    } finally {
      this.state.busy = false;
    }
  }

  // 从未收藏过且仍未收藏时不写字段，保持与其他端的 null 语义。
  private favoriteForSave(id: string): boolean | undefined {
    const item = this.state.logs.find((log: LogItem) => log.id === id);
    if (!this.state.editFavorite && typeof item?.isFavorite !== 'boolean') return undefined;
    return this.state.editFavorite;
  }

  /** 待整理 = 分类为日志且仍为默认「日常」标签的记录。批量整理复用 updateLogMeta
   * 的语义，正文与重要度保持不变；整批在 store 内一次落库、单次发布。 */
  inboxLogs(): LogItem[] {
    return this.state.logs.filter((item: LogItem) => item.category === Category.LOG && item.colorTag === ColorTag.DAILY);
  }

  toggleSelected(id: string): void {
    this.state.selectedIds = this.state.selectedIds.includes(id)
      ? this.state.selectedIds.filter((other: string) => other !== id)
      : [...this.state.selectedIds, id];
  }

  endSelection(): void {
    this.state.selecting = false;
    this.state.selectedIds = [];
  }

  /** 只整理用户选中的记录（替代原来的「影响全部待整理」）。 */
  async batchUpdateSelected(category: string, colorTag: string): Promise<void> {
    const ids = this.state.selectedIds;
    if (ids.length === 0 || this.state.busy) return;
    this.state.busy = true;
    try {
      await this.store.updateLogsMetaBatch(ids.map((id: string) => {
        const edit: LogMetaEdit = { id: id, category: category, colorTag: colorTag };
        return edit;
      }));
      this.runtime.notify(tr('✓ 已整理 {0} 条', ids.length), 'success');
      this.endSelection();
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error), 'error');
    } finally {
      this.state.busy = false;
    }
  }

  /** 日志流：只含日志，多选标签 + 日期上下界 + 三种排序 + 已收藏。 */
  flowLogs(): LogItem[] {
    const query = this.state.flowQuery.trim().toLowerCase();
    const filtered = this.state.logs.filter((item: LogItem) => {
      if (item.category !== Category.LOG) return false;
      if (this.state.flowFavorites && item.isFavorite !== true) return false;
      if (this.state.flowTags.length > 0 && !this.state.flowTags.includes(item.colorTag)) return false;
      if (this.state.flowStart !== '' && item.recordDate < this.state.flowStart) return false;
      if (this.state.flowEnd !== '' && item.recordDate > this.state.flowEnd) return false;
      return query === '' || item.content.toLowerCase().includes(query) ||
        colorTagName(item.colorTag).toLowerCase().includes(query);
    });
    if (this.state.flowSort === 'oldest') {
      return filtered.slice().sort((left: LogItem, right: LogItem) => left.createdAt.localeCompare(right.createdAt));
    }
    if (this.state.flowSort === 'tag') {
      return filtered.slice().sort((left: LogItem, right: LogItem) =>
        left.colorTag.localeCompare(right.colorTag) || right.createdAt.localeCompare(left.createdAt));
    }
    return filtered;
  }

  toggleFlowTag(tag: string): void {
    this.state.flowTags = this.state.flowTags.includes(tag)
      ? this.state.flowTags.filter((other: string) => other !== tag)
      : [...this.state.flowTags, tag];
  }

  filteredLogs(): LogItem[] {
    return this.state.searchResults;
  }

  updateSearchResults(): void {
    const query = this.state.searchText.trim().toLowerCase();
    let base = this.state.logs.filter((item: LogItem) => this.matchesFilters(item));
    if (query) {
      base = base.filter((item: LogItem) =>
        item.content.toLowerCase().includes(query) || colorTagName(item.colorTag).toLowerCase().includes(query));
    }
    this.state.searchResults = base;
  }

  private matchesFilters(item: LogItem): boolean {
    const category = this.state.filterCategory;
    if (category === 'log' && item.category !== Category.LOG) return false;
    if (category === 'idea' && item.category !== Category.IDEA) return false;
    if (category === 'inbox' && (item.category !== Category.LOG || item.colorTag !== ColorTag.DAILY)) return false;
    if (this.state.favoritesOnly && item.isFavorite !== true) return false;
    if (this.state.filterTag !== '' && item.colorTag !== this.state.filterTag) return false;
    if (this.state.filterImportance === 0 && item.importance > 0) return false;
    if (this.state.filterImportance === 1 && item.importance === 0) return false;
    if (this.state.filterDate === 'today') return item.recordDate === dayString();
    if (this.state.filterDate === 'week') return item.recordDate >= dayOffset(-6);
    if (this.state.filterDate === 'month') return item.recordDate >= dayOffset(-29);
    return true;
  }

  hasActiveFilters(): boolean {
    return this.state.searchText.trim() !== '' || this.state.filterCategory !== 'all' ||
      this.state.filterTag !== '' || this.state.filterDate !== 'all' || this.state.filterImportance !== -1 ||
      this.state.favoritesOnly;
  }

  clearFilters(): void {
    this.state.searchText = '';
    this.state.filterCategory = 'all';
    this.state.filterTag = '';
    this.state.filterDate = 'all';
    this.state.filterImportance = -1;
    this.state.favoritesOnly = false;
    this.state.logDisplayLimit = 50;
    this.updateSearchResults();
  }

  scheduleSearch(): void {
    clearTimeout(this.searchTimer);
    this.searchTimer = setTimeout(() => this.updateSearchResults(), 200);
  }

  displayedLogs(): LogItem[] {
    const filtered = this.filteredLogs();
    const ordered = this.state.sortAscending ? filtered.slice().reverse() : filtered;
    return ordered.slice(0, this.state.logDisplayLimit);
  }

  filteredLogCount(): number {
    return this.filteredLogs().length;
  }

  hasMoreLogs(): boolean {
    return this.filteredLogCount() > this.state.logDisplayLimit;
  }

}
