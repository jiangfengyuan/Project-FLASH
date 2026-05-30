import { useState, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Lightbulb, Trash2, Edit3, Archive, ChevronLeft, Clock } from 'lucide-react';
import { useLogStore, TAG_COLORS, TAG_NAMES } from '@/stores/logStore';
import LiquidGlassCard from '@/components/LiquidGlassCard';
import { format, differenceInDays, isToday, isYesterday } from 'date-fns';

type FilterType = 'all' | 'log' | 'idea';

const importanceMarks = ['', '', '!!', '!!!', '!!!!'];
const importanceColors = ['', '', '#FF9F43', '#FF6B6B', '#DC2626'];

const CATEGORY_LABELS: Record<string, { text: string; bg: string; color: string }> = {
  log: { text: 'LOG', bg: 'rgba(77,150,255,0.15)', color: '#4D96FF' },
  idea: { text: 'IDEA', bg: 'rgba(255,159,67,0.15)', color: '#FF9F43' },
};

function getTimeGroup(dateStr: string): string {
  const d = new Date(dateStr);
  if (isToday(d)) return '今天';
  if (isYesterday(d)) return '昨天';
  if (differenceInDays(new Date(), d) <= 7) return '本周';
  return '更早';
}

export default function IdeaFlow() {
  const { logs, deleteLog, updateLog } = useLogStore();
  const [filter, setFilter] = useState<FilterType>('all');
  const [menuOpenId, setMenuOpenId] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editContent, setEditContent] = useState('');
  const [detailLog, setDetailLog] = useState<(typeof logs)[0] | null>(null);
  const [direction, setDirection] = useState(0);
  const contentRef = useRef<HTMLDivElement>(null);

  const ideas = logs.filter((log) => {
    if (filter === 'idea') return log.category === 'idea';
    if (filter === 'log') return log.category === 'log';
    return true;
  });

  const unprocessedCount = logs.filter((l) => l.category === 'idea').length;

  // Group ideas by time
  const groups: { label: string; items: typeof ideas }[] = [];
  const groupMap = new Map<string, typeof ideas>();
  ideas.forEach((idea) => {
    const g = getTimeGroup(idea.recordDate);
    if (!groupMap.has(g)) groupMap.set(g, []);
    groupMap.get(g)!.push(idea);
  });
  ['今天', '昨天', '本周', '更早'].forEach((label) => {
    const items = groupMap.get(label);
    if (items && items.length > 0) {
      groups.push({ label, items });
    }
  });

  const handleFilterChange = (newFilter: FilterType) => {
    const order: FilterType[] = ['all', 'log', 'idea'];
    const oldIdx = order.indexOf(filter);
    const newIdx = order.indexOf(newFilter);
    setDirection(newIdx > oldIdx ? 1 : -1);
    setFilter(newFilter);
  };

  const handleEdit = (id: string) => {
    const log = logs.find((l) => l.id === id);
    if (!log) return;
    setEditingId(id);
    setEditContent(log.content);
    setMenuOpenId(null);
  };

  const handleSaveEdit = () => {
    if (!editingId || !editContent.trim()) return;
    updateLog(editingId, {
      content: editContent.trim(),
      importance: editContent.includes('!!!!') ? 4 : editContent.includes('!!!') ? 3 : editContent.includes('!!') ? 2 : 0,
    });
    setEditingId(null);
    setEditContent('');
  };

  const variants = {
    enter: (dir: number) => ({ x: dir > 0 ? 60 : -60, opacity: 0 }),
    center: { x: 0, opacity: 1 },
    exit: (dir: number) => ({ x: dir > 0 ? -60 : 60, opacity: 0 }),
  };

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="px-4 pt-3 pb-2 space-y-3">
        <div className="flex items-center justify-between">
          <h1 className="text-lg font-semibold text-white">Idea Flow</h1>
          {unprocessedCount >= 3 && (
            <div className="liquid-glass-pill px-3 py-1 flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-amber-400" />
              <span className="text-[11px] text-amber-300">
                {unprocessedCount} 个想法等待梳理
              </span>
            </div>
          )}
        </div>

        {/* Segmented Control */}
        <div className="liquid-glass-pill p-1 flex relative">
          {(['all', 'log', 'idea'] as FilterType[]).map((f) => (
            <button
              key={f}
              onClick={() => handleFilterChange(f)}
              className={`flex-1 py-1.5 rounded-full text-[12px] transition-all relative z-10 ${
                filter === f
                  ? 'text-white font-medium'
                  : 'text-slate-400'
              }`}
            >
              {f === 'all' ? '全部' : f === 'log' ? '我的日志' : '笔记'}
            </button>
          ))}
        </div>
      </div>

      {/* Reminder Banner */}
      {unprocessedCount >= 3 && (
        <motion.div
          initial={{ opacity: 0, height: 0 }}
          animate={{ opacity: 1, height: 'auto' }}
          className="mx-4 mb-3 liquid-glass-sm px-4 py-2.5 flex items-center gap-2"
          style={{ background: 'rgba(255,159,67,0.08)', borderColor: 'rgba(255,159,67,0.2)' }}
        >
          <Lightbulb size={14} className="text-amber-400 flex-shrink-0" />
          <p className="text-xs text-amber-200">
            你还有 {unprocessedCount} 个想法等待梳理
          </p>
        </motion.div>
      )}

      {/* Idea List with slide animation */}
      <div className="flex-1 overflow-y-auto no-scrollbar px-4 pb-4" ref={contentRef}>
        <AnimatePresence mode="wait" custom={direction}>
          <motion.div
            key={filter}
            custom={direction}
            variants={variants}
            initial="enter"
            animate="center"
            exit="exit"
            transition={{ duration: 0.25, ease: 'easeInOut' }}
            className="space-y-4"
          >
            {groups.map((group) => (
              <div key={group.label}>
                <h3 className="text-[11px] text-slate-300 font-medium mb-2 sticky top-0 py-1 z-10">
                  {group.label}
                </h3>
                <div className="space-y-3">
                  {group.items.map((idea, i) => (
                    <LiquidGlassCard
                      key={idea.id}
                      index={i}
                      onClick={() => {
                        if (!menuOpenId) setDetailLog(idea);
                      }}
                    >
                      <div className="p-4 relative">
                        {/* Top row: date + importance + category tag */}
                        <div className="flex items-center gap-2 mb-1.5">
                          <span className="text-[11px] text-slate-300 font-mono">
                            {format(new Date(idea.recordDate), 'yy.MM.dd')}
                          </span>
                          {idea.importance >= 2 && (
                            <span
                              className="text-[10px] font-bold"
                              style={{ color: importanceColors[idea.importance] || '#FF9F43' }}
                            >
                              {importanceMarks[idea.importance]}
                            </span>
                          )}
                        </div>

                        {/* Content row: text + tag dot + category badge */}
                        <div className="flex items-start justify-between gap-3">
                          <p className="text-[15px] text-white leading-relaxed line-clamp-3 flex-1">
                            {idea.content}
                          </p>
                          <div className="flex flex-col items-end gap-1.5 flex-shrink-0 mt-0.5">
                            {/* Tag dot */}
                            <div
                              className="w-3 h-3 rounded-full"
                              style={{
                                backgroundColor: TAG_COLORS[idea.colorTag],
                                boxShadow: `0 0 8px ${TAG_COLORS[idea.colorTag]}60`,
                              }}
                            />
                            {/* Category badge */}
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

                        {/* Expanded menu */}
                        {menuOpenId === idea.id && (
                          <motion.div
                            initial={{ opacity: 0, y: -5 }}
                            animate={{ opacity: 1, y: 0 }}
                            className="mt-3 pt-3 border-t border-white/10 flex gap-2"
                          >
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                handleEdit(idea.id);
                              }}
                              className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-white/5 text-xs text-slate-300 active:bg-white/10"
                            >
                              <Edit3 size={12} />
                              编辑
                            </button>
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                updateLog(idea.id, { category: idea.category === 'idea' ? 'log' : 'idea' });
                                setMenuOpenId(null);
                              }}
                              className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-white/5 text-xs text-slate-300 active:bg-white/10"
                            >
                              <Archive size={12} />
                              {idea.category === 'idea' ? '转LOG' : '转IDEA'}
                            </button>
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                deleteLog(idea.id);
                                setMenuOpenId(null);
                              }}
                              className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-red-500/10 text-xs text-red-400 active:bg-red-500/20"
                            >
                              <Trash2 size={12} />
                              删除
                            </button>
                          </motion.div>
                        )}
                      </div>
                    </LiquidGlassCard>
                  ))}
                </div>
              </div>
            ))}

            {ideas.length === 0 && (
              <div className="flex flex-col items-center justify-center py-20 text-slate-500">
                <Lightbulb size={40} className="mb-3 opacity-40" />
                <p className="text-sm">还没有想法记录</p>
                <p className="text-xs mt-1">在Log页面将记录标记为IDEA</p>
              </div>
            )}
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Full-screen Detail */}
      <AnimatePresence>
        {detailLog && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[90] flex flex-col"
          >
            <div className="absolute inset-0 bg-black/60 backdrop-blur-md" onClick={() => setDetailLog(null)} />
            <motion.div
              initial={{ y: '100%' }}
              animate={{ y: 0 }}
              exit={{ y: '100%' }}
              transition={{ type: 'spring', damping: 28, stiffness: 300 }}
              className="relative flex-1 flex flex-col mt-16"
            >
              <div className="liquid-glass flex-1 flex flex-col mx-0 rounded-t-[28px] overflow-hidden">
                {/* Detail Header */}
                <div className="flex items-center justify-between px-5 pt-5 pb-3">
                  <button
                    onClick={() => setDetailLog(null)}
                    className="w-9 h-9 flex items-center justify-center rounded-full bg-white/5 active:bg-white/10"
                  >
                    <ChevronLeft size={20} className="text-white" />
                  </button>
                  <span className="text-xs text-slate-400 font-mono">
                    {format(new Date(detailLog.createdAt), 'yyyy.MM.dd HH:mm')}
                  </span>
                  <div className="w-9" />
                </div>

                {/* Detail Body */}
                <div className="flex-1 overflow-y-auto no-scrollbar px-5 pb-8">
                  <div className="flex items-center gap-2 mb-4">
                    <span
                      className="text-[11px] px-3 py-1 rounded-full font-medium"
                      style={{
                        backgroundColor: `${TAG_COLORS[detailLog.colorTag]}25`,
                        color: TAG_COLORS[detailLog.colorTag],
                      }}
                    >
                      {TAG_NAMES[detailLog.colorTag]}
                    </span>
                    <span
                      className="text-[11px] px-3 py-1 rounded-full font-medium"
                      style={{
                        backgroundColor: CATEGORY_LABELS[detailLog.category].bg,
                        color: CATEGORY_LABELS[detailLog.category].color,
                      }}
                    >
                      {CATEGORY_LABELS[detailLog.category].text}
                    </span>
                    {detailLog.importance >= 2 && (
                      <span
                        className="text-[10px] font-bold"
                        style={{ color: importanceColors[detailLog.importance] }}
                      >
                        {importanceMarks[detailLog.importance]}
                      </span>
                    )}
                  </div>

                  <p className="text-lg text-white leading-relaxed whitespace-pre-wrap">
                    {detailLog.content}
                  </p>

                  <div className="mt-8 pt-4 border-t border-white/10">
                    <div className="flex items-center gap-4 text-xs text-slate-500">
                      <div className="flex items-center gap-1.5">
                        <Clock size={12} />
                        <span>记录于 {format(new Date(detailLog.createdAt), 'MM月dd日 HH:mm')}</span>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Bottom Actions */}
                <div className="px-5 pb-20 pt-3 border-t border-white/10 flex gap-2">
                  <button
                    onClick={() => {
                      handleEdit(detailLog.id);
                      setDetailLog(null);
                    }}
                    className="flex-1 liquid-glass-pill py-2.5 text-[11px] text-slate-300 flex items-center justify-center gap-1.5 active:scale-[0.98]"
                  >
                    <Edit3 size={12} />
                    编辑
                  </button>
                  <button
                    onClick={() => {
                      updateLog(detailLog.id, { category: detailLog.category === 'idea' ? 'log' : 'idea' });
                      setDetailLog(null);
                    }}
                    className="flex-1 liquid-glass-pill py-2.5 text-[11px] text-slate-300 flex items-center justify-center gap-1.5 active:scale-[0.98]"
                  >
                    <Archive size={12} />
                    {detailLog.category === 'idea' ? '归档' : '转IDEA'}
                  </button>
                  <button
                    onClick={() => {
                      deleteLog(detailLog.id);
                      setDetailLog(null);
                    }}
                    className="flex-1 liquid-glass-pill py-2.5 text-[11px] text-red-400 flex items-center justify-center gap-1.5 active:scale-[0.98]"
                    style={{ background: 'rgba(239,68,68,0.08)' }}
                  >
                    <Trash2 size={12} />
                    删除
                  </button>
                </div>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Edit Modal */}
      <AnimatePresence>
        {editingId && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[80] flex items-end justify-center"
            onClick={() => setEditingId(null)}
          >
            <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" />
            <motion.div
              initial={{ y: 100 }}
              animate={{ y: 0 }}
              exit={{ y: 100 }}
              className="relative w-full max-w-md mx-auto p-4 pb-8"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="liquid-glass p-4 space-y-4">
                <textarea
                  value={editContent}
                  onChange={(e) => setEditContent(e.target.value)}
                  placeholder="详细内容..."
                  rows={6}
                  className="w-full bg-transparent text-sm text-white placeholder-slate-500 outline-none resize-none leading-relaxed"
                />
                <div className="flex gap-2">
                  <button
                    onClick={handleSaveEdit}
                    className="flex-1 liquid-glass-pill py-3 text-white text-sm font-medium active:scale-[0.98]"
                  >
                    保存
                  </button>
                  <button
                    onClick={() => setEditingId(null)}
                    className="flex-1 liquid-glass-pill py-3 text-slate-400 text-sm active:scale-[0.98]"
                  >
                    取消
                  </button>
                </div>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
