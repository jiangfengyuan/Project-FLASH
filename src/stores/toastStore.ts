import { create } from 'zustand';

export type ToastType = 'success' | 'error' | 'info';

interface ToastState {
  toast: { message: string; type: ToastType } | null;
  showToast: (message: string, type?: ToastType) => void;
  clearToast: () => void;
}

export const useToastStore = create<ToastState>((set) => ({
  toast: null,
  showToast: (message, type = 'info') => set({ toast: { message, type } }),
  clearToast: () => set({ toast: null }),
}));
