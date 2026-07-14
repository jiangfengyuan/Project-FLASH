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
  },
  ios: {
    backgroundColor: '#0a0e1a',
  },
  plugins: {
    StatusBar: {
      style: 'DARK',
      backgroundColor: '#0a0e1a',
    },
    Keyboard: {
      resize: 'ionic',
    },
  },
};

export default config;
