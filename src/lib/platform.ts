// Phase 3 platform visual adaptation uses CSS/Tailwind tokens only.
// Jetpack Compose / SwiftUI introduction is intentionally deferred to Phase 5.

import { Capacitor } from '@capacitor/core';

export type Platform = 'android' | 'ios' | 'web';

export function getPlatform(): Platform {
  const cap = Capacitor.getPlatform();
  if (cap === 'android') return 'android';
  if (cap === 'ios') return 'ios';

  // Web preview: sniff User Agent.
  const ua = typeof navigator !== 'undefined' ? navigator.userAgent : '';
  if (/Android/i.test(ua)) return 'android';
  if (/iPhone|iPad|iPod|Macintosh/i.test(ua)) return 'ios';

  // Default to iOS visual on unknown desktop/web.
  return 'ios';
}

export function isNative(): boolean {
  return Capacitor.isNativePlatform();
}
