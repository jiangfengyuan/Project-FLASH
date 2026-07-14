import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export type ThemeMode = 'system' | 'dark' | 'light';

interface ThemeState {
  mode: ThemeMode;
  setMode: (mode: ThemeMode) => void;
  resolvedTheme: () => 'dark' | 'light';
}

function getSystemTheme(): 'dark' | 'light' {
  if (typeof window === 'undefined') return 'dark';
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export const useThemeStore = create<ThemeState>()(
  persist(
    (set, get) => ({
      mode: 'system',
      setMode: (mode) => set({ mode }),
      resolvedTheme: () => {
        const mode = get().mode;
        return mode === 'system' ? getSystemTheme() : mode;
      },
    }),
    {
      name: 'flash-theme',
      version: 1,
      partialize: (state) => ({ mode: state.mode }),
    }
  )
);
