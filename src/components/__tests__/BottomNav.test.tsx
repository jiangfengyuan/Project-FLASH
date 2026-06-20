import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import BottomNav from '@/components/BottomNav';
import { useNavigationStore } from '@/stores/navigationStore';

describe('BottomNav', () => {
  let vibrate: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    localStorage.clear();
    useNavigationStore.setState(useNavigationStore.getInitialState(), true);
    vibrate = vi.fn();
    vi.stubGlobal('navigator', { vibrate });
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('renders all tabs', () => {
    render(<BottomNav />);
    expect(screen.getByLabelText('Log')).toBeInTheDocument();
    expect(screen.getByLabelText('Idea')).toBeInTheDocument();
    expect(screen.getByLabelText('日历')).toBeInTheDocument();
    expect(screen.getByLabelText('情绪')).toBeInTheDocument();
  });

  it('marks the active tab', () => {
    useNavigationStore.setState({ activeTab: 'calendar' });
    render(<BottomNav />);
    expect(screen.getByLabelText('日历')).toHaveAttribute('aria-current', 'page');
    expect(screen.getByLabelText('Log')).not.toHaveAttribute('aria-current');
  });

  it('switches active tab on click', () => {
    render(<BottomNav />);
    fireEvent.click(screen.getByLabelText('情绪'));
    expect(useNavigationStore.getState().activeTab).toBe('emotion');
    expect(useNavigationStore.getState().currentPage).toBe('emotion');
  });

  it('triggers haptic feedback on click', () => {
    render(<BottomNav />);
    fireEvent.click(screen.getByLabelText('Idea'));
    expect(vibrate).toHaveBeenCalled();
  });
});
