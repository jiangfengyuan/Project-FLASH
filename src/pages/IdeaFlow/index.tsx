import { useState, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Lightbulb } from 'lucide-react';
import { useLogStore } from '@/stores/logStore';
import { useToastStore } from '@/stores/toastStore';
import { getImportanceFromContent } from '@/lib/constants';
import { haptic, HAPTIC_SUCCESS } from '@/lib/haptics';
import { parseLocalDate } from '@/lib/utils';
import IdeaList from './IdeaList';
import DetailDrawer from '@/components/DetailDrawer';
import EditDrawer from '@/components/EditDrawer';

function getTimeGroup(dateStr: string): string {
  const d = parseLocalDate(dateStr);
  const today = new Date();
  const diffDays = Math.floor((today.getTime() - d.getTime()) / (1000 * 60 * 60 * 24));
  if (diffDays === 0) return '今天';
  if (diffDays === 1) return '昨天';
  if (diffDays <= 7) return '本周';
  return '更早';
}

const GROUP_ORDER = ['今天', '昨天', '本周', '更早'];

export default function IdeaFlow() {
  const logs = useLogStore((state) => state.logs);
  const deleteLog = useLogStore((state) => state.deleteLog);
  const updateLog = useLogStore((state) => state.updateLog);
  const showToast = useToastStore((state) => state.showToast);

  const [menuOpenId, setMenuOpenId] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editContent, setEditContent] = useState('');
  const [detailLog, setDetailLog] = useState<(typeof logs)[0] | null>(null);

  const ideas = useMemo(() => logs.filter((l) => l.category === 'idea'), [logs]);
  const unprocessedCount = ideas.length;

  const groups = useMemo(() => {
    const result: { label: string; items: typeof ideas }[] = [];
    const groupMap = new Map<string, typeof ideas>();
    ideas.forEach((idea) => {
      const g = getTimeGroup(idea.recordDate);
      if (!groupMap.has(g)) groupMap.set(g, []);
      groupMap.get(g)!.push(idea);
    });
    GROUP_ORDER.forEach((label) => {
      const items = groupMap.get(label);
      if (items && items.length > 0) result.push({ label, items });
    });
    return result;
  }, [ideas]);

  const handleMenuAction = (action: 'edit' | 'delete' | 'transfer', id: string) => {
    if (action === 'edit') {
      const log = logs.find((l) => l.id === id);
      if (log) {
        setEditingId(id);
        setEditContent(log.content);
        setMenuOpenId(null);
      }
    } else if (action === 'delete') {
      deleteLog(id);
      showToast('想法已删除', 'info');
      setMenuOpenId(null);
    } else if (action === 'transfer') {
      const log = logs.find((l) => l.id === id);
      if (log) {
        updateLog(id, { category: log.category === 'idea' ? 'log' : 'idea' });
        showToast('已转至 Log', 'success');
        haptic(HAPTIC_SUCCESS);
      }
      setMenuOpenId(null);
    }
  };

  const handleDetailEdit = (id: string) => {
    const log = logs.find((l) => l.id === id);
    if (log) {
      setEditingId(id);
      setEditContent(log.content);
      setDetailLog(null);
    }
  };

  const handleEditSave = (id: string, content: string) => {
    updateLog(id, {
      content,
      importance: getImportanceFromContent(content),
    });
    showToast('编辑已保存', 'success');
    haptic(HAPTIC_SUCCESS);
    setEditingId(null);
  };

  return (
    <div className="flex flex-col h-full">
      <div className="px-4 pt-3 pb-2 space-y-3">
        <div className="flex items-center justify-between">
          <h1 className="text-lg font-semibold text-white">Idea Flow</h1>
          {unprocessedCount >= 3 && (
            <div className="liquid-glass-pill px-3 py-1 flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-amber-400" />
              <span className="text-[11px] text-amber-300">{unprocessedCount} 个想法等待梳理</span>
            </div>
          )}
        </div>
      </div>

      {unprocessedCount >= 3 && (
        <motion.div
          initial={{ opacity: 0, height: 0 }}
          animate={{ opacity: 1, height: 'auto' }}
          className="mx-4 mb-3 liquid-glass-sm px-4 py-2.5 flex items-center gap-2"
          style={{ background: 'rgba(255,159,67,0.08)', borderColor: 'rgba(255,159,67,0.2)' }}
        >
          <Lightbulb size={14} className="text-amber-400 flex-shrink-0" />
          <p className="text-xs text-amber-200">你还有 {unprocessedCount} 个想法等待梳理</p>
        </motion.div>
      )}

      <div className="flex-1 overflow-y-auto no-scrollbar px-4 pb-4">
        {groups.length === 0 && (
          <div className="flex flex-col items-center justify-center py-20 text-slate-500">
            <Lightbulb size={40} className="mb-3 opacity-40" />
            <p className="text-sm">还没有想法记录</p>
            <p className="text-xs mt-1">在 Log 页面将记录标记为 IDEA</p>
          </div>
        )}
        {groups.map((group) => (
          <div key={group.label} className="mb-4">
            <h3 className="text-[11px] text-slate-300 font-medium mb-2 sticky top-0 py-1 z-10">
              {group.label}
            </h3>
            <IdeaList
              ideas={group.items}
              onDetail={setDetailLog}
              onMenuAction={handleMenuAction}
              menuOpenId={menuOpenId}
              onMenuToggle={(id) => setMenuOpenId(menuOpenId === id ? null : id)}
            />
          </div>
        ))}
      </div>

      <AnimatePresence>
        {detailLog && (
          <DetailDrawer
            log={detailLog}
            onClose={() => setDetailLog(null)}
            onEdit={handleDetailEdit}
            onDelete={(id) => {
              deleteLog(id);
              showToast('想法已删除', 'info');
              setDetailLog(null);
            }}
            onTransfer={(id) => {
              const log = logs.find((l) => l.id === id);
              if (log) {
                updateLog(id, { category: log.category === 'idea' ? 'log' : 'idea' });
                showToast('已转至 Log', 'success');
                haptic(HAPTIC_SUCCESS);
              }
              setDetailLog(null);
            }}
          />
        )}
      </AnimatePresence>

      <EditDrawer
        editingId={editingId}
        initialContent={editContent}
        onSave={handleEditSave}
        onClose={() => {
          setEditingId(null);
          setEditContent('');
        }}
        placeholder="详细内容..."
      />
    </div>
  );
}
