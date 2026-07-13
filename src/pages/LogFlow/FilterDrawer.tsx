import { motion } from 'framer-motion';
import { X } from 'lucide-react';
import { useLogStore } from '@/stores/logStore';
import { COLOR_TAGS, TAG_NAMES, TAG_COLORS } from '@/lib/constants';

interface FilterDrawerProps {
  open: boolean;
  onClose: () => void;
  resultCount: number;
}

export default function FilterDrawer({ open, onClose, resultCount }: FilterDrawerProps) {
  const {
    startDate,
    endDate,
    filterTags,
    sortBy,
    setDateRange,
    toggleFilterTag,
    setSortBy,
    resetFilters,
  } = useLogStore();

  if (!open) return null;

  return (
    <motion.div
      initial={{ y: '100%' }}
      animate={{ y: 0 }}
      exit={{ y: '100%' }}
      transition={{ type: 'spring', damping: 25, stiffness: 200 }}
      className="absolute inset-x-0 bottom-0 z-40 rounded-t-3xl liquid-glass overflow-hidden max-h-[80%] flex flex-col"
    >
      <div className="flex items-center justify-between px-4 py-3 border-b border-white/10">
        <h2 className="text-base font-medium text-white">筛选与排序</h2>
        <button
          onClick={onClose}
          aria-label="关闭"
          className="w-8 h-8 flex items-center justify-center rounded-full bg-white/5"
        >
          <X size={16} className="text-slate-300" />
        </button>
      </div>

      <div className="flex-1 overflow-y-auto p-4 space-y-5">
        <section>
          <h3 className="text-xs text-slate-500 uppercase tracking-wider mb-2">日期范围</h3>
          <div className="flex items-center gap-2">
            <input
              type="date"
              value={startDate ?? ''}
              onChange={(e) => setDateRange(e.target.value || null, endDate)}
              className="flex-1 bg-white/5 text-white text-sm rounded-lg px-3 py-2 outline-none"
            />
            <span className="text-slate-500">-</span>
            <input
              type="date"
              value={endDate ?? ''}
              onChange={(e) => setDateRange(startDate, e.target.value || null)}
              className="flex-1 bg-white/5 text-white text-sm rounded-lg px-3 py-2 outline-none"
            />
          </div>
          <div className="flex gap-2 mt-2">
            <QuickDate label="近 7 天" days={7} />
            <QuickDate label="近 30 天" days={30} />
            <QuickDate label="本月" days={0} />
          </div>
        </section>

        <section>
          <h3 className="text-xs text-slate-500 uppercase tracking-wider mb-2">标签</h3>
          <div className="flex flex-wrap gap-2">
            {COLOR_TAGS.map((tag) => {
              const active = filterTags.includes(tag);
              return (
                <button
                  key={tag}
                  onClick={() => toggleFilterTag(tag)}
                  className="px-3 py-1.5 rounded-full text-xs transition-all border"
                  style={{
                    backgroundColor: active ? `${TAG_COLORS[tag]}20` : 'rgba(255,255,255,0.05)',
                    borderColor: active ? `${TAG_COLORS[tag]}60` : 'transparent',
                    color: active ? TAG_COLORS[tag] : '#94A3B8',
                  }}
                >
                  {TAG_NAMES[tag]}
                </button>
              );
            })}
          </div>
        </section>

        <section>
          <h3 className="text-xs text-slate-500 uppercase tracking-wider mb-2">排序</h3>
          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value as 'newest' | 'oldest' | 'tag')}
            className="w-full bg-white/5 text-white text-sm rounded-lg px-3 py-2 outline-none"
          >
            <option value="newest">时间倒序</option>
            <option value="oldest">时间正序</option>
            <option value="tag">按标签分组</option>
          </select>
        </section>
      </div>

      <div className="p-4 border-t border-white/10 flex gap-3">
        <button
          onClick={resetFilters}
          className="flex-1 py-2.5 rounded-xl bg-white/5 text-sm text-slate-300 active:bg-white/10 transition-colors"
        >
          重置
        </button>
        <button
          onClick={onClose}
          className="flex-1 py-2.5 rounded-xl bg-blue-500/30 text-sm text-white font-medium active:bg-blue-500/40 transition-colors"
        >
          查看 {resultCount} 条结果
        </button>
      </div>
    </motion.div>
  );
}

function QuickDate({ label, days }: { label: string; days: number }) {
  const { setDateRange } = useLogStore();

  const handleClick = () => {
    const end = new Date().toISOString().slice(0, 10);
    const start =
      days === 0
        ? new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().slice(0, 10)
        : new Date(Date.now() - days * 86400000).toISOString().slice(0, 10);
    setDateRange(start, end);
  };

  return (
    <button
      onClick={handleClick}
      className="px-3 py-1 rounded-lg text-xs bg-white/5 text-slate-400 active:bg-white/10 transition-colors"
    >
      {label}
    </button>
  );
}
