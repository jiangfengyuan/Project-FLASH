import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import InputArea from '@/pages/LogStream/InputArea';
import { useToastStore } from '@/stores/toastStore';

describe('InputArea', () => {
  beforeEach(() => {
    localStorage.clear();
    useToastStore.setState(useToastStore.getInitialState(), true);
    vi.stubGlobal('navigator', { vibrate: vi.fn() });
    vi.stubGlobal(
      'SpeechRecognition',
      vi.fn(function (this: unknown) {
        return {
          lang: '',
          continuous: false,
          interimResults: false,
          onresult: null as ((event: Event) => void) | null,
          onerror: null as ((event: Event) => void) | null,
          onend: null as (() => void) | null,
          start: vi.fn(),
          stop: vi.fn(),
        };
      })
    );
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('renders idle action buttons', () => {
    render(<InputArea mode="idle" onModeChange={vi.fn()} onSubmit={vi.fn()} />);
    expect(screen.getByLabelText('按住录音')).toBeInTheDocument();
    expect(screen.getByLabelText('键盘输入')).toBeInTheDocument();
  });

  it('switches to typing mode when keyboard button is clicked', () => {
    const onModeChange = vi.fn();
    render(<InputArea mode="idle" onModeChange={onModeChange} onSubmit={vi.fn()} />);
    fireEvent.click(screen.getByLabelText('键盘输入'));
    expect(onModeChange).toHaveBeenCalledWith('typing');
  });

  it('submits typed text with selected tag', () => {
    const onSubmit = vi.fn();
    const { rerender } = render(
      <InputArea mode="idle" onModeChange={vi.fn()} onSubmit={onSubmit} />
    );

    // Switch to typing mode
    fireEvent.click(screen.getByLabelText('键盘输入'));
    rerender(<InputArea mode="typing" onModeChange={vi.fn()} onSubmit={onSubmit} />);

    // Select a tag
    fireEvent.click(screen.getByText('灵感'));

    // Type and submit
    const input = screen.getByLabelText('记录内容');
    fireEvent.change(input, { target: { value: 'test note' } });
    fireEvent.click(screen.getByLabelText('发送'));

    expect(onSubmit).toHaveBeenCalledWith('test note', 'inspiration');
  });

  it('does not submit empty text', () => {
    const onSubmit = vi.fn();
    const { rerender } = render(
      <InputArea mode="idle" onModeChange={vi.fn()} onSubmit={onSubmit} />
    );
    fireEvent.click(screen.getByLabelText('键盘输入'));
    rerender(<InputArea mode="typing" onModeChange={vi.fn()} onSubmit={onSubmit} />);

    fireEvent.click(screen.getByLabelText('发送'));
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('truncates text over 140 characters, submits truncated text and shows toast', () => {
    const onSubmit = vi.fn();
    const { rerender } = render(
      <InputArea mode="idle" onModeChange={vi.fn()} onSubmit={onSubmit} />
    );
    fireEvent.click(screen.getByLabelText('键盘输入'));
    rerender(<InputArea mode="typing" onModeChange={vi.fn()} onSubmit={onSubmit} />);

    const input = screen.getByLabelText('记录内容');
    const longText = 'a'.repeat(150);
    fireEvent.change(input, { target: { value: longText } });
    fireEvent.click(screen.getByLabelText('发送'));

    expect(onSubmit).toHaveBeenCalledWith('a'.repeat(140), null);
    expect(useToastStore.getState().toast?.message).toContain('140');
  });

  it('transitions to preview when speech recognition ends naturally', async () => {
    const onModeChange = vi.fn();
    render(<InputArea mode="idle" onModeChange={onModeChange} onSubmit={vi.fn()} />);

    const micButton = screen.getByLabelText('按住录音');
    fireEvent.pointerDown(micButton);

    const recognitionCtor = (
      globalThis as unknown as { SpeechRecognition: ReturnType<typeof vi.fn> }
    ).SpeechRecognition;
    const recognitionInstance = recognitionCtor.mock.results[0].value as {
      onend: (() => void) | null;
    };
    recognitionInstance.onend?.();

    await waitFor(() => expect(onModeChange).toHaveBeenCalledWith('preview'));
  });
});
