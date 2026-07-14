import { describe, it, expect, vi, beforeEach } from 'vitest';
import { getPlatform } from '@/lib/platform';

vi.mock('@capacitor/core', () => ({
  Capacitor: {
    getPlatform: () => 'web',
    isNativePlatform: () => false,
  },
}));

describe('getPlatform', () => {
  beforeEach(() => {
    vi.unstubAllGlobals();
  });

  it('defaults to ios on plain web', () => {
    expect(getPlatform()).toBe('ios');
  });

  it('sniffs Android UA', () => {
    vi.stubGlobal('navigator', { userAgent: 'Mozilla/5.0 (Linux; Android 14)' });
    expect(getPlatform()).toBe('android');
  });

  it('sniffs iOS UA', () => {
    vi.stubGlobal('navigator', { userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17)' });
    expect(getPlatform()).toBe('ios');
  });
});
