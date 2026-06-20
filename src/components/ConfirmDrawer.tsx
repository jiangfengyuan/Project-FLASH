import { motion, AnimatePresence } from 'framer-motion';
import { AlertTriangle, X, Check } from 'lucide-react';
import { useReducedMotion, springTransition, fadeTransition } from '@/lib/motion';

interface ConfirmDrawerProps {
  open: boolean;
  title: string;
  description: string;
  confirmText?: string;
  cancelText?: string;
  danger?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

export default function ConfirmDrawer({
  open,
  title,
  description,
  confirmText = '确认',
  cancelText = '取消',
  danger = true,
  onConfirm,
  onCancel,
}: ConfirmDrawerProps) {
  const reduced = useReducedMotion();

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={fadeTransition(reduced)}
          className="fixed inset-0 z-[95] flex items-end justify-center"
          role="alertdialog"
          aria-modal="true"
          aria-labelledby="confirm-title"
          onClick={onCancel}
        >
          <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" />
          <motion.div
            initial={{ y: 100 }}
            animate={{ y: 0 }}
            exit={{ y: 100 }}
            transition={springTransition(reduced)}
            className="relative w-full max-w-md mx-auto p-4 pb-8"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="liquid-glass p-5 space-y-4">
              <div
                className={`flex items-center gap-3 ${danger ? 'text-red-400' : 'text-blue-400'}`}
              >
                <AlertTriangle size={24} />
                <h3 id="confirm-title" className="text-base font-medium text-white">
                  {title}
                </h3>
              </div>
              <p className="text-sm text-slate-400">{description}</p>
              <div className="flex gap-2">
                <button
                  onClick={onCancel}
                  className="flex-1 liquid-glass-pill py-3 text-slate-300 text-sm active:scale-[0.98] transition-transform flex items-center justify-center gap-1.5"
                >
                  <X size={14} /> {cancelText}
                </button>
                <button
                  onClick={onConfirm}
                  className={`flex-1 liquid-glass-pill py-3 text-white text-sm active:scale-[0.98] transition-transform flex items-center justify-center gap-1.5 ${
                    danger ? 'bg-red-500/20' : 'bg-blue-500/20'
                  }`}
                >
                  <Check size={14} /> {confirmText}
                </button>
              </div>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
