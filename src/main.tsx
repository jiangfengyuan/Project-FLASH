import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import './index.css';
import App from './App';
import ErrorBoundary from './components/ErrorBoundary';
import { DEMO_LOGS, DEMO_EMOTIONS } from '@/data/demo';
import { useLogStore } from '@/stores/logStore';
import { useEmotionStore } from '@/stores/emotionStore';
import { initNativePlugins } from '@/lib/nativePlugins';

// 开发环境下，若本地没有持久化数据，则自动注入 Demo 数据便于调试
if (import.meta.env.DEV) {
  if (useLogStore.getState().logs.length === 0) {
    useLogStore.setState({ logs: DEMO_LOGS });
  }
  if (useEmotionStore.getState().emotions.length === 0) {
    useEmotionStore.setState({ emotions: DEMO_EMOTIONS });
  }
}

void initNativePlugins();

const rootElement = document.getElementById('root');
if (!rootElement) {
  throw new Error('Root element #root not found');
}

createRoot(rootElement).render(
  <StrictMode>
    <ErrorBoundary>
      <App />
    </ErrorBoundary>
  </StrictMode>
);
