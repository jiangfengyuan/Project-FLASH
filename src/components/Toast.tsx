import { useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { CheckCircle, XCircle, Info } from 'lucide-react';
import { useAppStore } from '@/stores/appStore';

export default function Toast() {
  const { toast, clearToast } = useAppStore();

  useEffect(() => {
    if (toast) {
      const timer = setTimeout(clearToast, 3000);
      return () => clearTimeout(timer);
    }
  }, [toast, clearToast]);

  const iconMap = {
    success: CheckCircle,
    error: XCircle,
    info: Info,
  };

  const colorMap = {
    success: 'text-green-400',
    error: 'text-red-400',
    info: 'text-blue-400',
  };

  return (
    <AnimatePresence>
      {toast && (
        <motion.div
          initial={{ opacity: 0, y: 40, scale: 0.9 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: 20, scale: 0.95 }}
          className="fixed bottom-20 left-4 right-4 z-[90] flex items-center justify-center"
        >
          <div className="liquid-glass-sm flex items-center gap-3 px-5 py-3 max-w-sm">
            {(() => {
              const Icon = iconMap[toast.type];
              return <Icon size={18} className={colorMap[toast.type]} />;
            })()}
            <span className="text-sm text-white">{toast.message}</span>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
