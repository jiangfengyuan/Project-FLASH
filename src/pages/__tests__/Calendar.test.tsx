import { describe, expect, it, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import Calendar from '@/pages/Calendar';
import { useLogStore } from '@/stores/logStore';
import { useEmotionStore } from '@/stores/emotionStore';
import { format, startOfMonth } from 'date-fns';
import { getTodayStr } from '@/lib/utils';

describe('Calendar', () => {
  beforeEach(() => {
    localStorage.clear();
    useLogStore.setState(useLogStore.getInitialState(), true);
    useEmotionStore.setState(useEmotionStore.getInitialState(), true);
  });

  it('renders current month header', () => {
    render(<Calendar />);
    const today = new Date();
    expect(screen.getByText(format(today, 'yyyy年 M月'))).toBeInTheDocument();
  });

  it('navigates to previous and next month', () => {
    render(<Calendar />);
    const prevButton = screen.getByLabelText('上个月');
    const nextButton = screen.getByLabelText('下个月');

    fireEvent.click(prevButton);
    const lastMonth = startOfMonth(new Date().setMonth(new Date().getMonth() - 1));
    expect(screen.getByText(format(lastMonth, 'yyyy年 M月'))).toBeInTheDocument();

    fireEvent.click(nextButton);
    fireEvent.click(nextButton);
    const nextMonth = startOfMonth(new Date().setMonth(new Date().getMonth() + 1));
    expect(screen.getByText(format(nextMonth, 'yyyy年 M月'))).toBeInTheDocument();
  });

  it('shows today records section', () => {
    render(<Calendar />);
    expect(screen.getByText('今日记录')).toBeInTheDocument();
  });

  it('selects a day and shows records when available', async () => {
    const todayStr = getTodayStr();
    useLogStore.setState({ logs: [] });
    await useLogStore.getState().addLog('today log', 'daily', 'log');

    render(<Calendar />);
    const todayDate = new Date(`${todayStr}T00:00:00`);
    const dayButton = screen.getByLabelText(`${format(todayDate, 'yyyy年M月d日')}，1 条记录`);
    fireEvent.click(dayButton);

    expect(screen.getByText(`${format(todayDate, 'M月d日')} 的记录`)).toBeInTheDocument();
    expect(screen.getAllByText('today log').length).toBeGreaterThan(0);
  });
});
