import { useRef, useState } from 'react';
import { motion } from 'framer-motion';
import { ChevronLeft, Upload, Download, Trash2, X } from 'lucide-react';
import { useNavigationStore } from '@/stores/navigationStore';
import { useLogStore } from '@/stores/logStore';
import { useEmotionStore } from '@/stores/emotionStore';
import { useToastStore } from '@/stores/toastStore';
import {
  exportBackup,
  validateBackup,
  mergeImport,
  overwriteImport,
  type FlashBackup,
} from '@/lib/backup';
import { exportToFile, readTextFromFile } from '@/lib/fileIO';
import ConfirmDrawer from '@/components/ConfirmDrawer';
import LiquidGlassCard from '@/components/LiquidGlassCard';

export default function Settings() {
  const { navigateTo } = useNavigationStore();
  const logs = useLogStore((s) => s.logs);
  const emotions = useEmotionStore((s) => s.emotions);
  const overwriteLogs = useLogStore((s) => s.overwriteLogs);
  const overwriteEmotions = useEmotionStore((s) => s.overwriteEmotions);
  const showToast = useToastStore((s) => s.showToast);

  const fileInputRef = useRef<HTMLInputElement>(null);
  const [showExportDrawer, setShowExportDrawer] = useState(false);
  const [exportNotes, setExportNotes] = useState('');
  const [pendingBackup, setPendingBackup] = useState<FlashBackup | null>(null);
  const [importMode, setImportMode] = useState<'merge' | 'overwrite'>('merge');
  const [showClearConfirm, setShowClearConfirm] = useState(false);

  const handleExport = async () => {
    if (logs.length === 0 && emotions.length === 0) {
      showToast('当前没有可导出的记录', 'info');
      return;
    }
    const backup = exportBackup(logs, emotions, exportNotes);
    const filename = `flash-backup-${new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-')}.json`;
    try {
      await exportToFile(backup, filename);
      showToast('备份已生成', 'success');
      setShowExportDrawer(false);
      setExportNotes('');
    } catch {
      showToast('导出失败，请检查权限', 'error');
    }
  };

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (file.size > 10 * 1024 * 1024) {
      showToast('文件过大，请检查是否为 Flash 备份', 'error');
      return;
    }
    try {
      const text = await readTextFromFile(file);
      const data: unknown = JSON.parse(text);
      const validation = validateBackup(data);
      if (!validation.valid) {
        showToast(`备份校验失败：${validation.errors[0]}`, 'error');
        return;
      }
      setPendingBackup(data as FlashBackup);
    } catch {
      showToast('无法解析该文件', 'error');
    } finally {
      e.target.value = '';
    }
  };

  const handleImport = () => {
    if (!pendingBackup) return;
    const logResult =
      importMode === 'merge'
        ? mergeImport(pendingBackup, logs, emotions)
        : overwriteImport(pendingBackup);
    overwriteLogs(logResult.logs);
    overwriteEmotions(logResult.emotions);
    const issueText = logResult.specificIssues.length > 0 ? `，${logResult.specificIssues[0]}` : '';
    showToast(
      `已导入 ${logResult.importedLogs} 条日志和 ${logResult.importedEmotions} 条情绪记录${issueText}`,
      'success'
    );
    setPendingBackup(null);
  };

  const handleClear = () => {
    overwriteLogs([]);
    overwriteEmotions([]);
    showToast('全部数据已清除', 'info');
    setShowClearConfirm(false);
  };

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center gap-3 px-4 pt-3 pb-2">
        <button
          onClick={() => navigateTo('log')}
          aria-label="返回"
          className="w-9 h-9 flex items-center justify-center rounded-full bg-white/5 active:bg-white/10 transition-colors"
        >
          <ChevronLeft size={20} className="text-white" />
        </button>
        <h1 className="text-lg font-semibold text-white">设置</h1>
      </div>

      <div className="flex-1 overflow-y-auto no-scrollbar px-4 pb-4 space-y-4">
        <section>
          <h2 className="text-xs font-medium text-slate-500 uppercase tracking-wider mb-2 px-1">
            数据管理
          </h2>
          <LiquidGlassCard>
            <div className="divide-y divide-white/10">
              <button
                onClick={() => setShowExportDrawer(true)}
                className="w-full flex items-center gap-3 py-3.5 text-left"
              >
                <Download size={18} className="text-blue-400" />
                <span className="text-sm text-white">导出备份</span>
              </button>
              <button
                onClick={() => fileInputRef.current?.click()}
                className="w-full flex items-center gap-3 py-3.5 text-left"
              >
                <Upload size={18} className="text-green-400" />
                <span className="text-sm text-white">导入备份</span>
              </button>
              <button
                onClick={() => setShowClearConfirm(true)}
                className="w-full flex items-center gap-3 py-3.5 text-left"
              >
                <Trash2 size={18} className="text-red-400" />
                <span className="text-sm text-white">清除全部数据</span>
              </button>
            </div>
          </LiquidGlassCard>
        </section>

        <section>
          <h2 className="text-xs font-medium text-slate-500 uppercase tracking-wider mb-2 px-1">
            关于
          </h2>
          <LiquidGlassCard>
            <div className="py-3 text-center">
              <p className="text-white font-medium">一闪 Flash</p>
              <p className="text-xs text-slate-400 mt-1">v0.1.0 · 本地优先的情绪与日志记录应用</p>
            </div>
          </LiquidGlassCard>
        </section>
      </div>

      <input
        ref={fileInputRef}
        type="file"
        accept=".json,application/json"
        className="hidden"
        onChange={(e) => {
          void handleFileSelect(e);
        }}
      />

      {showExportDrawer && (
        <ExportDrawer
          logCount={logs.length}
          emotionCount={emotions.length}
          notes={exportNotes}
          onNotesChange={setExportNotes}
          onExport={() => {
            void handleExport();
          }}
          onClose={() => setShowExportDrawer(false)}
        />
      )}

      {pendingBackup && (
        <ImportPreviewDrawer
          backup={pendingBackup}
          mode={importMode}
          onModeChange={setImportMode}
          onImport={handleImport}
          onClose={() => setPendingBackup(null)}
        />
      )}

      <ConfirmDrawer
        open={showClearConfirm}
        title="清除全部数据？"
        description={`将删除 ${logs.length} 条日志和 ${emotions.length} 条情绪记录，此操作不可恢复。`}
        confirmText="清除"
        cancelText="取消"
        danger
        onConfirm={handleClear}
        onCancel={() => setShowClearConfirm(false)}
      />
    </div>
  );
}

interface ExportDrawerProps {
  logCount: number;
  emotionCount: number;
  notes: string;
  onNotesChange: (value: string) => void;
  onExport: () => void;
  onClose: () => void;
}

function ExportDrawer({
  logCount,
  emotionCount,
  notes,
  onNotesChange,
  onExport,
  onClose,
}: ExportDrawerProps) {
  return (
    <div className="absolute inset-0 z-50 flex items-end bg-black/40" onClick={onClose}>
      <motion.div
        initial={{ y: '100%' }}
        animate={{ y: 0 }}
        exit={{ y: '100%' }}
        transition={{ type: 'spring', damping: 25, stiffness: 200 }}
        className="w-full rounded-t-3xl liquid-glass p-4 space-y-4"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between">
          <h3 className="text-base font-medium text-white">导出备份</h3>
          <button
            onClick={onClose}
            aria-label="关闭"
            className="w-8 h-8 flex items-center justify-center rounded-full bg-white/5"
          >
            <X size={16} className="text-slate-300" />
          </button>
        </div>
        <p className="text-sm text-slate-400">
          你即将导出 <span className="text-white font-medium">{logCount}</span> 条日志和{' '}
          <span className="text-white font-medium">{emotionCount}</span> 条情绪记录。
        </p>
        <input
          value={notes}
          onChange={(e) => onNotesChange(e.target.value)}
          placeholder="给这份备份写个备注…"
          maxLength={50}
          className="w-full bg-white/5 text-white text-sm rounded-xl px-3 py-2.5 outline-none placeholder-slate-500"
        />
        <button
          onClick={onExport}
          className="w-full py-3 rounded-xl bg-blue-500/30 text-white text-sm font-medium active:bg-blue-500/40 transition-colors"
        >
          生成备份文件
        </button>
      </motion.div>
    </div>
  );
}

interface ImportPreviewDrawerProps {
  backup: FlashBackup;
  mode: 'merge' | 'overwrite';
  onModeChange: (mode: 'merge' | 'overwrite') => void;
  onImport: () => void;
  onClose: () => void;
}

function ImportPreviewDrawer({
  backup,
  mode,
  onModeChange,
  onImport,
  onClose,
}: ImportPreviewDrawerProps) {
  return (
    <div className="absolute inset-0 z-50 flex items-end bg-black/40" onClick={onClose}>
      <motion.div
        initial={{ y: '100%' }}
        animate={{ y: 0 }}
        exit={{ y: '100%' }}
        transition={{ type: 'spring', damping: 25, stiffness: 200 }}
        className="w-full rounded-t-3xl liquid-glass p-4 space-y-4"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between">
          <h3 className="text-base font-medium text-white">确认导入</h3>
          <button
            onClick={onClose}
            aria-label="关闭"
            className="w-8 h-8 flex items-center justify-center rounded-full bg-white/5"
          >
            <X size={16} className="text-slate-300" />
          </button>
        </div>
        <div className="text-sm text-slate-400 space-y-1">
          <p>导出时间：{new Date(backup.exportedAt).toLocaleString('zh-CN')}</p>
          <p>应用版本：{backup.appVersion}</p>
          {backup.notes && <p>备注：{backup.notes}</p>}
          <p>
            内容：<span className="text-white">{backup.logs.length}</span> 条日志 +{' '}
            <span className="text-white">{backup.emotions.length}</span> 条情绪记录
          </p>
        </div>
        <div className="space-y-2">
          <label className="flex items-start gap-3 p-3 rounded-xl bg-white/5 cursor-pointer">
            <input
              type="radio"
              name="importMode"
              checked={mode === 'merge'}
              onChange={() => onModeChange('merge')}
              className="mt-0.5"
            />
            <div>
              <p className="text-sm text-white">合并导入（推荐）</p>
              <p className="text-xs text-slate-500">保留现有记录，重复内容会被覆盖</p>
            </div>
          </label>
          <label className="flex items-start gap-3 p-3 rounded-xl bg-red-500/10 cursor-pointer border border-red-500/20">
            <input
              type="radio"
              name="importMode"
              checked={mode === 'overwrite'}
              onChange={() => onModeChange('overwrite')}
              className="mt-0.5"
            />
            <div>
              <p className="text-sm text-red-400">覆盖导入</p>
              <p className="text-xs text-slate-500">用备份完全替换当前数据</p>
            </div>
          </label>
        </div>
        <button
          onClick={onImport}
          className={`w-full py-3 rounded-xl text-white text-sm font-medium transition-colors ${
            mode === 'overwrite'
              ? 'bg-red-500/30 active:bg-red-500/40'
              : 'bg-blue-500/30 active:bg-blue-500/40'
          }`}
        >
          {mode === 'merge' ? '合并导入' : '确认覆盖'}
        </button>
      </motion.div>
    </div>
  );
}
