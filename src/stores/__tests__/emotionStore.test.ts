import { beforeEach, describe, expect, it, vi } from 'vitest';
import * as storageModule from '@/lib/storage';
import { MemoryStorageAdapter } from '@/lib/storage/memoryAdapter';
import { useEmotionStore, type EmotionRecord } from '@/stores/emotionStore';
import { DEMO_EMOTIONS } from '@/data/demo';

vi.mock('@/lib/storage', async () => {
  const actual = await vi.importActual<typeof storageModule>('@/lib/storage');
  const { MemoryStorageAdapter } = actual;
  return {
    ...actual,
    getStorageAdapter: vi.fn(async () => {
      const adapter = new MemoryStorageAdapter();
      await adapter.init();
      return adapter;
    }),
  };
});

describe('emotionStore', () => {
  beforeEach(() => {
    localStorage.clear();
    useEmotionStore.setState(
      { ...useEmotionStore.getInitialState(), emotions: DEMO_EMOTIONS },
      true
    );
  });

  it('adds an emotion record', async () => {
    await useEmotionStore.getState().addEmotion({
      level: 2,
      subEmotion: null,
      status: '学习中',
      note: '感觉不错',
      recordDate: '2026-06-19',
    });
    expect(useEmotionStore.getState().emotions).toHaveLength(6);
    expect(useEmotionStore.getState().emotions[0].level).toBe(2);
  });

  it('deletes an emotion record', async () => {
    const id = useEmotionStore.getState().emotions[0].id;
    await useEmotionStore.getState().deleteEmotion(id);
    expect(useEmotionStore.getState().emotions).toHaveLength(4);
  });

  it('sets current level', () => {
    useEmotionStore.getState().setCurrentLevel(-2);
    expect(useEmotionStore.getState().currentLevel).toBe(-2);
  });

  it('sets current sub emotion', () => {
    useEmotionStore.getState().setCurrentSubEmotion('angry');
    expect(useEmotionStore.getState().currentSubEmotion).toBe('angry');
  });

  it('serializes concurrent mutations', async () => {
    class OrderTrackingAdapter extends MemoryStorageAdapter {
      public order: string[] = [];
      async saveEmotion(emotion: EmotionRecord): Promise<void> {
        this.order.push(`start-${emotion.status}`);
        await new Promise((resolve) => setTimeout(resolve, 10));
        this.order.push(`end-${emotion.status}`);
        await super.saveEmotion(emotion);
      }
    }
    const adapter = new OrderTrackingAdapter();
    vi.mocked(storageModule.getStorageAdapter).mockResolvedValue(adapter);

    useEmotionStore.setState({ ...useEmotionStore.getInitialState(), emotions: [] }, true);

    await Promise.all([
      useEmotionStore.getState().addEmotion({
        level: 1,
        subEmotion: null,
        status: 'first',
        note: null,
        recordDate: '2026-07-14',
      }),
      useEmotionStore.getState().addEmotion({
        level: 2,
        subEmotion: null,
        status: 'second',
        note: null,
        recordDate: '2026-07-14',
      }),
    ]);

    expect(adapter.order).toEqual(['start-first', 'end-first', 'start-second', 'end-second']);
    expect(useEmotionStore.getState().emotions).toHaveLength(2);
  });
});
