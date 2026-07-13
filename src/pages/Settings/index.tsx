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
  sanitizeBackup,
  type FlashBackup,
  type ImportResult,
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
  const [importIssues, setImportIssues] = useState<string[]>([]);
  const [previewResult, setPreviewResult] = useState<ImportResult | null>(null);
  const [importFinished, setImportFinished] = useState(false);
  const [showClearConfirm, setShowClearConfirm] = useState(false);

  const closeImportDrawer = () => {
    setPendingBackup(null);
    setPreviewResult(null);
    setImportIssues([]);
    setImportFinished(false);
  };

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
    e.target.value = '';
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
      const backup = data as FlashBackup;
      const preview = sanitizeBackup(backup);
      setImportFinished(false);
      setImportIssues(
        preview.importedLogs === 0 && preview.importedEmotions === 0
          ? [...preview.specificIssues, '备份中没有可导入的有效记录，未执行覆盖']
          : preview.specificIssues
      );
      setPreviewResult(preview);
      setPendingBackup(backup);
    } catch {
      showToast('无法解析该文件', 'error');
    }
  };

  const handleImport = () => {
    if (!pendingBackup || !previewResult) return;
    if (previewResult.importedLogs === 0 && previewResult.importedEmotions === 0) {
      setImportIssues((prev) =>
        prev.includes('备份中没有可导入的有效记录，未执行覆盖')
          ? prev
          : [...prev, '备份中没有可导入的有效记录，未执行覆盖']
      );
      return;
    }
    const result =
      importMode === 'merge'
        ? mergeImport(pendingBackup, logs, emotions)
        : overwriteImport(pendingBackup);
    overwriteLogs(result.logs);
    overwriteEmotions(result.emotions);
    setImportFinished(true);
    if (result.specificIssues.length > 0) {
      setImportIssues(result.specificIssues);
      return;
    }
    showToast(
      `已导入 ${result.importedLogs} 条日志和 ${result.importedEmotions} 条情绪记录`,
      'success'
    );
    closeImportDrawer();
  };

  const handleDismissIssues = () => {
    closeImportDrawer();
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
        data-testid="import-file-input"
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

      {pendingBackup && previewResult && (
        <ImportPreviewDrawer
          backup={pendingBackup}
          mode={importMode}
          issues={importIssues}
          previewResult={previewResult}
          importFinished={importFinished}
          onModeChange={setImportMode}
          onImport={handleImport}
          onClose={closeImportDrawer}
          onDismissIssues={handleDismissIssues}
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
  issues: string[];
  previewResult: ImportResult;
  importFinished: boolean;
  onModeChange: (mode: 'merge' | 'overwrite') => void;
  onImport: () => void;
  onClose: () => void;
  onDismissIssues: () => void;
}

function ImportPreviewDrawer({
  backup,
  mode,
  issues,
  previewResult,
  importFinished,
  onModeChange,
  onImport,
  onClose,
  onDismissIssues,
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
            内容：
            <span data-testid="preview-log-count" className="text-white">
              {previewResult.importedLogs}
            </span>{' '}
            条日志 +{' '}
            <span data-testid="preview-emotion-count" className="text-white">
              {previewResult.importedEmotions}
            </span>{' '}
            条情绪记录
          </p>
        </div>
        {issues.length > 0 && (
          <div className="rounded-xl bg-yellow-500/10 border border-yellow-500/20 p-3 space-y-2">
            <p className="text-sm text-yellow-400">
              {importFinished ? '导入完成，但存在以下问题：' : '存在以下问题，导入时将跳过：'}
            </p>
            <ul className="text-sm text-slate-300 space-y-1 list-disc list-inside">
              {issues.map((issue, index) => (
                <li key={index}>{issue}</li>
              ))}
            </ul>
            <button
              onClick={onDismissIssues}
              className="w-full py-2 rounded-lg bg-yellow-500/20 text-yellow-400 text-sm font-medium active:bg-yellow-500/30 transition-colors"
            >
              我知道了
            </button>
          </div>
        )}
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
        {(() => {
          const canImport = previewResult.importedLogs > 0 || previewResult.importedEmotions > 0;
          const disabled = !canImport || (importFinished && issues.length > 0);
          const label = !canImport
            ? '无法导入'
            : importFinished && issues.length > 0
              ? '已导入'
              : mode === 'merge'
                ? '合并导入'
                : '确认覆盖';
          return (
            <button
              onClick={onImport}
              disabled={disabled}
              className={`w-full py-3 rounded-xl text-sm font-medium transition-colors ${
                disabled
                  ? 'bg-white/10 text-slate-500 cursor-not-allowed'
                  : mode === 'overwrite'
                    ? 'bg-red-500/30 text-white active:bg-red-500/40'
                    : 'bg-blue-500/30 text-white active:bg-blue-500/40'
              }`}
            >
              {label}
            </button>
          );
        })()}
      </motion.div>
    </div>
  );
}
