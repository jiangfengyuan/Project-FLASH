import '@testing-library/jest-dom/vitest';
import 'fake-indexeddb/auto';
import { vi } from 'vitest';

vi.mock('framer-motion', async () => await import('@/__mocks__/framer-motion'));

// jsdom does not implement crypto.randomUUID, so we polyfill it for store tests.
if (typeof crypto !== 'undefined' && !crypto.randomUUID) {
  Object.defineProperty(crypto, 'randomUUID', {
    value: () => `test-uuid-${Math.random().toString(36).slice(2)}`,
    writable: true,
  });
}

// Minimal ResizeObserver polyfill for components that observe layout.
class ResizeObserverPolyfill {
  observe() {}
  unobserve() {}
  disconnect() {}
}

if (typeof window !== 'undefined' && !window.ResizeObserver) {
  window.ResizeObserver = ResizeObserverPolyfill as unknown as typeof ResizeObserver;
}

// Polyfill matchMedia for useReducedMotion hook.
// In tests, default to reduced motion so Framer Motion transitions complete instantly.
if (typeof window !== 'undefined' && !window.matchMedia) {
  window.matchMedia = (query: string) =>
    ({
      matches: query === '(prefers-reduced-motion: reduce)',
      media: query,
      onchange: null,
      addListener: () => {},
      removeListener: () => {},
      addEventListener: () => {},
      removeEventListener: () => {},
      dispatchEvent: () => false,
    }) as unknown as MediaQueryList;
}

// jsdom does not implement Canvas 2D; provide a minimal mock so WaveBackground
// renders without spamming "HTMLCanvasElement.getContext is not implemented" warnings.
function createMockCanvasContext(): CanvasRenderingContext2D {
  const gradient = { addColorStop: () => {} };
  return {
    beginPath: () => {},
    moveTo: () => {},
    lineTo: () => {},
    closePath: () => {},
    createLinearGradient: () => gradient,
    fillRect: () => {},
    clearRect: () => {},
    fill: () => {},
    setTransform: () => {},
  } as unknown as CanvasRenderingContext2D;
}

if (typeof HTMLCanvasElement !== 'undefined') {
  HTMLCanvasElement.prototype.getContext = ((
    contextId: string
  ): ReturnType<typeof HTMLCanvasElement.prototype.getContext> => {
    if (contextId === '2d') {
      return createMockCanvasContext();
    }
    return null;
  }) as typeof HTMLCanvasElement.prototype.getContext;
}

// Polyfill localStorage for Zustand persist tests.
if (typeof window !== 'undefined' && !window.localStorage) {
  let storage: Record<string, string> = {};
  window.localStorage = {
    getItem: (key: string) => storage[key] ?? null,
    setItem: (key: string, value: string) => {
      storage[key] = String(value);
    },
    removeItem: (key: string) => {
      delete storage[key];
    },
    clear: () => {
      storage = {};
    },
    key: (index: number) => Object.keys(storage)[index] ?? null,
    get length() {
      return Object.keys(storage).length;
    },
  } as Storage;
}

// Silence expected console errors in tests if needed; keep this minimal.
const originalError = console.error;
console.error = (...args: unknown[]) => {
  const message = args[0]?.toString() ?? '';
  // Ignore React act() warnings caused by state updates outside act() in jsdom.
  if (message.includes('was not wrapped in act')) return;
  originalError.apply(console, args);
};
