import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import Settings from './index';
import { useLogStore } from '@/stores/logStore';
import { useEmotionStore } from '@/stores/emotionStore';

describe('Settings', () => {
  beforeEach(() => {
    useLogStore.setState({ logs: [] });
    useEmotionStore.setState({ emotions: [] });
  });

  it('renders export and import buttons', () => {
    render(<Settings />);
    expect(screen.getByText('导出备份')).toBeInTheDocument();
    expect(screen.getByText('导入备份')).toBeInTheDocument();
  });

  it('opens export drawer when export button is clicked', () => {
    render(<Settings />);
    fireEvent.click(screen.getByText('导出备份'));
    // The drawer opens; clicking export inside would show toast; test the drawer presence instead
    expect(screen.getByPlaceholderText(/备份/i)).toBeInTheDocument();
  });
});
