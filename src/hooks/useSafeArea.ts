import { useEffect } from 'react';

export function useSafeArea(): void {
  useEffect(() => {
    const update = () => {
      const style = document.documentElement.style;
      style.setProperty('--sat', 'env(safe-area-inset-top)');
      style.setProperty('--sar', 'env(safe-area-inset-right)');
      style.setProperty('--sab', 'env(safe-area-inset-bottom)');
      style.setProperty('--sal', 'env(safe-area-inset-left)');
    };

    update();
    window.addEventListener('resize', update);
    return () => window.removeEventListener('resize', update);
  }, []);
}
