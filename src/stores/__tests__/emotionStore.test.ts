import { beforeEach, describe, expect, it, vi } from 'vitest';
import * as storageModule from '@/lib/storage';
import { useEmotionStore } from '@/stores/emotionStore';
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
});
