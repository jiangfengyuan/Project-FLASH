import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import LogStream from '@/pages/LogStream';
import { useLogStore } from '@/stores/logStore';
import { useNavigationStore } from '@/stores/navigationStore';
import { useToastStore } from '@/stores/toastStore';

describe('LogStream', () => {
  beforeEach(() => {
    localStorage.clear();
    useLogStore.setState(useLogStore.getInitialState(), true);
    useNavigationStore.setState(useNavigationStore.getInitialState(), true);
    useToastStore.setState(useToastStore.getInitialState(), true);
    vi.stubGlobal('navigator', { vibrate: vi.fn() });
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('renders header and search button', () => {
    render(<LogStream />);
    expect(screen.getByText('日志')).toBeInTheDocument();
    expect(screen.getByLabelText('搜索记录')).toBeInTheDocument();
  });

  it('navigates to logFlow when search button is clicked', () => {
    render(<LogStream />);
    fireEvent.click(screen.getByLabelText('搜索记录'));
    expect(useNavigationStore.getState().currentPage).toBe('logFlow');
  });

  it('renders demo logs', () => {
    render(<LogStream />);
    const logs = useLogStore.getState().logs.filter((l) => l.category === 'log');
    expect(logs.length).toBeGreaterThan(0);
    expect(screen.getByText(logs[0].content)).toBeInTheDocument();
  });

  it('opens category sheet when submitting text', () => {
    render(<LogStream />);
    fireEvent.click(screen.getByLabelText('键盘输入'));

    const input = screen.getByLabelText('记录内容');
    fireEvent.change(input, { target: { value: 'new entry' } });
    fireEvent.click(screen.getByLabelText('发送'));

    expect(screen.getByText('保存为')).toBeInTheDocument();
    expect(screen.getByText('作为 LOG 保存')).toBeInTheDocument();
    expect(screen.getByText('作为 IDEA 发送')).toBeInTheDocument();
  });
});
