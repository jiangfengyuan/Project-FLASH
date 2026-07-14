import { describe, it, expect, beforeEach } from 'vitest';
import { useThemeStore } from '@/stores/themeStore';

describe('themeStore', () => {
  beforeEach(() => {
    localStorage.clear();
    useThemeStore.setState(useThemeStore.getInitialState(), true);
  });

  it('defaults to system mode', () => {
    expect(useThemeStore.getState().mode).toBe('system');
  });

  it('persists selected mode', () => {
    useThemeStore.getState().setMode('dark');
    expect(useThemeStore.getState().mode).toBe('dark');
  });

  it('resolves dark when mode is dark', () => {
    useThemeStore.setState({ mode: 'dark' });
    expect(useThemeStore.getState().resolvedTheme()).toBe('dark');
  });
});
