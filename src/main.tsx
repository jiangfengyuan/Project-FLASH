import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import './index.css';
import App from './App';
import ErrorBoundary from '@/components/ErrorBoundary';
import { initNativePlugins } from '@/lib/nativePlugins';
import { useNavigationStore } from '@/stores/navigationStore';

void initNativePlugins();

const rootElement = document.getElementById('root');
if (!rootElement) {
  throw new Error('Root element #root not found');
}

createRoot(rootElement).render(
  <StrictMode>
    <ErrorBoundary
      onReset={() => {
        useNavigationStore.getState().navigateTo('log');
      }}
    >
      <App />
    </ErrorBoundary>
  </StrictMode>
);
