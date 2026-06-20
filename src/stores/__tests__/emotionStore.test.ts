import { beforeEach, describe, expect, it } from 'vitest';
import { useEmotionStore } from '@/stores/emotionStore';

describe('emotionStore', () => {
  beforeEach(() => {
    localStorage.clear();
    useEmotionStore.setState(useEmotionStore.getInitialState(), true);
  });

  it('adds an emotion record', () => {
    useEmotionStore.getState().addEmotion({
      level: 2,
      subEmotion: null,
      status: '学习中',
      note: '感觉不错',
      recordDate: '2026-06-19',
    });
    expect(useEmotionStore.getState().emotions).toHaveLength(6);
    expect(useEmotionStore.getState().emotions[0].level).toBe(2);
  });

  it('deletes an emotion record', () => {
    const id = useEmotionStore.getState().emotions[0].id;
    useEmotionStore.getState().deleteEmotion(id);
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
