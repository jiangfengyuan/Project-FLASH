import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, act, waitFor } from '@testing-library/react';
import App from '@/App';
import { useNavigationStore } from '@/stores/navigationStore';
import { useLogStore } from '@/stores/logStore';
import { useEmotionStore } from '@/stores/emotionStore';
import { useToastStore } from '@/stores/toastStore';

describe('App', () => {
  beforeEach(() => {
    localStorage.clear();
    useNavigationStore.setState(useNavigationStore.getInitialState(), true);
    useLogStore.setState(useLogStore.getInitialState(), true);
    useEmotionStore.setState(useEmotionStore.getInitialState(), true);
    useToastStore.setState(useToastStore.getInitialState(), true);
    vi.useFakeTimers({ shouldAdvanceTime: true });
    vi.stubGlobal('navigator', { vibrate: vi.fn() });
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  it('renders splash screen initially', async () => {
    render(<App />);
    expect(await screen.findByAltText('Flash')).toBeInTheDocument();
  });

  it('auto-hides splash after timeout and shows main page', async () => {
    render(<App />);
    await screen.findByAltText('Flash');
    void act(() => {
      vi.advanceTimersByTime(3000);
    });
    await waitFor(() => expect(screen.queryByAltText('Flash')).not.toBeInTheDocument());
    expect(await screen.findByLabelText('Log')).toBeInTheDocument();
  });

  it('renders the current tab page', async () => {
    useNavigationStore.setState({ showSplash: false });
    render(<App />);
    expect(await screen.findByText('日志')).toBeInTheDocument();
  });

  it('gates main content until storage boot completes', async () => {
    useNavigationStore.setState({ showSplash: false });
    render(<App />);

    // Boot is async; main content must stay unmounted until it finishes.
    expect(useLogStore.getState().booted).toBe(false);
    expect(useEmotionStore.getState().booted).toBe(false);
    expect(screen.queryByText('日志')).not.toBeInTheDocument();

    await waitFor(() => {
      expect(useLogStore.getState().booted).toBe(true);
      expect(useEmotionStore.getState().booted).toBe(true);
    });
    expect(await screen.findByText('日志')).toBeInTheDocument();
  });

  it('switches page when active tab changes', async () => {
    useNavigationStore.setState({ showSplash: false });
    render(<App />);
    fireEvent.click(await screen.findByLabelText('日历'));
    expect(useNavigationStore.getState().currentPage).toBe('calendar');
    expect(await screen.findByText('今日记录')).toBeInTheDocument();
  });

  it('computes direction when navigating tabs', async () => {
    useNavigationStore.setState({ showSplash: false });
    render(<App />);
    fireEvent.click(await screen.findByLabelText('Idea'));
    expect(useNavigationStore.getState().direction).toBe(1);
    fireEvent.click(await screen.findByLabelText('Log'));
    expect(useNavigationStore.getState().direction).toBe(-1);
  });

  it('does not render BottomNav on non-tab pages', async () => {
    useNavigationStore.setState({ showSplash: false, currentPage: 'logFlow' });
    render(<App />);
    expect(screen.queryByLabelText('Log')).not.toBeInTheDocument();
    expect(await screen.findByLabelText('搜索记录')).toBeInTheDocument();
  });
});
