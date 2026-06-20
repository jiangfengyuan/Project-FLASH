import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { useToastStore } from '@/stores/toastStore';
import Toast from '@/components/Toast';

describe('Toast', () => {
  beforeEach(() => {
    useToastStore.setState(useToastStore.getInitialState(), true);
  });

  it('shows toast message', () => {
    useToastStore.getState().showToast('保存成功', 'success');
    render(<Toast />);
    expect(screen.getByText('保存成功')).toBeInTheDocument();
  });
});
