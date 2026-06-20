import { useState, memo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Lightbulb, Trash2, Edit3, Archive, MoreVertical } from 'lucide-react';
import { TAG_COLORS } from '@/lib/constants';
import type { LogItem } from '@/stores/logStore';
import { CATEGORY_LABELS, getImportanceDisplay } from '@/lib/constants';
import LiquidGlassCard from '@/components/LiquidGlassCard';
import ConfirmDrawer from '@/components/ConfirmDrawer';
import { format } from 'date-fns';
import { parseLocalDate } from '@/lib/utils';
import { useReducedMotion, fadeTransition } from '@/lib/motion';
import { haptic, HAPTIC_DELETE, HAPTIC_TAP } from '@/lib/haptics';

interface IdeaListProps {
  ideas: LogItem[];
  onDetail: (idea: LogItem) => void;
  onMenuAction: (action: 'edit' | 'delete' | 'transfer', id: string) => void;
  menuOpenId: string | null;
  onMenuToggle: (id: string) => void;
}

export const IdeaItem = memo(function IdeaItem({
  idea,
  onDetail,
  onMenuAction,
  menuOpenId,
  onMenuToggle,
}: {
  idea: LogItem;
  onDetail: (idea: LogItem) => void;
  onMenuAction: (action: 'edit' | 'delete' | 'transfer', id: string) => void;
  menuOpenId: string | null;
  onMenuToggle: (id: string) => void;
}) {
  const reduced = useReducedMotion();
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const { mark: importanceMark, color: importanceColor } = getImportanceDisplay(idea.importance);
  const isMenuOpen = menuOpenId === idea.id;

  const handleMenuClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    haptic(HAPTIC_TAP);
    onMenuToggle(idea.id);
  };

  const handleTransfer = (e: React.MouseEvent) => {
    e.stopPropagation();
    haptic(HAPTIC_TAP);
    onMenuAction('transfer', idea.id);
  };

  const handleEdit = (e: React.MouseEvent) => {
    e.stopPropagation();
    haptic(HAPTIC_TAP);
    onMenuAction('edit', idea.id);
  };

  const handleDelete = () => {
    haptic(HAPTIC_DELETE);
    onMenuAction('delete', idea.id);
    setShowDeleteConfirm(false);
  };

  return (
    <LiquidGlassCard
      onClick={() => {
        if (!isMenuOpen) onDetail(idea);
      }}
    >
      <div className="p-4 relative">
        <div className="flex items-center gap-2 mb-1.5">
          <span className="text-[11px] text-slate-300 font-mono">
            {format(parseLocalDate(idea.recordDate), 'yy.MM.dd')}
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

        <div className="flex items-start justify-between gap-3">
          <p className="text-[15px] text-white leading-relaxed line-clamp-3 flex-1">
            {idea.content}
          </p>
          <div className="flex flex-col items-end gap-1.5 flex-shrink-0 mt-0.5">
            <button
              onClick={handleMenuClick}
              aria-label="更多操作"
              className="w-7 h-7 flex items-center justify-center rounded-full active:bg-white/10 transition-colors"
            >
              <MoreVertical size={14} className="text-slate-400" />
            </button>
            <div
              className="w-3 h-3 rounded-full"
              style={{
                backgroundColor: TAG_COLORS[idea.colorTag],
                boxShadow: `0 0 8px ${TAG_COLORS[idea.colorTag]}60`,
              }}
            />
            <span
              className="text-[9px] px-1.5 py-0.5 rounded-full font-medium"
              style={{
                backgroundColor: CATEGORY_LABELS[idea.category].bg,
                color: CATEGORY_LABELS[idea.category].color,
              }}
            >
              {CATEGORY_LABELS[idea.category].text}
            </span>
          </div>
        </div>

        <AnimatePresence>
          {isMenuOpen && (
            <motion.div
              initial={{ opacity: 0, y: -5 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -5 }}
              transition={fadeTransition(reduced)}
              className="mt-3 pt-3 border-t border-white/10 flex gap-2"
            >
              <button
                onClick={handleEdit}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-white/5 text-xs text-slate-300 active:bg-white/10 transition-colors"
              >
                <Edit3 size={12} />
                编辑
              </button>
              <button
                onClick={handleTransfer}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-white/5 text-xs text-slate-300 active:bg-white/10 transition-colors"
              >
                <Archive size={12} />
                {idea.category === 'idea' ? '转LOG' : '转IDEA'}
              </button>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  setShowDeleteConfirm(true);
                }}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-red-500/10 text-xs text-red-400 active:bg-red-500/20 transition-colors"
              >
                <Trash2 size={12} />
                删除
              </button>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

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
    </LiquidGlassCard>
  );
});

export default function IdeaList({
  ideas,
  onDetail,
  onMenuAction,
  menuOpenId,
  onMenuToggle,
}: IdeaListProps) {
  const reduced = useReducedMotion();

  if (ideas.length === 0) {
    return (
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        className="flex flex-col items-center justify-center py-20 text-slate-500"
      >
        <Lightbulb size={40} className="mb-3 opacity-40" />
        <p className="text-sm">还没有想法记录</p>
        <p className="text-xs mt-1">在 Log 页面将记录标记为 IDEA</p>
      </motion.div>
    );
  }

  return (
    <div className="space-y-3">
      <AnimatePresence mode="popLayout">
        {ideas.map((idea) => (
          <motion.div
            key={idea.id}
            layout
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95 }}
            transition={fadeTransition(reduced)}
          >
            <IdeaItem
              idea={idea}
              onDetail={onDetail}
              onMenuAction={onMenuAction}
              menuOpenId={menuOpenId}
              onMenuToggle={onMenuToggle}
            />
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}
