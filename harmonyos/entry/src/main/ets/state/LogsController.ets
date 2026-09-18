import { Category, ColorTag, colorTagName, LogItem } from '../models/Models';
import { dayOffset, dayString } from '../data/DateUtils';
import { LogsState } from '../state/FeatureStates';
import { FlashStore } from '../data/FlashStore';
import { ControllerRuntime } from './ControllerRuntime';

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
      this.runtime.notify(isIdea ? '灵感已保存' : '日志已记录');
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error));
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
      this.runtime.notify(isIdea ? '灵感已保存' : '日志已记录');
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error));
    } finally {
      this.state.busy = false;
    }
  }

  async removeLog(id: string): Promise<void> {
    await this.store.deleteLog(id);
  }

  startEditLog(item: LogItem): void {
    this.state.editingLogId = item.id;
    this.state.editText = item.content;
    this.state.editCategory = item.category;
    this.state.editTag = item.colorTag;
  }

  async saveEditedLog(): Promise<void> {
    if (!this.state.editingLogId || !this.state.editText.trim() || this.state.busy) return;
    this.state.busy = true;
    try {
      const id = this.state.editingLogId;
      await this.store.updateLog(id, this.state.editText.slice(0, 10000));
      await this.store.updateLogMeta(id, this.state.editCategory, this.state.editTag);
      this.state.editingLogId = '';
      this.state.editText = '';
      this.state.editCategory = '';
      this.state.editTag = '';
      this.runtime.notify('记录已更新');
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error));
    } finally {
      this.state.busy = false;
    }
  }

  /** 待整理 = 分类为日志且仍为默认「日常」标签的记录。批量整理复用 updateLogMeta，
   * 正文与重要度保持不变。 */
  inboxLogs(): LogItem[] {
    return this.state.logs.filter((item: LogItem) => item.category === Category.LOG && item.colorTag === ColorTag.DAILY);
  }

  async batchUpdateInbox(category: string, colorTag: string): Promise<void> {
    const targets = this.inboxLogs();
    if (targets.length === 0 || this.state.busy) return;
    this.state.busy = true;
    try {
      for (const item of targets) {
        await this.store.updateLogMeta(item.id, category, colorTag);
      }
      this.runtime.notify(`已整理 ${targets.length} 条记录`);
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error));
    } finally {
      this.state.busy = false;
    }
  }

  filteredLogs(): LogItem[] {
    return this.state.searchResults;
  }

  updateSearchResults(): void {
    const query = this.state.searchText.trim().toLowerCase();
    let base = this.state.logs.filter((item: LogItem) => this.matchesFilters(item));
    if (query) {
      base = base.filter((item: LogItem) =>
        item.content.toLowerCase().includes(query) || colorTagName(item.colorTag).includes(query));
    }
    this.state.searchResults = base;
  }

  private matchesFilters(item: LogItem): boolean {
    const category = this.state.filterCategory;
    if (category === 'log' && item.category !== Category.LOG) return false;
    if (category === 'idea' && item.category !== Category.IDEA) return false;
    if (category === 'inbox' && (item.category !== Category.LOG || item.colorTag !== ColorTag.DAILY)) return false;
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
      this.state.filterTag !== '' || this.state.filterDate !== 'all' || this.state.filterImportance !== -1;
  }

  clearFilters(): void {
    this.state.searchText = '';
    this.state.filterCategory = 'all';
    this.state.filterTag = '';
    this.state.filterDate = 'all';
    this.state.filterImportance = -1;
    this.state.logDisplayLimit = 50;
    this.updateSearchResults();
  }

  scheduleSearch(): void {
    clearTimeout(this.searchTimer);
    this.searchTimer = setTimeout(() => this.updateSearchResults(), 160);
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
