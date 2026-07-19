import { useEffect, useState } from 'react';

function getInitialReducedMotion(): boolean {
  if (typeof window === 'undefined') return false;
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

export function useReducedMotion(): boolean {
  const [reduced, setReduced] = useState(getInitialReducedMotion);

  useEffect(() => {
    if (typeof window === 'undefined') return;

    const mql = window.matchMedia('(prefers-reduced-motion: reduce)');
    const handler = (event: MediaQueryListEvent) => setReduced(event.matches);
    mql.addEventListener('change', handler);
    return () => mql.removeEventListener('change', handler);
  }, []);

  return reduced;
}

export const springTransition = (reduced: boolean) =>
  reduced ? { duration: 0 } : { type: 'spring' as const, damping: 28, stiffness: 300 };

export const fadeTransition = (reduced: boolean) => (reduced ? { duration: 0 } : { duration: 0.2 });
