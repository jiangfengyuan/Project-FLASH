import { Category, ColorTag, colorTagName, LogItem } from '../models/Models';
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

  async saveIdea(): Promise<void> {
    if (!this.state.ideaText.trim() || this.state.busy) return;
    this.state.busy = true;
    try {
      await this.store.addLog(this.state.ideaText, Category.IDEA, ColorTag.IDEA);
      this.state.ideaText = '';
      this.runtime.notify('灵感已保存');
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
  }

  async saveEditedLog(): Promise<void> {
    if (!this.state.editingLogId || !this.state.editText.trim() || this.state.busy) return;
    this.state.busy = true;
    try {
      await this.store.updateLog(this.state.editingLogId, this.state.editText.slice(0, 10000));
      this.state.editingLogId = '';
      this.state.editText = '';
      this.runtime.notify('记录已更新');
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
    this.state.searchResults = !query ? this.state.logs.slice() : this.state.logs.filter((item: LogItem) =>
      item.content.toLowerCase().includes(query) || colorTagName(item.colorTag).includes(query));
  }

  scheduleSearch(): void {
    clearTimeout(this.searchTimer);
    this.searchTimer = setTimeout(() => this.updateSearchResults(), 160);
  }

  displayedLogs(): LogItem[] {
    return this.filteredLogs().slice(0, this.state.logDisplayLimit);
  }

  filteredLogCount(): number {
    return this.filteredLogs().length;
  }

  hasMoreLogs(): boolean {
    return this.filteredLogCount() > this.state.logDisplayLimit;
  }

}
