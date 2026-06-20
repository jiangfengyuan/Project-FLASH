import { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useReducedMotion, springTransition, fadeTransition } from '@/lib/motion';
import { haptic, HAPTIC_TAP } from '@/lib/haptics';

interface EditDrawerProps {
  editingId: string | null;
  initialContent: string;
  onSave: (id: string, content: string) => void;
  onClose: () => void;
  placeholder?: string;
}

export default function EditDrawer({
  editingId,
  initialContent,
  onSave,
  onClose,
  placeholder = '编辑内容...',
}: EditDrawerProps) {
  const reduced = useReducedMotion();
  const [editContent, setEditContent] = useState(initialContent);

  useEffect(() => {
    setEditContent(initialContent);
  }, [initialContent]);

  const handleSave = () => {
    haptic(HAPTIC_TAP);
    if (editingId && editContent.trim()) {
      onSave(editingId, editContent.trim());
    }
    onClose();
  };

  const handleClose = () => {
    haptic(HAPTIC_TAP);
    onClose();
  };

  return (
    <AnimatePresence>
      {editingId && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={fadeTransition(reduced)}
          className="fixed inset-0 z-[80] flex items-end justify-center"
          onClick={handleClose}
          role="dialog"
          aria-modal="true"
          aria-label="编辑内容"
        >
          <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" />
          <motion.div
            initial={{ y: 100 }}
            animate={{ y: 0 }}
            exit={{ y: 100 }}
            transition={springTransition(reduced)}
            className="relative w-full max-w-md mx-auto p-4 pb-8"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="liquid-glass p-4 space-y-4">
              <textarea
                value={editContent}
                onChange={(e) => setEditContent(e.target.value)}
                placeholder={placeholder}
                rows={6}
                autoFocus
                className="w-full bg-transparent text-sm text-white placeholder-slate-500 outline-none resize-none leading-relaxed"
                aria-multiline="true"
              />
              <div className="flex gap-2">
                <button
                  onClick={handleSave}
                  disabled={!editContent.trim()}
                  className="flex-1 liquid-glass-pill py-3 text-white text-sm font-medium active:scale-[0.98] transition-transform disabled:opacity-40"
                >
                  保存
                </button>
                <button
                  onClick={handleClose}
                  className="flex-1 liquid-glass-pill py-3 text-slate-400 text-sm active:scale-[0.98] transition-transform"
                >
                  取消
                </button>
              </div>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
