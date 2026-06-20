import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import DetailDrawer from '@/components/DetailDrawer';
import type { LogItem } from '@/stores/logStore';

const sampleLog: LogItem = {
  id: 'log-1',
  content: 'Sample log content',
  colorTag: 'daily',
  category: 'log',
  importance: 0,
  createdAt: new Date().toISOString(),
  recordDate: '2026-06-20',
};

describe('DetailDrawer', () => {
  beforeEach(() => {
    vi.stubGlobal('navigator', { vibrate: vi.fn() });
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('renders log content and tags', () => {
    render(
      <DetailDrawer
        log={sampleLog}
        onClose={vi.fn()}
        onEdit={vi.fn()}
        onDelete={vi.fn()}
        onTransfer={vi.fn()}
      />
    );
    expect(screen.getByText('Sample log content')).toBeInTheDocument();
    expect(screen.getByText('日常')).toBeInTheDocument();
    expect(screen.getByText('LOG')).toBeInTheDocument();
  });

  it('calls onClose when back button clicked', () => {
    const onClose = vi.fn();
    render(
      <DetailDrawer
        log={sampleLog}
        onClose={onClose}
        onEdit={vi.fn()}
        onDelete={vi.fn()}
        onTransfer={vi.fn()}
      />
    );
    fireEvent.click(screen.getByLabelText('返回'));
    expect(onClose).toHaveBeenCalled();
  });

  it('calls onEdit with log id and content', () => {
    const onEdit = vi.fn();
    render(
      <DetailDrawer
        log={sampleLog}
        onClose={vi.fn()}
        onEdit={onEdit}
        onDelete={vi.fn()}
        onTransfer={vi.fn()}
      />
    );
    fireEvent.click(screen.getByLabelText('编辑'));
    expect(onEdit).toHaveBeenCalledWith('log-1', 'Sample log content');
  });

  it('calls onTransfer when transfer button clicked', () => {
    const onTransfer = vi.fn();
    render(
      <DetailDrawer
        log={sampleLog}
        onClose={vi.fn()}
        onEdit={vi.fn()}
        onDelete={vi.fn()}
        onTransfer={onTransfer}
      />
    );
    fireEvent.click(screen.getByLabelText('转为 IDEA'));
    expect(onTransfer).toHaveBeenCalledWith('log-1');
  });
});
