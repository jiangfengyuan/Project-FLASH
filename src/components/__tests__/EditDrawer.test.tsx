import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import EditDrawer from '@/components/EditDrawer';

describe('EditDrawer', () => {
  beforeEach(() => {
    vi.stubGlobal('navigator', { vibrate: vi.fn() });
    // The drawer's autoFocus calls focus() on mount, which puts the textarea in
    // a state where fireEvent.input does not update the controlled value in
    // jsdom. Mocking focus() avoids that test-environment quirk.
    vi.spyOn(HTMLTextAreaElement.prototype, 'focus').mockImplementation(() => {});
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it('does not render when editingId is null', () => {
    render(
      <EditDrawer editingId={null} initialContent="hello" onSave={vi.fn()} onClose={vi.fn()} />
    );
    expect(screen.queryByText('保存')).not.toBeInTheDocument();
  });

  it('renders with initial content and saves trimmed text', () => {
    const onSave = vi.fn();
    const onClose = vi.fn();
    render(
      <EditDrawer
        editingId="log-1"
        initialContent="  hello world  "
        onSave={onSave}
        onClose={onClose}
      />
    );
    const textarea = screen.getByRole('textbox');
    expect(textarea).toHaveValue('  hello world  ');

    fireEvent.change(textarea, { target: { value: 'updated' } });
    fireEvent.click(screen.getByText('保存'));
    expect(onSave).toHaveBeenCalledWith('log-1', 'updated');
    expect(onClose).toHaveBeenCalled();
  });

  it('does not save when content is empty', () => {
    const onSave = vi.fn();
    const onClose = vi.fn();
    render(
      <EditDrawer editingId="log-1" initialContent="content" onSave={onSave} onClose={onClose} />
    );
    const textarea = screen.getByRole('textbox');
    fireEvent.change(textarea, { target: { value: '   ' } });
    const saveButton = screen.getByText('保存');
    expect(saveButton).toBeDisabled();
    fireEvent.click(saveButton);
    expect(onSave).not.toHaveBeenCalled();
  });

  it('calls onClose when cancel clicked', () => {
    const onClose = vi.fn();
    render(
      <EditDrawer editingId="log-1" initialContent="content" onSave={vi.fn()} onClose={onClose} />
    );
    fireEvent.click(screen.getByText('取消'));
    expect(onClose).toHaveBeenCalled();
  });

  it('resets edited text when switching to a different log with identical content', async () => {
    const { rerender } = render(
      <EditDrawer editingId="log-1" initialContent="same" onSave={vi.fn()} onClose={vi.fn()} />
    );
    const textarea = screen.getByRole('textbox');
    fireEvent.input(textarea, { target: { value: 'user typed something else' } });
    expect(textarea).toHaveValue('user typed something else');

    // A different log with the same initial content must still reset the draft.
    rerender(
      <EditDrawer editingId="log-2" initialContent="same" onSave={vi.fn()} onClose={vi.fn()} />
    );
    await waitFor(() => expect(screen.getByRole('textbox')).toHaveValue('same'));
  });
});
