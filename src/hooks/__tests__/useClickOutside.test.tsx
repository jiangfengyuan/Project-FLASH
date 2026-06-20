import { describe, expect, it, vi } from 'vitest';
import { render, fireEvent, screen } from '@testing-library/react';
import { useRef } from 'react';
import { useClickOutside } from '../useClickOutside';

function TestComponent({
  enabled,
  onClickOutside,
}: {
  enabled?: boolean;
  onClickOutside: () => void;
}) {
  const ref = useRef<HTMLDivElement>(null);
  useClickOutside(ref, onClickOutside, enabled ?? true);
  return (
    <div>
      <div ref={ref} data-testid="inside">
        inside
      </div>
      <div data-testid="outside">outside</div>
    </div>
  );
}

describe('useClickOutside', () => {
  it('calls handler when clicking outside', () => {
    const handler = vi.fn();
    render(<TestComponent onClickOutside={handler} />);
    fireEvent.mouseDown(screen.getByTestId('outside'));
    expect(handler).toHaveBeenCalled();
  });

  it('does not call handler when clicking inside', () => {
    const handler = vi.fn();
    render(<TestComponent onClickOutside={handler} />);
    fireEvent.mouseDown(screen.getByTestId('inside'));
    expect(handler).not.toHaveBeenCalled();
  });

  it('does not call handler when disabled', () => {
    const handler = vi.fn();
    render(<TestComponent onClickOutside={handler} enabled={false} />);
    fireEvent.mouseDown(screen.getByTestId('outside'));
    expect(handler).not.toHaveBeenCalled();
  });
});
