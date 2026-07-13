import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import LogFlow from '@/pages/LogFlow';
import { useLogStore } from '@/stores/logStore';
import { useToastStore } from '@/stores/toastStore';

describe('LogFlow', () => {
  beforeEach(() => {
    localStorage.clear();
    useLogStore.setState(useLogStore.getInitialState(), true);
    useToastStore.setState(useToastStore.getInitialState(), true);
    vi.stubGlobal('navigator', { vibrate: vi.fn() });
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('renders search input and back button', () => {
    render(<LogFlow />);
    expect(screen.getByLabelText('搜索记录')).toBeInTheDocument();
    expect(screen.getByLabelText('返回')).toBeInTheDocument();
  });

  it('filters logs by search query', () => {
    useLogStore.setState({
      logs: [
        {
          id: '1',
          content: 'buy milk',
          colorTag: 'daily',
          category: 'log',
          importance: 0,
          createdAt: new Date().toISOString(),
          recordDate: '2026-06-20',
        },
        {
          id: '2',
          content: 'project idea',
          colorTag: 'idea',
          category: 'idea',
          importance: 0,
          createdAt: new Date().toISOString(),
          recordDate: '2026-06-20',
        },
      ],
    });
    render(<LogFlow />);
    expect(screen.getByText('buy milk')).toBeInTheDocument();
    expect(screen.queryByText('project idea')).not.toBeInTheDocument();

    const input = screen.getByLabelText('搜索记录');
    fireEvent.change(input, { target: { value: 'milk' } });
    expect(screen.getByText('buy milk')).toBeInTheDocument();

    fireEvent.change(input, { target: { value: 'idea' } });
    expect(screen.queryByText('buy milk')).not.toBeInTheDocument();
  });

  it('filters logs by color tag', () => {
    useLogStore.setState({
      logs: [
        {
          id: '1',
          content: 'urgent task',
          colorTag: 'urgent',
          category: 'log',
          importance: 0,
          createdAt: new Date().toISOString(),
          recordDate: '2026-06-20',
        },
        {
          id: '2',
          content: 'daily note',
          colorTag: 'daily',
          category: 'log',
          importance: 0,
          createdAt: new Date().toISOString(),
          recordDate: '2026-06-20',
        },
      ],
    });
    render(<LogFlow />);
    fireEvent.click(screen.getByLabelText('筛选与排序'));
    fireEvent.click(screen.getByRole('button', { name: '紧急' }));
    expect(screen.getByText('urgent task')).toBeInTheDocument();
    expect(screen.queryByText('daily note')).not.toBeInTheDocument();
  });

  it('transfers a log to idea from detail drawer', () => {
    useLogStore.setState({
      logs: [
        {
          id: '1',
          content: 'transfer me',
          colorTag: 'daily',
          category: 'log',
          importance: 0,
          createdAt: new Date().toISOString(),
          recordDate: '2026-06-20',
        },
      ],
    });
    render(<LogFlow />);
    fireEvent.click(screen.getByText('transfer me'));
    fireEvent.click(screen.getByLabelText('转为 IDEA'));
    expect(useLogStore.getState().logs[0].category).toBe('idea');
  });

  it('auto-corrects date range when end is before start', async () => {
    useLogStore.setState({ startDate: '2026-06-15', endDate: '2026-06-20' });
    render(<LogFlow />);
    fireEvent.click(screen.getByLabelText('筛选与排序'));

    const endInput = screen.getByLabelText('结束日期');
    fireEvent.change(endInput, { target: { value: '2026-06-10' } });

    await waitFor(() => {
      const state = useLogStore.getState();
      expect(state.startDate).toBe('2026-06-10');
      expect(state.endDate).toBe('2026-06-10');
    });
  });
});
