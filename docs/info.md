Using Node.js 20, Tailwind CSS v3.4.19, and Vite v8.0.16

Tailwind CSS has been set up with a custom dark/glass-morphism theme.

Setup complete: D:\Developer\projects\flash-Alpha-v6\app

Actual shared components (src/components/):
BottomNav, SplashScreen, Toast, WaveBackground,
LiquidGlassCard, ErrorBoundary, DetailDrawer, EditDrawer, ConfirmDrawer

Usage:
import { cn } from '@/lib/utils'
import LiquidGlassCard from '@/components/LiquidGlassCard'

Structure:
src/components/ Shared UI components
src/pages/ Page-level components
src/stores/ Zustand global stores
src/hooks/ Custom hooks
src/lib/ Utility functions and shared constants
src/App.tsx Root React component
src/index.css Global styles
src/main.tsx Entry point for rendering
index.html HTML entry point
tailwind.config.js Tailwind theme configuration
vite.config.ts Vite build and dev server settings
postcss.config.js PostCSS configuration
