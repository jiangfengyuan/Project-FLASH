import { useState, useRef, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Mic, Keyboard, Send, X, Clock, Search, ArrowRight, ChevronLeft, Trash2, Archive, Edit3, Lightbulb } from 'lucide-react';
import { useAppStore } from '@/stores/appStore';
import { useLogStore, TAG_COLORS, TAG_NAMES, type ColorTag } from '@/stores/logStore';
import LiquidGlassCard from '@/components/LiquidGlassCard';
import { format } from 'date-fns';

const colorTags: ColorTag[] = ['urgent', 'inspiration', 'daily', 'memo', 'emotion', 'idea'];

export default function LogStream() {
  const { navigateTo } = useAppStore();
  const { logs, addLog, deleteLog, updateLog } = useLogStore();
  const [mode, setMode] = useState<'idle' | 'typing' | 'recording' | 'preview'>('idle');
  const [text, setText] = useState('');
  const [selectedTag, setSelectedTag] = useState<ColorTag | null>(null);
  const [showCategorySheet, setShowCategorySheet] = useState(false);
  const [pendingContent, setPendingContent] = useState('');
  const inputRef = useRef<HTMLInputElement>(null!);
  const [recordingTime, setRecordingTime] = useState(0);
  const recordingTimer = useRef<ReturnType<typeof setInterval>>(undefined);
  const [detailLog, setDetailLog] = useState<typeof logs[0] | null>(null);
  const [editingDetailId, setEditingDetailId] = useState<string | null>(null);
  const [editContent, setEditContent] = useState('');

  const streamLogs = logs.filter((l) => l.category === 'log').slice(0, 20);

  useEffect(() => {
    if (mode === 'typing' && inputRef.current) {
      inputRef.current.focus();
    }
  }, [mode]);

  useEffect(() => {
    if (mode === 'recording') {
      recordingTimer.current = setInterval(() => {
        setRecordingTime((t) => t + 1);
      }, 1000);
    }
    return () => {
      if (recordingTimer.current) clearInterval(recordingTimer.current);
    };
  }, [mode]);

  const handleTextSubmit = () => {
    if (!text.trim()) return;
    if (text.length > 140) {
      setText(text.slice(0, 140));
      return;
    }
    setPendingContent(text.trim());
    setShowCategorySheet(true);
  };

  const handleSave = (category: 'log' | 'idea') => {
    addLog(pendingContent, selectedTag || 'daily', category);
    setText('');
    setSelectedTag(null);
    setPendingContent('');
    setShowCategorySheet(false);
    setMode('idle');
  };

  const startRecording = () => {
    setMode('recording');
    setRecordingTime(0);
  };

  const stopRecording = () => {
    setMode('preview');
    if (recordingTimer.current) clearInterval(recordingTimer.current);
  };

  const formatTime = (s: number) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center justify-between px-4 pt-3 pb-2">
        <div className="liquid-glass-pill px-4 py-1.5">
          <h1 className="text-lg font-semibold text-white">一闪</h1>
        </div>
        <button
          onClick={() => navigateTo('logFlow')}
          className="w-9 h-9 flex items-center justify-center rounded-full bg-white/5 active:bg-white/10 transition-colors"
        >
          <Search size={18} className="text-slate-300" />
        </button>
      </div>

      {/* Stream List */}
      <div className="flex-1 overflow-y-auto no-scrollbar px-4 pb-48 pt-2 space-y-3">
        {/* Quick access */}
        <div className="flex gap-2 mb-4">
          <button
            onClick={() => navigateTo('logFlow')}
            className="liquid-glass-pill px-3 py-1.5 flex items-center gap-1.5 text-xs text-slate-300 active:scale-95 transition-transform"
          >
            <ArrowRight size={12} />
            LOGS
          </button>
          <button
            onClick={() => navigateTo('idea')}
            className="liquid-glass-pill px-3 py-1.5 flex items-center gap-1.5 text-xs text-slate-300 active:scale-95 transition-transform"
          >
            <ArrowRight size={12} />
            IDEAS
          </button>
        </div>

        {streamLogs.map((log, i) => (
          <LiquidGlassCard
            key={log.id}
            colorTag={TAG_COLORS[log.colorTag]}
            index={i}
            onClick={() => setDetailLog(log)}
          >
            <div className="py-3 pr-4">
              <p className="text-[15px] text-white leading-relaxed">{log.content}</p>
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
                  {format(new Date(log.createdAt), 'HH:mm')}
                </span>
              </div>
            </div>
          </LiquidGlassCard>
        ))}

        {streamLogs.length === 0 && (
          <div className="flex flex-col items-center justify-center py-20 text-slate-500">
            <Clock size={40} className="mb-3 opacity-40" />
            <p className="text-sm">还没有记录</p>
            <p className="text-xs mt-1">点击下方按钮开始记录</p>
          </div>
        )}
      </div>

      {/* Input Area */}
      <div className="fixed bottom-16 left-0 right-0 px-4 z-40">
        <AnimatePresence mode="wait">
          {mode === 'idle' && (
            <motion.div
              key="idle"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 20 }}
              className="flex items-center justify-center gap-6"
            >
              {/* Recording Button */}
              <motion.button
                onTouchStart={startRecording}
                onMouseDown={startRecording}
                className="relative w-16 h-16 rounded-full flex items-center justify-center animate-breathe"
                style={{
                  background: 'rgba(255,255,255,0.08)',
                  backdropFilter: 'blur(20px)',
                  border: '1px solid rgba(255,255,255,0.15)',
                }}
              >
                <div
                  className="absolute inset-0 rounded-full"
                  style={{
                    boxShadow: 'inset 0 1px 2px rgba(255,255,255,0.15), 0 4px 20px rgba(100,80,255,0.2)',
                  }}
                />
                <Mic size={24} className="text-white relative z-10" />
              </motion.button>

              {/* Text Input Toggle */}
              <motion.button
                onClick={() => setMode('typing')}
                className="liquid-glass-pill w-12 h-12 flex items-center justify-center active:scale-95"
                whileTap={{ scale: 0.9 }}
              >
                <Keyboard size={20} className="text-slate-300" />
              </motion.button>
            </motion.div>
          )}

          {mode === 'recording' && (
            <motion.div
              key="recording"
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.8 }}
              className="flex flex-col items-center"
            >
              {/* Pulse rings */}
              <div className="relative">
                <div className="absolute inset-0 rounded-full animate-pulse-ring bg-red-500/30" />
                <div
                  className="absolute inset-0 rounded-full animate-pulse-ring bg-red-500/20"
                  style={{ animationDelay: '0.4s' }}
                />
                <button
                  onClick={stopRecording}
                  className="relative w-20 h-20 rounded-full bg-red-500/80 backdrop-blur flex items-center justify-center"
                  style={{
                    boxShadow: '0 0 30px rgba(239,68,68,0.4)',
                  }}
                >
                  <Mic size={28} className="text-white" />
                </button>
              </div>
              <div className="liquid-glass-sm mt-4 px-6 py-2 flex items-center gap-2">
                <div className="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
                <span className="text-white font-mono text-sm">{formatTime(recordingTime)}</span>
              </div>
              <p className="text-xs text-slate-400 mt-2">松手结束录音</p>
            </motion.div>
          )}

          {mode === 'preview' && (
            <motion.div
              key="preview"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 20 }}
              className="space-y-3"
            >
              <div className="liquid-glass p-4">
                <p className="text-white text-sm">[语音转写预览] 今天在课堂上想到了一个很好的创意...</p>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => {
                    setPendingContent('今天在课堂上想到了一个很好的创意');
                    setShowCategorySheet(true);
                  }}
                  className="flex-1 liquid-glass-pill py-2.5 text-sm text-white font-medium active:scale-95 transition-transform"
                >
                  保存
                </button>
                <button
                  onClick={() => setMode('idle')}
                  className="flex-1 liquid-glass-pill py-2.5 text-sm text-slate-300 active:scale-95 transition-transform"
                >
                  取消
                </button>
              </div>
            </motion.div>
          )}

          {mode === 'typing' && (
            <motion.div
              key="typing"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 20 }}
              className="space-y-3"
            >
              {/* Tag Selection */}
              <div className="flex gap-2 overflow-x-auto no-scrollbar pb-1">
                {colorTags.map((tag) => (
                  <button
                    key={tag}
                    onClick={() => setSelectedTag(selectedTag === tag ? null : tag)}
                    className={`flex-shrink-0 px-3 py-1 rounded-full text-[11px] transition-all ${
                      selectedTag === tag
                        ? 'text-white scale-105'
                        : 'bg-white/5 text-slate-400 border border-white/10'
                    }`}
                    style={
                      selectedTag === tag
                        ? { backgroundColor: TAG_COLORS[tag] }
                        : {}
                    }
                  >
                    {TAG_NAMES[tag]}
                  </button>
                ))}
              </div>

              {/* Input Field */}
              <div className="liquid-glass-input flex items-center gap-2 px-4 py-3">
                <input
                  ref={inputRef}
                  value={text}
                  onChange={(e) => setText(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && handleTextSubmit()}
                  placeholder="闪过即留..."
                  maxLength={140}
                  className="flex-1 bg-transparent text-white text-[15px] placeholder-slate-500 outline-none"
                />
                <span className={`text-[10px] ${text.length > 130 ? 'text-red-400' : 'text-slate-500'}`}>
                  {text.length}/140
                </span>
                <button
                  onClick={handleTextSubmit}
                  disabled={!text.trim()}
                  className="w-8 h-8 rounded-full bg-blue-500/80 flex items-center justify-center disabled:opacity-30 active:scale-90 transition-transform"
                >
                  <Send size={14} className="text-white" />
                </button>
                <button onClick={() => { setMode('idle'); setText(''); }} className="w-8 h-8 flex items-center justify-center">
                  <X size={16} className="text-slate-400" />
                </button>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Detail Full-screen Page */}
      <AnimatePresence>
        {detailLog && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[90] flex flex-col"
          >
            {/* Backdrop */}
            <div className="absolute inset-0 bg-black/60 backdrop-blur-md" onClick={() => setDetailLog(null)} />

            {/* Detail Content */}
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
                  {/* Tag */}
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
                      className="text-[11px] px-3 py-1 rounded-full bg-white/5 text-slate-400"
                    >
                      {detailLog.category === 'idea' ? 'IDEA' : 'LOG'}
                    </span>
                  </div>

                  {/* Content */}
                  <p className="text-lg text-white leading-relaxed whitespace-pre-wrap">
                    {detailLog.content}
                  </p>

                  {/* Date section */}
                  <div className="mt-8 pt-4 border-t border-white/10">
                    <div className="flex items-center gap-4 text-xs text-slate-500">
                      <div className="flex items-center gap-1.5">
                        <Clock size={12} />
                        <span>记录于 {format(new Date(detailLog.createdAt), 'MM月dd日 HH:mm')}</span>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Bottom Actions - Edit / Archive / Transfer / Delete */}
                <div className="px-4 pb-20 pt-3 border-t border-white/10 grid grid-cols-4 gap-2">
                  <button
                    onClick={() => {
                      setEditContent(detailLog.content);
                      setEditingDetailId(detailLog.id);
                      setDetailLog(null);
                    }}
                    className="liquid-glass-pill py-2.5 text-[10px] text-slate-300 flex flex-col items-center justify-center gap-1 active:scale-[0.98]"
                  >
                    <Edit3 size={13} />
                    编辑
                  </button>
                  <button
                    onClick={() => {
                      updateLog(detailLog.id, { category: detailLog.category === 'idea' ? 'log' : 'idea' });
                      setDetailLog(null);
                    }}
                    className="liquid-glass-pill py-2.5 text-[10px] text-slate-300 flex flex-col items-center justify-center gap-1 active:scale-[0.98]"
                  >
                    <Archive size={13} />
                    归档
                  </button>
                  <button
                    onClick={() => {
                      updateLog(detailLog.id, { category: 'idea' });
                      setDetailLog(null);
                    }}
                    className="liquid-glass-pill py-2.5 text-[10px] text-amber-300 flex flex-col items-center justify-center gap-1 active:scale-[0.98]"
                    style={{ background: 'rgba(255,159,67,0.1)' }}
                  >
                    <Lightbulb size={13} />
                    转Idea
                  </button>
                  <button
                    onClick={() => {
                      deleteLog(detailLog.id);
                      setDetailLog(null);
                    }}
                    className="liquid-glass-pill py-2.5 text-[10px] text-red-400 flex flex-col items-center justify-center gap-1 active:scale-[0.98]"
                    style={{ background: 'rgba(239,68,68,0.08)' }}
                  >
                    <Trash2 size={13} />
                    删除
                  </button>
                </div>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Edit Detail Modal */}
      <AnimatePresence>
        {editingDetailId && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[80] flex items-end justify-center"
            onClick={() => setEditingDetailId(null)}
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
                  placeholder="编辑内容..."
                  rows={6}
                  className="w-full bg-transparent text-sm text-white placeholder-slate-500 outline-none resize-none leading-relaxed"
                />
                <div className="flex gap-2">
                  <button
                    onClick={() => {
                      if (editContent.trim()) {
                        updateLog(editingDetailId, { content: editContent.trim() });
                      }
                      setEditingDetailId(null);
                      setEditContent('');
                    }}
                    className="flex-1 liquid-glass-pill py-3 text-white text-sm font-medium active:scale-[0.98]"
                  >
                    保存
                  </button>
                  <button
                    onClick={() => { setEditingDetailId(null); setEditContent(''); }}
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

      {/* Category Action Sheet */}
      <AnimatePresence>
        {showCategorySheet && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[80] flex items-end justify-center"
            onClick={() => setShowCategorySheet(false)}
          >
            <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" />
            <motion.div
              initial={{ y: 100 }}
              animate={{ y: 0 }}
              exit={{ y: 100 }}
              className="relative w-full max-w-md mx-auto p-4 pb-8 space-y-3"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="liquid-glass p-4 space-y-2">
                <p className="text-center text-sm text-slate-400 mb-3">保存为</p>
                <button
                  onClick={() => handleSave('log')}
                  className="w-full liquid-glass-pill py-3.5 text-white font-medium text-sm active:scale-[0.98] transition-transform"
                >
                  作为 LOG 保存
                </button>
                <button
                  onClick={() => handleSave('idea')}
                  className="w-full liquid-glass-pill py-3.5 text-amber-300 font-medium text-sm active:scale-[0.98] transition-transform"
                  style={{ background: 'rgba(255,159,67,0.15)' }}
                >
                  作为 IDEA 发送
                </button>
              </div>
              <button
                onClick={() => setShowCategorySheet(false)}
                className="w-full liquid-glass-pill py-3 text-slate-400 text-sm active:scale-[0.98] transition-transform"
              >
                取消
              </button>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
