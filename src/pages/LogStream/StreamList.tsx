import { memo, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ArrowRight, FileText } from 'lucide-react';
import { useNavigationStore } from '@/stores/navigationStore';
import { useLogStore, type LogItem } from '@/stores/logStore';
import { TAG_COLORS, TAG_NAMES } from '@/lib/constants';
import LiquidGlassCard from '@/components/LiquidGlassCard';
import { format } from 'date-fns';
import { useReducedMotion, fadeTransition } from '@/lib/motion';

interface StreamListProps {
  onDetail: (log: LogItem) => void;
}

const LogCard = memo(function LogCard({
  log,
  index,
  onDetail,
}: {
  log: LogItem;
  index: number;
  onDetail: (log: LogItem) => void;
}) {
  return (
    <LiquidGlassCard
      colorTag={TAG_COLORS[log.colorTag]}
      index={index}
      onClick={() => onDetail(log)}
    >
      <div className="py-3 pr-4">
        <p className="text-[15px] text-white leading-relaxed">{log.content}</p>
        <div className="flex items-center justify-between mt-2">
          <span
            className="text-[10px] px-2 py-0.5 rounded-full"
            style={{
              backgroundColor: `${TAG_COLORS[log.colorTag]}20`,
              color: TAG_COLORS[log.colorTag],
            }}
          >
            {TAG_NAMES[log.colorTag]}
          </span>
          <span className="text-xs text-slate-400 font-mono">
            {format(new Date(log.createdAt), 'HH:mm')}
          </span>
        </div>
      </div>
    </LiquidGlassCard>
  );
});

export default function StreamList({ onDetail }: StreamListProps) {
  const reduced = useReducedMotion();
  const { navigateTo } = useNavigationStore();
  const logs = useLogStore((state) => state.logs);
  const streamLogs = useMemo(() => logs.filter((l) => l.category === 'log').slice(0, 20), [logs]);

  return (
    <div className="flex-1 overflow-y-auto no-scrollbar px-4 pb-48 pt-2 space-y-3">
      {/* Quick access */}
      <div className="flex gap-2 mb-4">
        <button
          onClick={() => navigateTo('logFlow')}
          className="liquid-glass-pill px-3 py-1.5 flex items-center gap-1.5 text-xs text-slate-300 active:scale-95 transition-transform"
        >
          <ArrowRight size={12} />
          LOGS
        </button>
        <button
          onClick={() => navigateTo('idea')}
          className="liquid-glass-pill px-3 py-1.5 flex items-center gap-1.5 text-xs text-slate-300 active:scale-95 transition-transform"
        >
          <ArrowRight size={12} />
          IDEAS
        </button>
      </div>

      <AnimatePresence mode="popLayout">
        {streamLogs.map((log, i) => (
          <motion.div
            key={log.id}
            layout
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95 }}
            transition={fadeTransition(reduced)}
          >
            <LogCard log={log} index={i} onDetail={onDetail} />
          </motion.div>
        ))}
      </AnimatePresence>

      {streamLogs.length === 0 && (
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          className="flex flex-col items-center justify-center py-20 text-slate-500"
        >
          <FileText size={40} className="mb-3 opacity-40" />
          <p className="text-sm">还没有记录</p>
          <p className="text-xs mt-1">点击下方按钮开始记录</p>
        </motion.div>
      )}
    </div>
  );
}
