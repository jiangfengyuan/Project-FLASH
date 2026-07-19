import { memo } from 'react';
import { Virtuoso } from 'react-virtuoso';
import { motion, AnimatePresence } from 'framer-motion';
import { Trash2, Frown, Angry, Meh } from 'lucide-react';
import { useEmotionStore } from '@/stores/emotionStore';
import { LEVEL_NAMES, LEVEL_COLORS } from '@/lib/constants';
import LiquidGlassCard from '@/components/LiquidGlassCard';
import { format } from 'date-fns';
import EmotionEmoji from './EmotionEmoji';
import { useReducedMotion, fadeTransition } from '@/lib/motion';
import { haptic, HAPTIC_DELETE } from '@/lib/haptics';

const subEmotionConfig = {
  sad: { label: '伤心', color: '#A78BFA', icon: Frown },
  angry: { label: '生气', color: '#F87171', icon: Angry },
  uncomfortable: { label: '难受', color: '#FB923C', icon: Meh },
};

const HistoryItem = memo(function HistoryItem({
  record,
  index,
  onDelete,
}: {
  record: ReturnType<typeof useEmotionStore.getState>['emotions'][0];
  index: number;
  onDelete: (id: string) => void | Promise<void>;
}) {
  const reduced = useReducedMotion();
  const subEmotion = record.subEmotion ? subEmotionConfig[record.subEmotion] : null;

  return (
    <motion.div
      layout
      initial={{ opacity: 0, y: reduced ? 0 : 8 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, scale: 0.95 }}
      transition={fadeTransition(reduced)}
      className="pb-2"
    >
      <LiquidGlassCard index={index} className="!rounded-2xl">
        <div className="p-3 flex items-center gap-3">
          <div className="flex-shrink-0">
            <EmotionEmoji level={record.level} size={40} />
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2">
              <span className="text-sm font-medium" style={{ color: LEVEL_COLORS[record.level] }}>
                {LEVEL_NAMES[record.level]}
              </span>
              {subEmotion && (
                <span
                  className="text-[10px] px-2 py-0.5 rounded-full flex items-center gap-1"
                  style={{
                    backgroundColor: `${subEmotion.color}20`,
                    color: subEmotion.color,
                  }}
                >
                  <subEmotion.icon size={10} />
                  {subEmotion.label}
                </span>
              )}
            </div>
            {record.status && <p className="text-xs text-slate-400 mt-0.5">{record.status}</p>}
            {record.note && (
              <p className="text-xs text-slate-500 mt-0.5 line-clamp-2">{record.note}</p>
            )}
            <span className="text-[10px] text-slate-600 mt-1 block font-mono">
              {format(new Date(record.createdAt), 'MM/dd HH:mm')}
            </span>
          </div>
          <button
            onClick={() => {
              haptic(HAPTIC_DELETE);
              void onDelete(record.id);
            }}
            aria-label="删除情绪记录"
            className="flex-shrink-0 w-8 h-8 flex items-center justify-center rounded-full active:bg-red-500/20 transition-colors"
          >
            <Trash2 size={14} className="text-slate-500" />
          </button>
        </div>
      </LiquidGlassCard>
    </motion.div>
  );
});

const EmptyHistoryList = () => (
  <div className="text-center py-8 text-slate-600 text-sm">还没有情绪记录</div>
);

export default function HistoryList() {
  const emotions = useEmotionStore((state) => state.emotions);
  const deleteEmotion = useEmotionStore((state) => state.deleteEmotion);

  return (
    <div className="flex-1 overflow-hidden px-4 pb-4">
      <h3 className="text-xs text-slate-400 mb-2 backdrop-blur-sm py-1">历史记录</h3>
      {import.meta.env.MODE === 'test' ? (
        <div className="h-full overflow-y-auto no-scrollbar">
          <AnimatePresence mode="popLayout">
            {emotions.map((record, i) => (
              <HistoryItem key={record.id} record={record} index={i} onDelete={deleteEmotion} />
            ))}
          </AnimatePresence>
          {emotions.length === 0 && (
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              className="text-center py-8 text-slate-600 text-sm"
            >
              还没有情绪记录
            </motion.div>
          )}
        </div>
      ) : (
        <Virtuoso
          data={emotions}
          style={{ height: '100%' }}
          className="no-scrollbar"
          components={{ EmptyPlaceholder: EmptyHistoryList }}
          itemContent={(_index, record) => (
            <div className="pb-2">
              <HistoryItem record={record} index={_index} onDelete={deleteEmotion} />
            </div>
          )}
        />
      )}
    </div>
  );
}
