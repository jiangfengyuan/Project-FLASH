import { Component, type ReactNode } from 'react';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
}

interface State {
  hasError: boolean;
  error?: Error;
}

export default class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('ErrorBoundary caught an error:', error, errorInfo);
  }

  handleReload = () => {
    window.location.reload();
  };

  handleReset = () => {
    this.setState({ hasError: false, error: undefined });
  };

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback;
      }
      return (
        <div className="h-screen w-screen flex flex-col items-center justify-center bg-slate-950 text-white p-6">
          <h2 className="text-xl font-semibold mb-2">出错了</h2>
          <p className="text-sm text-slate-400 text-center mb-6 max-w-xs">
            应用遇到了意外问题。你可以尝试刷新页面或重置状态。
          </p>
          <div className="flex gap-3">
            <button
              onClick={this.handleReset}
              className="px-5 py-2 rounded-full bg-white/10 text-sm active:scale-95 transition-transform"
            >
              重试
            </button>
            <button
              onClick={this.handleReload}
              className="px-5 py-2 rounded-full bg-blue-500/80 text-sm active:scale-95 transition-transform"
            >
              刷新页面
            </button>
          </div>
          {this.state.error && (
            <pre className="mt-6 text-[10px] text-slate-500 max-w-xs overflow-auto">
              {this.state.error.message}
            </pre>
          )}
        </div>
      );
    }

    return this.props.children;
  }
}
