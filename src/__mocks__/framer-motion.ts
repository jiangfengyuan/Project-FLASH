import { createElement, forwardRef } from 'react';
import type { ReactNode } from 'react';

interface AnimatePresenceProps {
  children?: ReactNode;
  mode?: string;
  initial?: boolean;
}

export const AnimatePresence = ({ children }: AnimatePresenceProps) =>
  createElement('div', null, children);

export const motion = new Proxy(
  {},
  {
    get(_, tag: string) {
      return forwardRef<unknown, Record<string, unknown>>(({ children, ...props }, ref) => {
        const cleaned = { ...props, ref };
        delete (cleaned as Record<string, unknown>).initial;
        delete (cleaned as Record<string, unknown>).animate;
        delete (cleaned as Record<string, unknown>).exit;
        delete (cleaned as Record<string, unknown>).variants;
        delete (cleaned as Record<string, unknown>).transition;
        delete (cleaned as Record<string, unknown>).whileTap;
        delete (cleaned as Record<string, unknown>).whileHover;
        delete (cleaned as Record<string, unknown>).layout;
        delete (cleaned as Record<string, unknown>).layoutId;
        return createElement(tag as string, cleaned, children as ReactNode);
      });
    },
  }
) as Record<string, unknown>;
