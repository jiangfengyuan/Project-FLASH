import { StatusBar, Style } from '@capacitor/status-bar';

export async function initNativePlugins(): Promise<void> {
  try {
    await StatusBar.setStyle({ style: Style.Dark });
    await StatusBar.setBackgroundColor({ color: '#0a0e1a' });
  } catch {
    // Web preview or unsupported platform
  }
}
