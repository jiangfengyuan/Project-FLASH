import { describe, it, expect, vi, beforeEach } from 'vitest';
import { initNativePlugins } from '@/lib/nativePlugins';

const { setStyle, setBackgroundColor } = vi.hoisted(() => ({
  setStyle: vi.fn(),
  setBackgroundColor: vi.fn(),
}));

vi.mock('@capacitor/status-bar', () => ({
  StatusBar: { setStyle, setBackgroundColor },
  Style: { Dark: 'DARK' },
}));

describe('initNativePlugins', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('sets status bar to dark style and background color', async () => {
    await initNativePlugins();
    expect(setStyle).toHaveBeenCalledWith({ style: 'DARK' });
    expect(setBackgroundColor).toHaveBeenCalledWith({ color: '#0a0e1a' });
  });

  it('silently ignores errors on unsupported platforms', async () => {
    setStyle.mockRejectedValueOnce(new Error('not available'));
    await expect(initNativePlugins()).resolves.toBeUndefined();
  });
});
