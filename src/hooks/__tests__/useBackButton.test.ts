import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { Mock } from 'vitest';
import { render } from '@testing-library/react';
import { createElement } from 'react';
import { useBackButton } from '@/hooks/useBackButton';
import { useNavigationStore } from '@/stores/navigationStore';

const addListener = vi.hoisted(
  () =>
    vi.fn(() => Promise.resolve({ remove: vi.fn() })) as Mock<
      (
        event: 'backButton',
        handler: (event: { canGoBack: boolean }) => void
      ) => Promise<{ remove: () => void }>
    >
);
const exitApp = vi.hoisted(() => vi.fn());
const isNativePlatform = vi.hoisted(() => vi.fn(() => true));

vi.mock('@capacitor/app', () => ({
  App: { addListener, exitApp },
}));

vi.mock('@capacitor/core', () => ({
  Capacitor: { isNativePlatform },
}));

function TestComponent() {
  useBackButton(exitApp);
  return createElement('div');
}

describe('useBackButton', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    useNavigationStore.setState({ currentPage: 'log', activeTab: 'log' });
  });

  it('registers back button listener', () => {
    render(createElement(TestComponent));
    expect(addListener).toHaveBeenCalledWith('backButton', expect.any(Function));
  });

  it('exits app on tab home page', async () => {
    render(createElement(TestComponent));
    const handler = addListener.mock.calls[0][1];
    handler({ canGoBack: true });
    await Promise.resolve();
    expect(exitApp).toHaveBeenCalled();
  });

  it('navigates to active tab on non-tab page', async () => {
    useNavigationStore.setState({ currentPage: 'settings', activeTab: 'log' });
    render(createElement(TestComponent));
    const handler = addListener.mock.calls[0][1];
    handler({ canGoBack: true });
    await Promise.resolve();
    expect(useNavigationStore.getState().currentPage).toBe('log');
    expect(exitApp).not.toHaveBeenCalled();
  });

  it('does not register listener on non-native platforms', () => {
    isNativePlatform.mockReturnValueOnce(false);
    render(createElement(TestComponent));
    expect(addListener).not.toHaveBeenCalled();
  });
});
