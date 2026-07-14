import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type ThemeMode = 'system' | 'dark';

interface ThemeState {
  mode: ThemeMode;
  resolved: 'dark' | 'light';
  setMode: (mode: ThemeMode) => void;
  resolvedTheme: () => 'dark' | 'light';
}

function getSystemTheme(): 'dark' | 'light' {
  if (typeof window === 'undefined') return 'dark';
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function resolveTheme(mode: ThemeMode): 'dark' | 'light' {
  return mode === 'system' ? getSystemTheme() : mode;
}

export const useThemeStore = create<ThemeState>()(
  persist(
    (set, get) => ({
      mode: 'system',
      resolved: resolveTheme('system'),
      setMode: (mode) => set({ mode, resolved: resolveTheme(mode) }),
      resolvedTheme: () => get().resolved,
    }),
    {
      name: 'flash-theme',
      version: 1,
      partialize: (state) => ({ mode: state.mode }),
    }
  )
);

// Keep the resolved theme in sync when mode is "system" and the OS theme changes.
if (typeof window !== 'undefined') {
  const mql = window.matchMedia('(prefers-color-scheme: dark)');
  const handler = () => {
    const state = useThemeStore.getState();
    if (state.mode === 'system') {
      useThemeStore.setState({ resolved: getSystemTheme() });
    }
  };
  mql.addEventListener('change', handler);
}

// When mode is mutated directly (e.g. in tests or via rehydration), reconcile resolved.
useThemeStore.subscribe((state, prevState) => {
  if (state.mode !== prevState.mode) {
    const nextResolved = resolveTheme(state.mode);
    if (state.resolved !== nextResolved) {
      useThemeStore.setState({ resolved: nextResolved });
    }
  }
});
