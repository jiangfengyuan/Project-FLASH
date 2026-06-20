import { useState } from 'react';
import { Search } from 'lucide-react';
import { AnimatePresence } from 'framer-motion';
import { useNavigationStore } from '@/stores/navigationStore';
import { useLogStore, type ColorTag, type LogItem } from '@/stores/logStore';
import { useToastStore } from '@/stores/toastStore';
import { haptic, HAPTIC_SUCCESS } from '@/lib/haptics';
import StreamList from './StreamList';
import InputArea, { type InputMode } from './InputArea';
import DetailDrawer from '@/components/DetailDrawer';
import EditDrawer from '@/components/EditDrawer';
import CategorySheet from './CategorySheet';

export default function LogStream() {
  const { navigateTo } = useNavigationStore();
  const logs = useLogStore((state) => state.logs);
  const addLog = useLogStore((state) => state.addLog);
  const deleteLog = useLogStore((state) => state.deleteLog);
  const updateLog = useLogStore((state) => state.updateLog);
  const showToast = useToastStore((state) => state.showToast);

  const [mode, setMode] = useState<InputMode>('idle');
  const [showCategorySheet, setShowCategorySheet] = useState(false);
  const [pendingContent, setPendingContent] = useState('');
  const [pendingTag, setPendingTag] = useState<ColorTag | null>(null);
  const [detailLog, setDetailLog] = useState<LogItem | null>(null);
  const [editingDetailId, setEditingDetailId] = useState<string | null>(null);
  const [editInitialContent, setEditInitialContent] = useState('');

  const handleSubmit = (content: string, tag: ColorTag | null) => {
    setPendingContent(content);
    setPendingTag(tag);
    setShowCategorySheet(true);
  };

  const handleSave = (category: 'log' | 'idea') => {
    addLog(pendingContent, pendingTag || 'daily', category);
    showToast(category === 'idea' ? '已发送至 Idea Flow' : '记录已保存', 'success');
    haptic(HAPTIC_SUCCESS);
    setPendingContent('');
    setPendingTag(null);
    setShowCategorySheet(false);
    setMode('idle');
  };

  const handleDetailEdit = (id: string, content: string) => {
    setEditingDetailId(id);
    setEditInitialContent(content);
  };

  const handleEditSave = (id: string, content: string) => {
    if (content.trim()) {
      updateLog(id, { content: content.trim() });
      showToast('编辑已保存', 'success');
      haptic(HAPTIC_SUCCESS);
    }
    setEditingDetailId(null);
    setEditInitialContent('');
  };

  const handleEditClose = () => {
    setEditingDetailId(null);
    setEditInitialContent('');
  };

  const handleDelete = (id: string) => {
    deleteLog(id);
    showToast('记录已删除', 'info');
  };

  const handleTransfer = (id: string) => {
    const log = logs.find((l) => l.id === id);
    if (log) {
      const nextCategory = log.category === 'idea' ? 'log' : 'idea';
      updateLog(id, { category: nextCategory });
      showToast(nextCategory === 'idea' ? '已转至 Idea Flow' : '已转回 Log', 'success');
      haptic(HAPTIC_SUCCESS);
    }
  };

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center justify-between px-4 pt-3 pb-2">
        <div className="liquid-glass-pill px-4 py-1.5">
          <h1 className="text-lg font-semibold text-white">日志</h1>
        </div>
        <button
          onClick={() => navigateTo('logFlow')}
          aria-label="搜索记录"
          className="w-9 h-9 flex items-center justify-center rounded-full bg-white/5 active:bg-white/10 transition-colors"
        >
          <Search size={18} className="text-slate-300" />
        </button>
      </div>

      <StreamList onDetail={setDetailLog} />

      <InputArea mode={mode} onModeChange={setMode} onSubmit={handleSubmit} />

      <AnimatePresence>
        {detailLog && (
          <DetailDrawer
            log={detailLog}
            onClose={() => setDetailLog(null)}
            onEdit={handleDetailEdit}
            onDelete={handleDelete}
            onTransfer={handleTransfer}
          />
        )}
      </AnimatePresence>

      <EditDrawer
        editingId={editingDetailId}
        initialContent={editInitialContent}
        onSave={handleEditSave}
        onClose={handleEditClose}
      />

      <CategorySheet
        open={showCategorySheet}
        onClose={() => setShowCategorySheet(false)}
        onSave={handleSave}
      />
    </div>
  );
}
