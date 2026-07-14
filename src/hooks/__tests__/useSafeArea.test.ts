import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { createElement } from 'react';
import { useSafeArea } from '@/hooks/useSafeArea';

function TestComponent() {
  useSafeArea();
  return null;
}

describe('useSafeArea', () => {
  it('sets safe-area CSS variables on document element', () => {
    render(createElement(TestComponent));
    const style = document.documentElement.style;
    expect(style.getPropertyValue('--sat')).toBe('env(safe-area-inset-top)');
    expect(style.getPropertyValue('--sab')).toBe('env(safe-area-inset-bottom)');
  });
});
