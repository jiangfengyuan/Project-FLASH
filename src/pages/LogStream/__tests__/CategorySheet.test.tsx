import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import CategorySheet from '@/pages/LogStream/CategorySheet';

describe('CategorySheet', () => {
  beforeEach(() => {
    vi.stubGlobal('navigator', { vibrate: vi.fn() });
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('does not render when closed', () => {
    render(<CategorySheet open={false} onClose={vi.fn()} onSave={vi.fn()} />);
    expect(screen.queryByText('保存为')).not.toBeInTheDocument();
  });

  it('calls onSave with log category', () => {
    const onSave = vi.fn();
    render(<CategorySheet open onClose={vi.fn()} onSave={onSave} />);
    fireEvent.click(screen.getByText('作为 LOG 保存'));
    expect(onSave).toHaveBeenCalledWith('log');
  });

  it('calls onSave with idea category', () => {
    const onSave = vi.fn();
    render(<CategorySheet open onClose={vi.fn()} onSave={onSave} />);
    fireEvent.click(screen.getByText('作为 IDEA 发送'));
    expect(onSave).toHaveBeenCalledWith('idea');
  });

  it('calls onClose when cancel clicked', () => {
    const onClose = vi.fn();
    render(<CategorySheet open onClose={onClose} onSave={vi.fn()} />);
    fireEvent.click(screen.getByText('取消'));
    expect(onClose).toHaveBeenCalled();
  });
});
