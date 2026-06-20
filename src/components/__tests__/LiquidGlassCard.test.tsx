import { describe, expect, it, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import LiquidGlassCard from '@/components/LiquidGlassCard';

describe('LiquidGlassCard', () => {
  it('renders children', () => {
    render(<LiquidGlassCard>Hello</LiquidGlassCard>);
    expect(screen.getByText('Hello')).toBeInTheDocument();
  });

  it('calls onClick when clicked', () => {
    const handleClick = vi.fn();
    render(<LiquidGlassCard onClick={handleClick}>Click me</LiquidGlassCard>);
    fireEvent.click(screen.getByText('Click me'));
    expect(handleClick).toHaveBeenCalledTimes(1);
  });

  it('renders color tag', () => {
    render(<LiquidGlassCard colorTag="#ff0000">Card</LiquidGlassCard>);
    const card = screen.getByText('Card').closest('.liquid-glass');
    expect(card).toBeInTheDocument();
  });
});
