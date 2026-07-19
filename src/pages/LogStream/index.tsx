import { useState } from 'react';
import { Search, Settings } from 'lucide-react';
import { AnimatePresence } from 'framer-motion';
import { useNavigationStore } from '@/stores/navigationStore';
import { useLogStore, type ColorTag } from '@/stores/logStore';
import { useToastStore } from '@/stores/toastStore';
import { haptic, HAPTIC_SUCCESS } from '@/lib/haptics';
import StreamList from './StreamList';
import InputArea, { type InputMode } from './InputArea';
import DetailDrawer from '@/components/DetailDrawer';
import EditDrawer from '@/components/EditDrawer';
import CategorySheet from './CategorySheet';

export default function LogStream() {
  const { navigateTo } = useNavigationStore();
  const addLog = useLogStore((state) => state.addLog);
  const deleteLog = useLogStore((state) => state.deleteLog);
  const updateLog = useLogStore((state) => state.updateLog);
  const showToast = useToastStore((state) => state.showToast);

  const [mode, setMode] = useState<InputMode>('idle');
  const [inputText, setInputText] = useState('');
  const [showCategorySheet, setShowCategorySheet] = useState(false);
  const [pendingContent, setPendingContent] = useState('');
  const [pendingTag, setPendingTag] = useState<ColorTag | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [detailLogId, setDetailLogId] = useState<string | null>(null);
  const [editingDetailId, setEditingDetailId] = useState<string | null>(null);
  const [editInitialContent, setEditInitialContent] = useState('');
  const detailLog = useLogStore((state) =>
    detailLogId ? state.logs.find((log) => log.id === detailLogId) : null
  );

  const handleSubmit = (content: string, tag: ColorTag | null) => {
    setPendingContent(content);
    setPendingTag(tag);
    setShowCategorySheet(true);
  };

  const handleCategoryCancel = () => {
    setInputText(pendingContent);
    setPendingContent('');
    setPendingTag(null);
    setShowCategorySheet(false);
  };

  const handleSave = (category: 'log' | 'idea') => {
    if (isSubmitting) return;
    setIsSubmitting(true);
    addLog(pendingContent, pendingTag || 'daily', category)
      .then(() => {
        showToast(category === 'idea' ? '已发送至 Idea Flow' : '记录已保存', 'success');
        haptic(HAPTIC_SUCCESS);
      })
      .catch(() => {
        showToast('保存失败，请重试', 'error');
      })
      .finally(() => {
        setIsSubmitting(false);
        setPendingContent('');
        setPendingTag(null);
        setInputText('');
        setShowCategorySheet(false);
        setMode('idle');
      });
  };

  const handleDetailEdit = (id: string, content: string) => {
    setEditingDetailId(id);
    setEditInitialContent(content);
  };

  const handleEditSave = (id: string, content: string) => {
    const save = content.trim()
      ? updateLog(id, { content: content.trim() })
          .then(() => {
            showToast('编辑已保存', 'success');
            haptic(HAPTIC_SUCCESS);
          })
          .catch(() => {
            showToast('保存失败，请重试', 'error');
          })
      : Promise.resolve();
    void save.finally(() => {
      setEditingDetailId(null);
      setEditInitialContent('');
    });
  };

  const handleEditClose = () => {
    setEditingDetailId(null);
    setEditInitialContent('');
  };

  const handleDelete = (id: string) => {
    deleteLog(id)
      .then(() => {
        showToast('记录已删除', 'info');
      })
      .catch(() => {
        showToast('删除失败，请重试', 'error');
      });
  };

  const handleTransfer = (id: string) => {
    const log = useLogStore.getState().logs.find((l) => l.id === id);
    if (!log) return;
    const nextCategory = log.category === 'idea' ? 'log' : 'idea';
    updateLog(id, { category: nextCategory })
      .then(() => {
        showToast(nextCategory === 'idea' ? '已转至 Idea Flow' : '已转回 Log', 'success');
        haptic(HAPTIC_SUCCESS);
      })
      .catch(() => {
        showToast('保存失败，请重试', 'error');
      });
  };

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center justify-between px-4 pt-3 pb-2">
        <div className="liquid-glass-pill px-4 py-1.5">
          <h1 className="text-lg font-semibold text-white">日志</h1>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => navigateTo('settings')}
            aria-label="设置"
            className="w-9 h-9 flex items-center justify-center rounded-full bg-white/5 active:bg-white/10 transition-colors"
          >
            <Settings size={18} className="text-white" />
          </button>
          <button
            onClick={() => navigateTo('logFlow')}
            aria-label="搜索记录"
            className="w-9 h-9 flex items-center justify-center rounded-full bg-white/5 active:bg-white/10 transition-colors"
          >
            <Search size={18} className="text-slate-300" />
          </button>
        </div>
      </div>

      <StreamList onDetail={(log) => setDetailLogId(log.id)} />

      <InputArea
        mode={mode}
        onModeChange={setMode}
        onSubmit={handleSubmit}
        text={inputText}
        onTextChange={setInputText}
      />

      <AnimatePresence>
        {detailLog && (
          <DetailDrawer
            log={detailLog}
            onClose={() => setDetailLogId(null)}
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
        onClose={handleCategoryCancel}
        onSave={handleSave}
        disabled={isSubmitting}
      />
    </div>
  );
}
