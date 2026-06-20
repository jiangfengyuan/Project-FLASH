import { beforeEach, describe, expect, it } from 'vitest';
import { useToastStore } from '@/stores/toastStore';

describe('toastStore', () => {
  beforeEach(() => {
    useToastStore.setState(useToastStore.getInitialState(), true);
  });

  it('shows a toast', () => {
    useToastStore.getState().showToast('hello', 'success');
    expect(useToastStore.getState().toast).toEqual({ message: 'hello', type: 'success' });
  });

  it('defaults to info type', () => {
    useToastStore.getState().showToast('info message');
    expect(useToastStore.getState().toast).toEqual({ message: 'info message', type: 'info' });
  });

  it('clears toast', () => {
    useToastStore.getState().showToast('hello');
    useToastStore.getState().clearToast();
    expect(useToastStore.getState().toast).toBeNull();
  });
});
