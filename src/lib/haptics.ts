/**
 * Lightweight haptic feedback helper.
 * Falls back silently on browsers/devices that do not support vibration.
 */
export function haptic(pattern: number | number[] = 10): void {
  if (typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function') {
    try {
      navigator.vibrate(pattern);
    } catch {
      // Ignore vibration errors (e.g. user denied permission).
    }
  }
}

export const HAPTIC_TAP = 8;
export const HAPTIC_SUCCESS = [20, 30, 20];
export const HAPTIC_WARNING = 30;
export const HAPTIC_DELETE = [30, 40, 30];
