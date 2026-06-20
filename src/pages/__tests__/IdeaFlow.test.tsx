import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import IdeaFlow from '@/pages/IdeaFlow';
import { useLogStore } from '@/stores/logStore';
import { useToastStore } from '@/stores/toastStore';
import { getTodayStr } from '@/lib/utils';

describe('IdeaFlow', () => {
  beforeEach(() => {
    localStorage.clear();
    useLogStore.setState(useLogStore.getInitialState(), true);
    useToastStore.setState(useToastStore.getInitialState(), true);
    vi.stubGlobal('navigator', { vibrate: vi.fn() });
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('renders empty state when no ideas', () => {
    useLogStore.setState({ logs: [] });
    render(<IdeaFlow />);
    expect(screen.getByText('还没有想法记录')).toBeInTheDocument();
  });

  it('groups ideas by time', () => {
    const todayStr = getTodayStr();
    const yesterdayStr = getTodayStr(new Date(Date.now() - 86400000));
    useLogStore.setState({
      logs: [
        {
          id: '1',
          content: 'today idea',
          colorTag: 'idea',
          category: 'idea',
          importance: 0,
          createdAt: new Date().toISOString(),
          recordDate: todayStr,
        },
        {
          id: '2',
          content: 'yesterday idea',
          colorTag: 'idea',
          category: 'idea',
          importance: 0,
          createdAt: new Date(Date.now() - 86400000).toISOString(),
          recordDate: yesterdayStr,
        },
      ],
    });
    render(<IdeaFlow />);
    expect(screen.getByText('今天')).toBeInTheDocument();
    expect(screen.getByText('昨天')).toBeInTheDocument();
    expect(screen.getByText('today idea')).toBeInTheDocument();
    expect(screen.getByText('yesterday idea')).toBeInTheDocument();
  });

  it('transfers an idea to log', () => {
    useLogStore.setState({
      logs: [
        {
          id: '1',
          content: 'idea to log',
          colorTag: 'idea',
          category: 'idea',
          importance: 0,
          createdAt: new Date().toISOString(),
          recordDate: getTodayStr(),
        },
      ],
    });
    render(<IdeaFlow />);
    fireEvent.click(screen.getByLabelText('更多操作'));
    fireEvent.click(screen.getByText('转LOG'));
    expect(useLogStore.getState().logs[0].category).toBe('log');
  });
});
