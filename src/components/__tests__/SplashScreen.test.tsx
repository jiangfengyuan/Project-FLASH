import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, act } from '@testing-library/react';
import SplashScreen from '@/components/SplashScreen';
import { useNavigationStore } from '@/stores/navigationStore';

describe('SplashScreen', () => {
  beforeEach(() => {
    localStorage.clear();
    useNavigationStore.setState(useNavigationStore.getInitialState(), true);
    vi.useFakeTimers({ shouldAdvanceTime: true });
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  it('renders splash image and skip text', () => {
    render(<SplashScreen />);
    expect(screen.getByText('点击跳过')).toBeInTheDocument();
    void act(() => {
      vi.advanceTimersByTime(500);
    });
    expect(screen.getByAltText('Flash')).toBeInTheDocument();
  });

  it('advances phases and reveals brand text', () => {
    render(<SplashScreen />);
    void act(() => {
      vi.advanceTimersByTime(1500);
    });
    expect(screen.getByText((_, element) => element?.textContent === '#flash')).toBeInTheDocument();
  });

  it('auto-dismisses after full animation timeline', () => {
    render(<SplashScreen />);
    void act(() => {
      vi.advanceTimersByTime(500);
    }); // phase 1
    void act(() => {
      vi.advanceTimersByTime(1000);
    }); // phase 2/3
    void act(() => {
      vi.advanceTimersByTime(1000);
    }); // phase 4
    void act(() => {
      vi.advanceTimersByTime(600);
    }); // dismiss
    expect(useNavigationStore.getState().showSplash).toBe(false);
  });

  it('dismisses immediately when clicked (skip)', () => {
    render(<SplashScreen />);
    fireEvent.click(screen.getByText('点击跳过'));
    void act(() => {
      vi.advanceTimersByTime(600);
    });
    expect(useNavigationStore.getState().showSplash).toBe(false);
  });

  it('cleans up pending timers on unmount', () => {
    const { unmount } = render(<SplashScreen />);
    unmount();
    void act(() => {
      vi.advanceTimersByTime(5000);
    });
    expect(useNavigationStore.getState().showSplash).toBe(true);
  });
});
