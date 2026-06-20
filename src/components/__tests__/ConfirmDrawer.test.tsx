import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import ConfirmDrawer from '@/components/ConfirmDrawer';

describe('ConfirmDrawer', () => {
  beforeEach(() => {
    vi.stubGlobal('navigator', { vibrate: vi.fn() });
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('does not render when closed', () => {
    render(
      <ConfirmDrawer
        open={false}
        title="Confirm?"
        description="desc"
        onConfirm={vi.fn()}
        onCancel={vi.fn()}
      />
    );
    expect(screen.queryByText('Confirm?')).not.toBeInTheDocument();
  });

  it('renders and calls onConfirm', () => {
    const onConfirm = vi.fn();
    const onCancel = vi.fn();
    render(
      <ConfirmDrawer
        open
        title="Confirm?"
        description="desc"
        confirmText="Yes"
        cancelText="No"
        onConfirm={onConfirm}
        onCancel={onCancel}
      />
    );
    expect(screen.getByText('Confirm?')).toBeInTheDocument();
    fireEvent.click(screen.getByText('Yes'));
    expect(onConfirm).toHaveBeenCalled();
    expect(onCancel).not.toHaveBeenCalled();
  });

  it('calls onCancel when cancel or backdrop clicked', () => {
    const onCancel = vi.fn();
    const { container } = render(
      <ConfirmDrawer
        open
        title="Confirm?"
        description="desc"
        onConfirm={vi.fn()}
        onCancel={onCancel}
      />
    );
    fireEvent.click(screen.getByText('取消'));
    expect(onCancel).toHaveBeenCalledTimes(1);

    // backdrop is the outer motion div; click on it directly
    const backdrop = container.firstChild?.firstChild;
    if (backdrop) fireEvent.click(backdrop as Element);
    expect(onCancel).toHaveBeenCalledTimes(2);
  });
});
