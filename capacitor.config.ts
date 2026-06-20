import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.flash.app',
  appName: '一闪',
  webDir: 'dist',
  server: {
    androidScheme: 'https',
  },
  android: {
    backgroundColor: '#0a0e1a',
    statusBarStyle: 'LIGHT',
    statusBarColor: '#0a0e1a',
  },
  ios: {
    backgroundColor: '#0a0e1a',
    statusBarStyle: 'LIGHT',
  },
};

export default config;
