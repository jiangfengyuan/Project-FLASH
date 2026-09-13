import { dayOffset } from '../data/DateUtils';
import { EmotionRecord } from '../models/Models';
import { EmotionState } from '../state/FeatureStates';
import { FlashStore } from '../data/FlashStore';
import { ControllerRuntime } from './ControllerRuntime';

export class EmotionController {
  private state: EmotionState;
  private store: FlashStore;
  private runtime: ControllerRuntime;
  constructor(state: EmotionState, runtime: ControllerRuntime, store: FlashStore = FlashStore.instance) {
    this.state = state;
    this.store = store;
    this.runtime = runtime;
  }
  async saveEmotion(): Promise<void> {
    if (this.state.busy) return;
    this.state.busy = true;
    try {
      await this.store.addEmotion(this.state.emotionLevel,
        this.state.emotionLevel < 0 ? this.state.selectedSubEmotion : undefined, this.state.emotionNote);
      this.state.emotionNote = '';
      this.runtime.notify('情绪已记录');
    } catch (error) {
      this.runtime.notify(this.runtime.errorMessage(error as Error));
    } finally {
      this.state.busy = false;
    }
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

  dayAverage(day: string): number | undefined {
    const matches = this.state.emotions.filter((item: EmotionRecord) => item.recordDate === day);
    if (matches.length === 0) return undefined;
    return matches.reduce((sum: number, item: EmotionRecord) => sum + item.level, 0) / matches.length;
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
