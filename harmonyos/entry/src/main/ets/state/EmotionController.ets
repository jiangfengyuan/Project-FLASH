import { tr } from '../data/I18n';
import { dayOffset, dayString } from '../data/DateUtils';
import { EmotionRecord } from '../models/Models';
import { EmotionState } from '../state/FeatureStates';
import { FlashStore } from '../data/FlashStore';
import { ControllerRuntime } from './ControllerRuntime';

export class EmotionController {
  private state: EmotionState;
  private store: FlashStore;
  private runtime: ControllerRuntime;
  private aggregatesVersion: number = -1;
  private aggregates: Map<string, number[]> = new Map<string, number[]>();
  constructor(state: EmotionState, runtime: ControllerRuntime, store: FlashStore = FlashStore.instance) {
    this.state = state;
    this.store = store;
    this.runtime = runtime;
  }
  async saveEmotion(): Promise<void> {
    if (this.state.busy) return;
    this.state.busy = true;
    try {
      const level = this.state.emotionLevel;
      await this.store.addEmotion(level,
        level < 0 ? this.state.selectedSubEmotion : undefined, this.state.emotionNote, this.state.emotionStatus,
        this.state.emotionIntensity > 0 ? this.state.emotionIntensity : undefined);
      this.state.emotionNote = '';
      this.state.emotionStatus = '';
      this.state.emotionIntensity = 0;
      // 保存成功动效信号：页面按 savedLevel 极性做差异化反馈，尊重减少动态效果。
      this.state.savedLevel = level;
      this.state.savedFlash++;
      this.runtime.notify(tr('情绪已记录'), 'success');
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error), 'error');
    } finally {
      this.state.busy = false;
    }
  }

  selectIntensity(value: number): void {
    this.state.emotionIntensity = this.state.emotionIntensity === value ? 0 : value;
  }

  async toggleFavorite(item: EmotionRecord): Promise<void> {
    try {
      await this.store.setEmotionFavorite(item.id, item.isFavorite !== true);
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error), 'error');
    }
  }

  /** 本周（周一到周日）的日期串，趋势行用。 */
  currentWeekDays(today: Date = new Date()): string[] {
    const monday = new Date(today.getFullYear(), today.getMonth(), today.getDate());
    monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));
    const days: string[] = [];
    for (let index = 0; index < 7; index++) {
      days.push(dayString(new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + index)));
    }
    return days;
  }

  /** 某天最新一条情绪的等级；没有记录返回 undefined。 */
  latestLevel(day: string): number | undefined {
    const record = this.state.emotions.find((item: EmotionRecord) => item.recordDate === day);
    return record?.level;
  }

  /** 本周一句话摘要：阈值同 Memory（±1）。 */
  weekSummary(): string {
    const days = this.currentWeekDays();
    const week = this.state.emotions.filter((item: EmotionRecord) => days.includes(item.recordDate));
    if (week.length === 0) return '本周暂无记录';
    const mean = week.reduce((sum: number, item: EmotionRecord) => sum + item.level, 0) / week.length;
    if (mean >= 1) return '本周整体偏积极';
    if (mean <= -1) return '本周情绪偏低落';
    return '本周情绪平稳';
  }

  async removeEmotion(id: string): Promise<void> {
    await this.store.deleteEmotion(id);
  }

  averageEmotion(): string {
    if (this.state.emotions.length === 0) return '—';
    const total = this.state.emotions.reduce((sum: number, item: EmotionRecord) => sum + item.level, 0);
    return (total / this.state.emotions.length).toFixed(1);
  }

  lastSevenDays(): string[] {
    const days: string[] = [];
    for (let index = -6; index <= 0; index++) days.push(dayOffset(index));
    return days;
  }

  /** Per-day [sum, count] aggregation built once per data version: the stats
   * trend rows ask for every day in the window, so each lookup must not
   * re-scan the whole emotion list. */
  private dayAggregates(): Map<string, number[]> {
    if (this.aggregatesVersion === this.state.emotionsVersion) return this.aggregates;
    const map = new Map<string, number[]>();
    this.state.emotions.forEach((item: EmotionRecord) => {
      const entry = map.get(item.recordDate) ?? [0, 0];
      entry[0] += item.level;
      entry[1] += 1;
      map.set(item.recordDate, entry);
    });
    this.aggregates = map;
    this.aggregatesVersion = this.state.emotionsVersion;
    return map;
  }

  dayAverage(day: string): number | undefined {
    const entry = this.dayAggregates().get(day);
    return entry === undefined ? undefined : entry[0] / entry[1];
  }

  dayBar(day: string): number {
    const average = this.dayAverage(day);
    return average === undefined ? 0 : Math.max(8, Math.round((average + 3) / 6 * 100));
  }

  dayEmotionLabel(day: string): string {
    const average = this.dayAverage(day);
    return average === undefined ? '—' : average.toFixed(1);
  }

}
