import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { render, act } from '@testing-library/react';
import WaveBackground from '@/components/WaveBackground';

interface CtxMock {
  beginPath: ReturnType<typeof vi.fn>;
  moveTo: ReturnType<typeof vi.fn>;
  lineTo: ReturnType<typeof vi.fn>;
  closePath: ReturnType<typeof vi.fn>;
  createLinearGradient: ReturnType<typeof vi.fn>;
  fillRect: ReturnType<typeof vi.fn>;
  clearRect: ReturnType<typeof vi.fn>;
  fill: ReturnType<typeof vi.fn>;
  setTransform: ReturnType<typeof vi.fn>;
}

const createCtxMock = (): CtxMock => ({
  beginPath: vi.fn(),
  moveTo: vi.fn(),
  lineTo: vi.fn(),
  closePath: vi.fn(),
  createLinearGradient: vi.fn(() => ({ addColorStop: vi.fn() })),
  fillRect: vi.fn(),
  clearRect: vi.fn(),
  fill: vi.fn(),
  setTransform: vi.fn(),
});

const reducedMotionMedia = (): MediaQueryList =>
  ({
    matches: true,
    media: '(prefers-reduced-motion: reduce)',
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  }) as unknown as MediaQueryList;

const noMotionPreferenceMedia = (): MediaQueryList =>
  ({
    matches: false,
    media: '(prefers-reduced-motion: reduce)',
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  }) as unknown as MediaQueryList;

describe('WaveBackground', () => {
  let originalGetContext: typeof HTMLCanvasElement.prototype.getContext;
  let lastCtx: CtxMock | null = null;
  let rafSpy: ReturnType<typeof vi.spyOn>;
  let cafSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    // eslint-disable-next-line @typescript-eslint/unbound-method
    originalGetContext = HTMLCanvasElement.prototype.getContext;
    HTMLCanvasElement.prototype.getContext = vi.fn(() => {
      lastCtx = createCtxMock();
      return lastCtx as unknown as CanvasRenderingContext2D;
    }) as unknown as typeof HTMLCanvasElement.prototype.getContext;

    rafSpy = vi.spyOn(window, 'requestAnimationFrame');
    cafSpy = vi.spyOn(window, 'cancelAnimationFrame');
  });

  afterEach(() => {
    vi.useRealTimers();
    HTMLCanvasElement.prototype.getContext = originalGetContext;
    lastCtx = null;
    vi.restoreAllMocks();
  });

  it('renders a canvas element', () => {
    const { container } = render(<WaveBackground />);
    expect(container.querySelector('canvas')).toBeInTheDocument();
  });

  it('initializes canvas size to window dimensions', () => {
    const { container } = render(<WaveBackground />);
    const canvas = container.querySelector('canvas')!;
    expect(canvas.style.width).toBe(`${window.innerWidth}px`);
    expect(canvas.style.height).toBe(`${window.innerHeight}px`);
  });

  it('draws static background when reduced motion is preferred', () => {
    vi.stubGlobal('matchMedia', (query: string) =>
      query === '(prefers-reduced-motion: reduce)'
        ? reducedMotionMedia()
        : noMotionPreferenceMedia()
    );
    render(<WaveBackground />);
    expect(lastCtx).not.toBeNull();
    expect(lastCtx!.fillRect).toHaveBeenCalled();
    expect(rafSpy).not.toHaveBeenCalled();
  });

  it('starts animation loop when motion is not reduced', () => {
    vi.stubGlobal('matchMedia', () => noMotionPreferenceMedia());
    render(<WaveBackground />);
    expect(rafSpy).toHaveBeenCalled();
    void act(() => {
      vi.advanceTimersByTime(16);
    });
    expect(lastCtx).not.toBeNull();
    expect(lastCtx!.clearRect).toHaveBeenCalled();
  });

  it('removes listeners and cancels rAF on unmount', () => {
    vi.stubGlobal('matchMedia', () => noMotionPreferenceMedia());
    const removeEventListenerSpy = vi.spyOn(window, 'removeEventListener');
    const { unmount } = render(<WaveBackground />);
    unmount();
    expect(removeEventListenerSpy).toHaveBeenCalledWith('resize', expect.any(Function));
    expect(cafSpy).toHaveBeenCalled();
  });
});
