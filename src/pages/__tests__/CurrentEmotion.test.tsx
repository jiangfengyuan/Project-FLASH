import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import CurrentEmotion from '@/pages/CurrentEmotion';
import { useEmotionStore } from '@/stores/emotionStore';
import { useToastStore } from '@/stores/toastStore';

describe('CurrentEmotion', () => {
  beforeEach(() => {
    localStorage.clear();
    useEmotionStore.setState(useEmotionStore.getInitialState(), true);
    useToastStore.setState(useToastStore.getInitialState(), true);
    vi.stubGlobal('navigator', { vibrate: vi.fn() });
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('renders emotion slider and save button', () => {
    render(<CurrentEmotion />);
    expect(screen.getByRole('slider')).toBeInTheDocument();
    expect(screen.getByText('记录此刻')).toBeInTheDocument();
  });

  it('shows sub-emotion options when level is negative', () => {
    useEmotionStore.getState().setCurrentLevel(-1);
    render(<CurrentEmotion />);
    expect(screen.getByRole('button', { name: '伤心' })).toBeInTheDocument();
  });

  it('adds an emotion record when saving', async () => {
    render(<CurrentEmotion />);
    fireEvent.click(screen.getByText('记录此刻'));
    await waitFor(() => {
      expect(useEmotionStore.getState().emotions.length).toBeGreaterThan(0);
    });
  });

  it('renders history list', async () => {
    await useEmotionStore.getState().addEmotion({
      level: 2,
      subEmotion: null,
      status: '工作中',
      note: '感觉不错',
      recordDate: '2026-06-20',
    });
    render(<CurrentEmotion />);
    expect(screen.getByText('工作中')).toBeInTheDocument();
    expect(screen.getByText('感觉不错')).toBeInTheDocument();
  });
});
