import { useState, useRef, memo, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Search,
  X,
  SlidersHorizontal,
  ChevronLeft,
  MoreVertical,
  Trash2,
  Edit3,
} from 'lucide-react';
import { useNavigationStore } from '@/stores/navigationStore';
import { useLogStore, type LogItem } from '@/stores/logStore';
import { TAG_COLORS, TAG_NAMES, COLOR_TAGS } from '@/lib/constants';
import { useToastStore } from '@/stores/toastStore';
import { Virtuoso } from 'react-virtuoso';
import LiquidGlassCard from '@/components/LiquidGlassCard';
import DetailDrawer from '@/components/DetailDrawer';
import EditDrawer from '@/components/EditDrawer';
import ConfirmDrawer from '@/components/ConfirmDrawer';
import { format } from 'date-fns';
import { useClickOutside } from '@/hooks/useClickOutside';
import { useReducedMotion, fadeTransition } from '@/lib/motion';
import { haptic, HAPTIC_SUCCESS, HAPTIC_DELETE, HAPTIC_TAP } from '@/lib/haptics';

interface LogCardProps {
  log: LogItem;
  menuOpenId: string | null;
  onMenuToggle: (id: string) => void;
  onDetail: (log: LogItem) => void;
  onEdit: (id: string) => void;
  onDelete: (id: string) => void;
}

const LogCard = memo(function LogCard({
  log,
  menuOpenId,
  onMenuToggle,
  onDetail,
  onEdit,
  onDelete,
}: LogCardProps) {
  const reduced = useReducedMotion();
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const isMenuOpen = menuOpenId === log.id;

  useClickOutside(
    menuRef,
    () => {
      if (isMenuOpen) onMenuToggle(log.id);
    },
    isMenuOpen
  );

  return (
    <LiquidGlassCard colorTag={TAG_COLORS[log.colorTag]} onClick={() => onDetail(log)}>
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
            haptic(HAPTIC_TAP);
            onMenuToggle(log.id);
          }}
          aria-label="更多操作"
          className="absolute top-3 right-2 w-7 h-7 flex items-center justify-center rounded-full active:bg-white/10 transition-colors"
        >
          <MoreVertical size={14} className="text-slate-400" />
        </button>
        <AnimatePresence>
          {isMenuOpen && (
            <motion.div
              ref={menuRef}
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.9 }}
              transition={fadeTransition(reduced)}
              className="absolute top-10 right-2 liquid-glass-sm z-20 min-w-[120px] py-1"
            >
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onEdit(log.id);
                }}
                className="w-full flex items-center gap-2 px-3 py-2 text-xs text-slate-300 hover:bg-white/5 transition-colors"
              >
                <Edit3 size={12} /> 编辑
              </button>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  setShowDeleteConfirm(true);
                }}
                className="w-full flex items-center gap-2 px-3 py-2 text-xs text-red-400 hover:bg-white/5 transition-colors"
              >
                <Trash2 size={12} /> 删除
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
        onConfirm={() => {
          haptic(HAPTIC_DELETE);
          onDelete(log.id);
          setShowDeleteConfirm(false);
        }}
        onCancel={() => setShowDeleteConfirm(false)}
      />
    </LiquidGlassCard>
  );
});

const EmptyLogList = () => (
  <div className="flex flex-col items-center justify-center py-20 text-slate-500">
    <Search size={36} className="mb-3 opacity-40" />
    <p className="text-sm">没有找到匹配的记录</p>
  </div>
);

export default function LogFlow() {
  const { navigateTo } = useNavigationStore();
  const logs = useLogStore((state) => state.logs);
  const searchQuery = useLogStore((state) => state.searchQuery);
  const setSearchQuery = useLogStore((state) => state.setSearchQuery);
  const filterTag = useLogStore((state) => state.filterTag);
  const setFilterTag = useLogStore((state) => state.setFilterTag);
  const deleteLog = useLogStore((state) => state.deleteLog);
  const updateLog = useLogStore((state) => state.updateLog);
  const showToast = useToastStore((state) => state.showToast);

  const reduced = useReducedMotion();
  const [showFilters, setShowFilters] = useState(false);
  const [menuOpenId, setMenuOpenId] = useState<string | null>(null);
  const [detailLog, setDetailLog] = useState<LogItem | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editContent, setEditContent] = useState('');

  const filteredLogs = useMemo(() => {
    const query = searchQuery.toLowerCase();
    return logs.filter((log) => {
      if (log.category !== 'log') return false;
      const matchesSearch = !query || log.content.toLowerCase().includes(query);
      const matchesTag = !filterTag || log.colorTag === filterTag;
      return matchesSearch && matchesTag;
    });
  }, [logs, searchQuery, filterTag]);

  const handleEdit = (id: string) => {
    const log = logs.find((l) => l.id === id);
    if (!log) return;
    setEditingId(id);
    setEditContent(log.content);
    setMenuOpenId(null);
  };

  const handleSaveEdit = (id: string, content: string) => {
    updateLog(id, { content: content.trim() });
    showToast('编辑已保存', 'success');
    haptic(HAPTIC_SUCCESS);
    setEditingId(null);
    setEditContent('');
  };

  const handleDelete = (id: string) => {
    deleteLog(id);
    showToast('记录已删除', 'info');
    setMenuOpenId(null);
  };

  const handleTransfer = (id: string) => {
    const log = logs.find((l) => l.id === id);
    if (!log) return;
    const nextCategory = log.category === 'idea' ? 'log' : 'idea';
    updateLog(id, { category: nextCategory });
    showToast(nextCategory === 'idea' ? '已转至 Idea Flow' : '已转回 Log', 'success');
    haptic(HAPTIC_SUCCESS);
    setDetailLog(null);
  };

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center gap-3 px-4 pt-3 pb-2">
        <button
          onClick={() => navigateTo('log')}
          aria-label="返回"
          className="w-9 h-9 flex items-center justify-center rounded-full bg-white/5 active:bg-white/10 transition-colors"
        >
          <ChevronLeft size={20} className="text-white" />
        </button>
        <div className="flex-1 liquid-glass-input flex items-center gap-2 px-4 py-2">
          <Search size={16} className="text-slate-400 flex-shrink-0" />
          <input
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="搜索记录..."
            aria-label="搜索记录"
            className="flex-1 bg-transparent text-white text-sm placeholder-slate-500 outline-none"
          />
          {searchQuery && (
            <button onClick={() => setSearchQuery('')} aria-label="清空搜索">
              <X size={14} className="text-slate-400" />
            </button>
          )}
        </div>
        <button
          onClick={() => setShowFilters(!showFilters)}
          aria-label="筛选标签"
          aria-expanded={showFilters}
          className={`w-9 h-9 flex items-center justify-center rounded-full transition-colors ${
            showFilters || filterTag ? 'bg-blue-500/30' : 'bg-white/5'
          } active:bg-white/10`}
        >
          <SlidersHorizontal size={16} className="text-slate-300" />
        </button>
      </div>

      {/* Filter Bar */}
      <AnimatePresence>
        {showFilters && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
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
              {COLOR_TAGS.map((tag) => (
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
      </AnimatePresence>

      {/* Log List */}
      {filteredLogs.length > 50 ? (
        <div className="flex-1 overflow-hidden px-4 pb-4 pt-2">
          <Virtuoso
            data={filteredLogs}
            style={{ height: '100%' }}
            className="no-scrollbar"
            components={{ EmptyPlaceholder: EmptyLogList }}
            itemContent={(_index, log) => (
              <div className="pb-3">
                <LogCard
                  log={log}
                  menuOpenId={menuOpenId}
                  onMenuToggle={(id) => setMenuOpenId(menuOpenId === id ? null : id)}
                  onDetail={setDetailLog}
                  onEdit={handleEdit}
                  onDelete={handleDelete}
                />
              </div>
            )}
          />
        </div>
      ) : (
        <div className="flex-1 overflow-y-auto no-scrollbar px-4 pb-4 pt-2 space-y-3">
          <AnimatePresence mode="popLayout">
            {filteredLogs.map((log) => (
              <motion.div
                key={log.id}
                layout
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.95 }}
                transition={fadeTransition(reduced)}
              >
                <LogCard
                  log={log}
                  menuOpenId={menuOpenId}
                  onMenuToggle={(id) => setMenuOpenId(menuOpenId === id ? null : id)}
                  onDetail={setDetailLog}
                  onEdit={handleEdit}
                  onDelete={handleDelete}
                />
              </motion.div>
            ))}
          </AnimatePresence>
          {filteredLogs.length === 0 && (
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              className="flex flex-col items-center justify-center py-20 text-slate-500"
            >
              <Search size={36} className="mb-3 opacity-40" />
              <p className="text-sm">没有找到匹配的记录</p>
            </motion.div>
          )}
        </div>
      )}

      <AnimatePresence>
        {detailLog && (
          <DetailDrawer
            log={detailLog}
            onClose={() => setDetailLog(null)}
            onEdit={(id) => {
              handleEdit(id);
              setDetailLog(null);
            }}
            onDelete={(id) => {
              handleDelete(id);
              setDetailLog(null);
            }}
            onTransfer={handleTransfer}
          />
        )}
      </AnimatePresence>

      <EditDrawer
        editingId={editingId}
        initialContent={editContent}
        onSave={handleSaveEdit}
        onClose={() => {
          setEditingId(null);
          setEditContent('');
        }}
        placeholder="详细内容..."
      />
    </div>
  );
}
