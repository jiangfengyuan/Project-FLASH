import { motion, AnimatePresence } from 'framer-motion';
import { X } from 'lucide-react';
import { useLogStore } from '@/stores/logStore';
import { COLOR_TAGS, TAG_NAMES, TAG_COLORS } from '@/lib/constants';
import { subDays, startOfMonth, format } from 'date-fns';
import { getTodayStr, parseLocalDate } from '@/lib/utils';

interface FilterDrawerProps {
  open: boolean;
  onClose: () => void;
  resultCount: number;
}

export default function FilterDrawer({ open, onClose, resultCount }: FilterDrawerProps) {
  const startDate = useLogStore((s) => s.startDate);
  const endDate = useLogStore((s) => s.endDate);
  const filterTags = useLogStore((s) => s.filterTags);
  const sortBy = useLogStore((s) => s.sortBy);
  const setDateRange = useLogStore((s) => s.setDateRange);
  const toggleFilterTag = useLogStore((s) => s.toggleFilterTag);
  const setSortBy = useLogStore((s) => s.setSortBy);
  const resetFilters = useLogStore((s) => s.resetFilters);

  const handleStartChange = (value: string | null) => {
    if (value && endDate && value > endDate) {
      setDateRange(value, value);
      return;
    }
    setDateRange(value, endDate);
  };

  const handleEndChange = (value: string | null) => {
    if (value && startDate && value < startDate) {
      setDateRange(value, value);
      return;
    }
    setDateRange(startDate, value);
  };

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          initial={{ y: '100%' }}
          animate={{ y: 0 }}
          exit={{ y: '100%' }}
          transition={{ type: 'spring', damping: 25, stiffness: 200 }}
          className="absolute inset-x-0 bottom-0 z-40 rounded-t-[var(--radius-sheet)] liquid-glass overflow-hidden max-h-[80%] flex flex-col"
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
                  aria-label="开始日期"
                  value={startDate ?? ''}
                  onChange={(e) => handleStartChange(e.target.value || null)}
                  className="flex-1 bg-white/5 text-white text-sm rounded-[var(--radius-card)] px-3 py-2 outline-none"
                />
                <span className="text-slate-500">-</span>
                <input
                  type="date"
                  aria-label="结束日期"
                  value={endDate ?? ''}
                  onChange={(e) => handleEndChange(e.target.value || null)}
                  className="flex-1 bg-white/5 text-white text-sm rounded-[var(--radius-card)] px-3 py-2 outline-none"
                />
              </div>
              <div className="flex gap-2 mt-2">
                <QuickDate label="近 7 天" days={7} />
                <QuickDate label="近 30 天" days={30} />
                <QuickDate label="本月" mode="month" />
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
                      className={`px-3 py-1.5 rounded-full text-xs transition-all border ${
                        active ? '' : 'bg-white/5 border-transparent text-slate-400'
                      }`}
                      style={
                        active
                          ? {
                              backgroundColor: `${TAG_COLORS[tag]}20`,
                              borderColor: `${TAG_COLORS[tag]}60`,
                              color: TAG_COLORS[tag],
                            }
                          : undefined
                      }
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
                <option value="newest" className="bg-slate-900 text-white">
                  时间倒序
                </option>
                <option value="oldest" className="bg-slate-900 text-white">
                  时间正序
                </option>
                <option value="tag" className="bg-slate-900 text-white">
                  按标签分组
                </option>
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
              className="flex-1 py-2.5 rounded-xl bg-[var(--color-primary)]/30 text-sm text-white font-medium active:bg-[var(--color-primary)]/40 transition-colors"
            >
              查看 {resultCount} 条结果
            </button>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

function QuickDate({ label, days, mode }: { label: string; days?: number; mode?: 'month' }) {
  const setDateRange = useLogStore((s) => s.setDateRange);

  const handleClick = () => {
    const end = getTodayStr();
    const endDate = parseLocalDate(end);
    const start =
      mode === 'month'
        ? format(startOfMonth(endDate), 'yyyy-MM-dd')
        : format(subDays(endDate, (days ?? 7) - 1), 'yyyy-MM-dd');
    setDateRange(start, end);
  };

  return (
    <button
      onClick={handleClick}
      className="px-3 py-1 rounded-[var(--radius-card)] text-xs bg-white/5 text-slate-400 active:bg-white/10 transition-colors"
    >
      {label}
    </button>
  );
}
