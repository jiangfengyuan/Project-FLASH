import { useState } from 'react';
import { motion } from 'framer-motion';
import { ChevronLeft, Clock, Edit3, Archive, Trash2 } from 'lucide-react';
import { TAG_COLORS, TAG_NAMES } from '@/lib/constants';
import type { LogItem } from '@/stores/logStore';
import { CATEGORY_LABELS, getImportanceDisplay } from '@/lib/constants';
import { format } from 'date-fns';
import { useReducedMotion, springTransition, fadeTransition } from '@/lib/motion';
import { haptic, HAPTIC_DELETE, HAPTIC_TAP } from '@/lib/haptics';
import ConfirmDrawer from './ConfirmDrawer';

interface DetailDrawerProps {
  log: LogItem;
  onClose: () => void;
  onEdit: (id: string, content: string) => void;
  onDelete: (id: string) => void;
  onTransfer: (id: string) => void;
}

export default function DetailDrawer({
  log,
  onClose,
  onEdit,
  onDelete,
  onTransfer,
}: DetailDrawerProps) {
  const reduced = useReducedMotion();
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const { mark: importanceMark, color: importanceColor } = getImportanceDisplay(log.importance);

  const handleDelete = () => {
    haptic(HAPTIC_DELETE);
    onDelete(log.id);
    setShowDeleteConfirm(false);
    onClose();
  };

  const handleTransfer = () => {
    haptic(HAPTIC_TAP);
    onTransfer(log.id);
    onClose();
  };

  const handleEdit = () => {
    haptic(HAPTIC_TAP);
    onEdit(log.id, log.content);
    onClose();
  };

  return (
    <motion.div
      key="detail"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={fadeTransition(reduced)}
      className="fixed inset-0 z-[90] flex flex-col"
      role="dialog"
      aria-modal="true"
      aria-labelledby="detail-title"
    >
      <div
        className="absolute inset-0 bg-black/60 backdrop-blur-md"
        onClick={onClose}
        aria-hidden="true"
      />
      <motion.div
        initial={{ y: '100%' }}
        animate={{ y: 0 }}
        exit={{ y: '100%' }}
        transition={springTransition(reduced)}
        className="relative flex-1 flex flex-col mt-16"
      >
        <div className="liquid-glass flex-1 flex flex-col mx-0 rounded-t-[28px] overflow-hidden">
          <div className="flex items-center justify-between px-5 pt-5 pb-3">
            <button
              onClick={onClose}
              aria-label="返回"
              className="w-9 h-9 flex items-center justify-center rounded-full bg-white/5 active:bg-white/10 transition-colors"
            >
              <ChevronLeft size={20} className="text-white" />
            </button>
            <span className="text-xs text-slate-400 font-mono">
              {format(new Date(log.createdAt), 'yyyy.MM.dd HH:mm')}
            </span>
            <div className="w-9" />
          </div>

          <div className="flex-1 overflow-y-auto no-scrollbar px-5 pb-8">
            <div className="flex items-center gap-2 mb-4 flex-wrap">
              <span
                className="text-[11px] px-3 py-1 rounded-full font-medium"
                style={{
                  backgroundColor: `${TAG_COLORS[log.colorTag]}25`,
                  color: TAG_COLORS[log.colorTag],
                }}
              >
                {TAG_NAMES[log.colorTag]}
              </span>
              <span
                className="text-[11px] px-3 py-1 rounded-full font-medium"
                style={{
                  backgroundColor: CATEGORY_LABELS[log.category].bg,
                  color: CATEGORY_LABELS[log.category].color,
                }}
              >
                {CATEGORY_LABELS[log.category].text}
              </span>
              {importanceMark && (
                <span
                  className="text-[10px] font-bold"
                  style={{ color: importanceColor }}
                  aria-label={`重要度 ${importanceMark}`}
                >
                  {importanceMark}
                </span>
              )}
            </div>

            <p id="detail-title" className="text-lg text-white leading-relaxed whitespace-pre-wrap">
              {log.content}
            </p>

            <div className="mt-8 pt-4 border-t border-white/10">
              <div className="flex items-center gap-4 text-xs text-slate-500">
                <div className="flex items-center gap-1.5">
                  <Clock size={12} />
                  <span>记录于 {format(new Date(log.createdAt), 'MM月dd日 HH:mm')}</span>
                </div>
              </div>
            </div>
          </div>

          <div className="px-5 pb-20 pt-3 border-t border-white/10 flex gap-2">
            <button
              onClick={handleEdit}
              aria-label="编辑"
              className="flex-1 liquid-glass-pill py-2.5 text-[11px] text-slate-300 flex items-center justify-center gap-1.5 active:scale-[0.98] transition-transform"
            >
              <Edit3 size={12} /> 编辑
            </button>
            <button
              onClick={handleTransfer}
              aria-label={log.category === 'idea' ? '转为 LOG' : '转为 IDEA'}
              className="flex-1 liquid-glass-pill py-2.5 text-[11px] text-amber-300 flex items-center justify-center gap-1.5 active:scale-[0.98] transition-transform"
              style={{ background: 'rgba(255,159,67,0.1)' }}
            >
              <Archive size={12} /> {log.category === 'idea' ? '转LOG' : '转IDEA'}
            </button>
            <button
              onClick={() => setShowDeleteConfirm(true)}
              aria-label="删除"
              className="flex-1 liquid-glass-pill py-2.5 text-[11px] text-red-400 flex items-center justify-center gap-1.5 active:scale-[0.98] transition-transform"
              style={{ background: 'rgba(239,68,68,0.08)' }}
            >
              <Trash2 size={12} /> 删除
            </button>
          </div>
        </div>
      </motion.div>

      <ConfirmDrawer
        open={showDeleteConfirm}
        title="确认删除？"
        description="删除后将无法恢复，是否继续？"
        confirmText="删除"
        cancelText="取消"
        danger
        onConfirm={handleDelete}
        onCancel={() => setShowDeleteConfirm(false)}
      />
    </motion.div>
  );
}
