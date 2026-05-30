import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Search, X, SlidersHorizontal, ChevronLeft, MoreVertical, Trash2, Edit3, Archive, Clock } from 'lucide-react';
import { useAppStore } from '@/stores/appStore';
import { useLogStore, TAG_COLORS, TAG_NAMES, type ColorTag } from '@/stores/logStore';
import LiquidGlassCard from '@/components/LiquidGlassCard';
import { format } from 'date-fns';

const colorTags: ColorTag[] = ['urgent', 'inspiration', 'daily', 'memo', 'emotion', 'idea'];

const CATEGORY_LABELS: Record<string, { text: string; bg: string; color: string }> = {
  log: { text: 'LOG', bg: 'rgba(77,150,255,0.15)', color: '#4D96FF' },
  idea: { text: 'IDEA', bg: 'rgba(255,159,67,0.15)', color: '#FF9F43' },
};

export default function LogFlow() {
  const { navigateTo } = useAppStore();
  const { logs, searchQuery, setSearchQuery, filterTag, setFilterTag, deleteLog, updateLog } = useLogStore();
  const [showFilters, setShowFilters] = useState(false);
  const [menuOpenId, setMenuOpenId] = useState<string | null>(null);
  const [detailLog, setDetailLog] = useState<(typeof logs)[0] | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editContent, setEditContent] = useState('');

  const filteredLogs = logs.filter((log) => {
    if (log.category !== 'log') return false;
    const matchesSearch = !searchQuery || log.content.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesTag = !filterTag || log.colorTag === filterTag;
    return matchesSearch && matchesTag;
  });

  const handleEdit = (id: string) => {
    const log = logs.find((l) => l.id === id);
    if (!log) return;
    setEditingId(id);
    setEditContent(log.content);
    setMenuOpenId(null);
  };

  const handleSaveEdit = () => {
    if (!editingId || !editContent.trim()) return;
    updateLog(editingId, { content: editContent.trim() });
    setEditingId(null);
    setEditContent('');
  };

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center gap-3 px-4 pt-3 pb-2">
        <button
          onClick={() => navigateTo('log')}
          className="w-9 h-9 flex items-center justify-center rounded-full bg-white/5 active:bg-white/10"
        >
          <ChevronLeft size={20} className="text-white" />
        </button>
        <div className="flex-1 liquid-glass-input flex items-center gap-2 px-4 py-2">
          <Search size={16} className="text-slate-400 flex-shrink-0" />
          <input
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="搜索记录..."
            className="flex-1 bg-transparent text-white text-sm placeholder-slate-500 outline-none"
          />
          {searchQuery && (
            <button onClick={() => setSearchQuery('')}>
              <X size={14} className="text-slate-400" />
            </button>
          )}
        </div>
        <button
          onClick={() => setShowFilters(!showFilters)}
          className={`w-9 h-9 flex items-center justify-center rounded-full transition-colors ${
            showFilters || filterTag ? 'bg-blue-500/30' : 'bg-white/5'
          } active:bg-white/10`}
        >
          <SlidersHorizontal size={16} className="text-slate-300" />
        </button>
      </div>

      {/* Filter Bar */}
      {showFilters && (
        <motion.div
          initial={{ height: 0, opacity: 0 }}
          animate={{ height: 'auto', opacity: 1 }}
          className="px-4 pb-2 overflow-hidden"
        >
          <div className="liquid-glass-sm p-3 flex flex-wrap gap-2">
            <button
              onClick={() => setFilterTag(null)}
              className={`px-3 py-1 rounded-full text-[11px] transition-all ${
                !filterTag ? 'bg-white/20 text-white' : 'bg-white/5 text-slate-400'
              }`}
            >
              全部
            </button>
            {colorTags.map((tag) => (
              <button
                key={tag}
                onClick={() => setFilterTag(filterTag === tag ? null : tag)}
                className="px-3 py-1 rounded-full text-[11px] transition-all"
                style={
                  filterTag === tag
                    ? { backgroundColor: `${TAG_COLORS[tag]}30`, color: TAG_COLORS[tag] }
                    : { backgroundColor: 'rgba(255,255,255,0.05)', color: '#94A3B8' }
                }
              >
                {TAG_NAMES[tag]}
              </button>
            ))}
          </div>
        </motion.div>
      )}

      {/* Log List */}
      <div className="flex-1 overflow-y-auto no-scrollbar px-4 pb-4 pt-2 space-y-3">
        {filteredLogs.map((log, i) => (
          <LiquidGlassCard
            key={log.id}
            colorTag={TAG_COLORS[log.colorTag]}
            index={i}
            onClick={() => setDetailLog(log)}
          >
            <div className="py-3 pr-4 relative">
              <p className="text-[15px] text-white leading-relaxed pr-8">{log.content}</p>
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
                  {format(new Date(log.createdAt), 'MM-dd HH:mm')}
                </span>
              </div>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  setMenuOpenId(menuOpenId === log.id ? null : log.id);
                }}
                className="absolute top-3 right-2 w-7 h-7 flex items-center justify-center rounded-full active:bg-white/10"
              >
                <MoreVertical size={14} className="text-slate-400" />
              </button>
              {menuOpenId === log.id && (
                <motion.div
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  className="absolute top-10 right-2 liquid-glass-sm z-20 min-w-[120px] py-1]"
                >
                  <button
                    onClick={(e) => { e.stopPropagation(); handleEdit(log.id); }}
                    className="w-full flex items-center gap-2 px-3 py-2 text-xs text-slate-300 hover:bg-white/5"
                  >
                    <Edit3 size={12} /> 编辑
                  </button>
                  <button
                    onClick={(e) => { e.stopPropagation(); deleteLog(log.id); setMenuOpenId(null); }}
                    className="w-full flex items-center gap-2 px-3 py-2 text-xs text-red-400 hover:bg-white/5"
                  >
                    <Trash2 size={12} /> 删除
                  </button>
                </motion.div>
              )}
            </div>
          </LiquidGlassCard>
        ))}
        {filteredLogs.length === 0 && (
          <div className="flex flex-col items-center justify-center py-20 text-slate-500">
            <Search size={36} className="mb-3 opacity-40" />
            <p className="text-sm">没有找到匹配的记录</p>
          </div>
        )}
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
                <div className="px-5 pb-20 pt-3 border-t border-white/10 flex gap-2">
                  <button
                    onClick={() => { handleEdit(detailLog.id); setDetailLog(null); }}
                    className="flex-1 liquid-glass-pill py-2.5 text-[11px] text-slate-300 flex items-center justify-center gap-1.5 active:scale-[0.98]"
                  >
                    <Edit3 size={12} /> 编辑
                  </button>
                  <button
                    onClick={() => { updateLog(detailLog.id, { category: 'idea' }); setDetailLog(null); }}
                    className="flex-1 liquid-glass-pill py-2.5 text-[11px] text-amber-300 flex items-center justify-center gap-1.5 active:scale-[0.98]"
                    style={{ background: 'rgba(255,159,67,0.1)' }}
                  >
                    <Archive size={12} /> 转IDEA
                  </button>
                  <button
                    onClick={() => { deleteLog(detailLog.id); setDetailLog(null); }}
                    className="flex-1 liquid-glass-pill py-2.5 text-[11px] text-red-400 flex items-center justify-center gap-1.5 active:scale-[0.98]"
                    style={{ background: 'rgba(239,68,68,0.08)' }}
                  >
                    <Trash2 size={12} /> 删除
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
                  <button onClick={handleSaveEdit} className="flex-1 liquid-glass-pill py-3 text-white text-sm font-medium active:scale-[0.98]">
                    保存
                  </button>
                  <button onClick={() => setEditingId(null)} className="flex-1 liquid-glass-pill py-3 text-slate-400 text-sm active:scale-[0.98]">
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
