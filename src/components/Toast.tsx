import { useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { CheckCircle, XCircle, Info } from 'lucide-react';
import { useToastStore } from '@/stores/toastStore';
import { useReducedMotion } from '@/lib/motion';

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

export default function Toast() {
  const reduced = useReducedMotion();
  const toast = useToastStore((state) => state.toast);
  const clearToast = useToastStore((state) => state.clearToast);

  useEffect(() => {
    if (toast) {
      const timer = setTimeout(clearToast, 3000);
      return () => clearTimeout(timer);
    }
  }, [toast, clearToast]);

  return (
    <AnimatePresence>
      {toast && (
        <motion.div
          initial={{ opacity: 0, y: 40, scale: 0.9 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: 20, scale: 0.95 }}
          transition={{ duration: reduced ? 0 : 0.25 }}
          role="status"
          aria-live="polite"
          className="fixed bottom-20 left-4 right-4 z-[90] flex items-center justify-center"
        >
          <div className="liquid-glass-sm flex items-center gap-3 px-5 py-3 max-w-sm">
            {(() => {
              const Icon = iconMap[toast.type];
              return <Icon size={18} className={colorMap[toast.type]} aria-hidden="true" />;
            })()}
            <span className="text-sm text-white">{toast.message}</span>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
