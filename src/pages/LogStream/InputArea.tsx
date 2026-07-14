import { useState, useRef, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Mic, Keyboard, Send, X } from 'lucide-react';
import { COLOR_TAGS, TAG_COLORS, TAG_NAMES } from '@/lib/constants';
import type { ColorTag } from '@/lib/constants';
import { useToastStore } from '@/stores/toastStore';
import { haptic, HAPTIC_SUCCESS, HAPTIC_TAP, HAPTIC_WARNING } from '@/lib/haptics';
import { useReducedMotion } from '@/lib/motion';

export type InputMode = 'idle' | 'typing' | 'recording' | 'preview';

interface InputAreaProps {
  mode: InputMode;
  onModeChange: (mode: InputMode) => void;
  onSubmit: (content: string, tag: ColorTag | null) => void;
}

interface SpeechRecognitionErrorEvent extends Event {
  error: string;
}

interface SpeechRecognitionEvent extends Event {
  results: SpeechRecognitionResultList;
}

interface SpeechRecognitionInstance {
  lang: string;
  continuous: boolean;
  interimResults: boolean;
  onresult: ((event: SpeechRecognitionEvent) => void) | null;
  onerror: ((event: SpeechRecognitionErrorEvent) => void) | null;
  onend: (() => void) | null;
  start(): void;
  stop(): void;
}

declare global {
  interface Window {
    SpeechRecognition?: new () => SpeechRecognitionInstance;
    webkitSpeechRecognition?: new () => SpeechRecognitionInstance;
  }
}

function formatTime(s: number) {
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

function getSpeechRecognition(): (new () => SpeechRecognitionInstance) | null {
  if (typeof window === 'undefined') return null;
  return (
    (window as unknown as { SpeechRecognition?: new () => SpeechRecognitionInstance })
      .SpeechRecognition ||
    (window as unknown as { webkitSpeechRecognition?: new () => SpeechRecognitionInstance })
      .webkitSpeechRecognition ||
    null
  );
}

export default function InputArea({ mode, onModeChange, onSubmit }: InputAreaProps) {
  const reduced = useReducedMotion();
  const showToast = useToastStore((state) => state.showToast);
  const [text, setText] = useState('');
  const [selectedTag, setSelectedTag] = useState<ColorTag | null>(null);
  const [recordingTime, setRecordingTime] = useState(0);
  const [transcript, setTranscript] = useState('');
  const [recordingError, setRecordingError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const recordingTimer = useRef<ReturnType<typeof setInterval>>(undefined);
  const recognitionRef = useRef<SpeechRecognitionInstance | null>(null);
  const recordingActiveRef = useRef(false);
  const finalTranscriptRef = useRef('');
  const interimTranscriptRef = useRef('');
  const lastFinalIndexRef = useRef(-1);
  const endInPreviewTimeoutRef = useRef<ReturnType<typeof setTimeout>>(undefined);
  const shouldEndInPreviewRef = useRef(false);

  const SpeechRecognitionCtor = getSpeechRecognition();
  const speechSupported = SpeechRecognitionCtor !== null;

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
      if (recordingTimer.current) {
        clearInterval(recordingTimer.current);
        recordingTimer.current = undefined;
      }
    };
  }, [mode]);

  const stopRecognition = useCallback(() => {
    if (recognitionRef.current) {
      try {
        recognitionRef.current.stop();
      } catch {
        // ignore
      }
      recognitionRef.current = null;
    }
  }, []);

  const startRecording = () => {
    if (recordingActiveRef.current) return;
    recordingActiveRef.current = true;

    haptic(HAPTIC_TAP);
    setRecordingError(null);
    setTranscript('');
    finalTranscriptRef.current = '';
    interimTranscriptRef.current = '';
    lastFinalIndexRef.current = -1;

    if (!speechSupported) {
      showToast('当前浏览器不支持语音转写，请使用键盘输入', 'error');
      haptic(HAPTIC_WARNING);
      recordingActiveRef.current = false;
      return;
    }

    onModeChange('recording');
    setRecordingTime(0);
    shouldEndInPreviewRef.current = true;

    const recognition: SpeechRecognitionInstance = new SpeechRecognitionCtor();
    recognition.lang = 'zh-CN';
    recognition.continuous = true;
    recognition.interimResults = true;

    recognition.onresult = (event: SpeechRecognitionEvent) => {
      const results = event.results;
      let interim = '';
      for (let i = 0; i < results.length; i++) {
        const result = results.item(i);
        const transcriptText = result.item(0).transcript;
        if (result.isFinal) {
          if (i > lastFinalIndexRef.current) {
            finalTranscriptRef.current += (finalTranscriptRef.current ? ' ' : '') + transcriptText;
            lastFinalIndexRef.current = i;
          }
        } else {
          interim = transcriptText;
        }
      }
      interimTranscriptRef.current = interim;
      const display = finalTranscriptRef.current + (interim ? ` ${interim}...` : '');
      setTranscript(display.trim());
    };

    recognition.onerror = (event: SpeechRecognitionErrorEvent) => {
      if (event.error === 'aborted' || event.error === 'no-speech') return;
      setRecordingError('语音识别出错，请重试');
      shouldEndInPreviewRef.current = false;
      stopRecognition();
      recordingActiveRef.current = false;
      onModeChange('idle');
      showToast('语音识别出错，请重试', 'error');
      haptic(HAPTIC_WARNING);
    };

    recognition.onend = () => {
      recordingActiveRef.current = false;
      // Defer mode change to avoid racing with stopRecording.
      endInPreviewTimeoutRef.current = setTimeout(() => {
        if (shouldEndInPreviewRef.current) {
          shouldEndInPreviewRef.current = false;
          onModeChange('preview');
        }
      }, 0);
    };

    recognitionRef.current = recognition;
    recognition.start();
  };

  const stopRecording = useCallback(() => {
    if (!recordingActiveRef.current) return;
    recordingActiveRef.current = false;
    shouldEndInPreviewRef.current = false;

    if (recordingTimer.current) {
      clearInterval(recordingTimer.current);
      recordingTimer.current = undefined;
    }
    if (endInPreviewTimeoutRef.current) {
      clearTimeout(endInPreviewTimeoutRef.current);
      endInPreviewTimeoutRef.current = undefined;
    }
    stopRecognition();
    if (!transcript.trim()) {
      onModeChange('idle');
      showToast('未识别到语音，请重试', 'info');
      return;
    }
    onModeChange('preview');
  }, [stopRecognition, transcript, onModeChange, showToast]);

  // Safety net: stop recording if pointer/touch ends anywhere outside the button.
  useEffect(() => {
    if (mode !== 'recording') return;

    const handleGlobalPointerUp = () => {
      if (recordingActiveRef.current) {
        stopRecording();
      }
    };

    document.addEventListener('pointerup', handleGlobalPointerUp);
    document.addEventListener('touchend', handleGlobalPointerUp);

    return () => {
      document.removeEventListener('pointerup', handleGlobalPointerUp);
      document.removeEventListener('touchend', handleGlobalPointerUp);
    };
  }, [mode, stopRecording]);

  const handleTextSubmit = () => {
    if (!text.trim()) return;
    let content = text.trim();
    if (content.length > 140) {
      content = content.slice(0, 140);
      showToast('内容超过 140 字，已自动截断', 'info');
    }
    onSubmit(content, selectedTag);
    haptic(HAPTIC_SUCCESS);
    setText('');
    setSelectedTag(null);
  };

  const handleVoiceSubmit = () => {
    const clean = transcript.replace(/\.\.\.$/, '').trim();
    if (!clean) {
      showToast('没有可保存的内容', 'error');
      return;
    }
    onSubmit(clean, null);
    haptic(HAPTIC_SUCCESS);
    setTranscript('');
    setRecordingTime(0);
  };

  const handleCancel = () => {
    shouldEndInPreviewRef.current = false;
    if (endInPreviewTimeoutRef.current) {
      clearTimeout(endInPreviewTimeoutRef.current);
      endInPreviewTimeoutRef.current = undefined;
    }
    stopRecognition();
    onModeChange('idle');
    setText('');
    setSelectedTag(null);
    setTranscript('');
    finalTranscriptRef.current = '';
    interimTranscriptRef.current = '';
    lastFinalIndexRef.current = -1;
    setRecordingTime(0);
    setRecordingError(null);
  };

  return (
    <div className="fixed bottom-16 left-0 right-0 px-4 z-40">
      <AnimatePresence mode="wait">
        {mode === 'idle' && (
          <motion.div
            key="idle"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 20 }}
            transition={{ duration: reduced ? 0 : 0.25 }}
            className="flex items-center justify-center gap-6"
          >
            <motion.button
              onPointerDown={startRecording}
              onPointerUp={stopRecording}
              onPointerLeave={stopRecording}
              onPointerCancel={stopRecording}
              onContextMenu={(e) => e.preventDefault()}
              aria-label={speechSupported ? '按住录音' : '当前浏览器不支持语音转写'}
              className="relative w-16 h-16 rounded-full flex items-center justify-center animate-breathe"
              style={{
                background: 'rgba(255,255,255,0.08)',
                backdropFilter: 'blur(20px)',
                border: '1px solid rgba(255,255,255,0.15)',
                touchAction: 'none',
                WebkitUserSelect: 'none',
                userSelect: 'none',
              }}
            >
              <div
                className="absolute inset-0 rounded-full"
                style={{
                  boxShadow: 'var(--shadow-card)',
                }}
              />
              <Mic size={24} className="text-white relative z-10" />
              {!speechSupported && (
                <span className="absolute -top-1 -right-1 w-3 h-3 rounded-full bg-slate-500" />
              )}
            </motion.button>

            <motion.button
              onClick={() => onModeChange('typing')}
              aria-label="键盘输入"
              className="liquid-glass-pill w-12 h-12 flex items-center justify-center active:scale-95 transition-transform"
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
            transition={{ duration: reduced ? 0 : 0.25 }}
            className="flex flex-col items-center"
          >
            <div className="relative">
              <div className="absolute inset-0 rounded-full animate-pulse-ring bg-red-500/30" />
              <div
                className="absolute inset-0 rounded-full animate-pulse-ring bg-red-500/20"
                style={{ animationDelay: '0.4s' }}
              />
              <button
                onClick={stopRecording}
                aria-label="结束录音"
                className="relative w-20 h-20 rounded-full bg-red-500/80 backdrop-blur flex items-center justify-center active:scale-95 transition-transform"
                style={{ boxShadow: '0 0 30px rgba(239,68,68,0.4)' }}
              >
                <Mic size={28} className="text-white" />
              </button>
            </div>
            <div className="liquid-glass-sm mt-4 px-6 py-2 flex items-center gap-2">
              <div className="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
              <span className="text-white font-mono text-sm">{formatTime(recordingTime)}</span>
            </div>
            <p className="text-xs text-slate-400 mt-2">点击结束录音</p>
          </motion.div>
        )}

        {mode === 'preview' && (
          <motion.div
            key="preview"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 20 }}
            transition={{ duration: reduced ? 0 : 0.25 }}
            className="space-y-3"
          >
            <div className="liquid-glass p-4">
              <p className="text-white text-sm min-h-[1.25rem]">{transcript || '识别中...'}</p>
            </div>
            {recordingError && <p className="text-xs text-red-400 text-center">{recordingError}</p>}
            <div className="flex items-center gap-2">
              <button
                onClick={handleVoiceSubmit}
                disabled={!transcript.trim()}
                className="flex-1 liquid-glass-pill py-2.5 text-sm text-white font-medium active:scale-95 transition-transform disabled:opacity-40 flex items-center justify-center gap-2"
              >
                <Send size={14} /> 保存
              </button>
              <button
                onClick={handleCancel}
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
            transition={{ duration: reduced ? 0 : 0.25 }}
            className="space-y-3"
          >
            <div className="flex gap-2 overflow-x-auto no-scrollbar pb-1">
              {COLOR_TAGS.map((tag) => (
                <button
                  key={tag}
                  onClick={() => setSelectedTag(selectedTag === tag ? null : tag)}
                  aria-pressed={selectedTag === tag}
                  className={`flex-shrink-0 px-3 py-1 rounded-full text-[11px] transition-all ${
                    selectedTag === tag
                      ? 'text-white scale-105'
                      : 'bg-white/5 text-slate-400 border border-white/10'
                  }`}
                  style={selectedTag === tag ? { backgroundColor: TAG_COLORS[tag] } : {}}
                >
                  {TAG_NAMES[tag]}
                </button>
              ))}
            </div>

            <div className="liquid-glass-input flex items-center gap-2 px-4 py-3">
              <input
                ref={inputRef}
                value={text}
                onChange={(e) => setText(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleTextSubmit()}
                placeholder="闪过即留..."
                maxLength={140}
                aria-label="记录内容"
                className="flex-1 bg-transparent text-white text-[15px] placeholder-slate-500 outline-none"
              />
              <span
                className={`text-[10px] ${text.length > 130 ? 'text-red-400' : 'text-slate-500'}`}
                aria-live="polite"
              >
                {text.length}/140
              </span>
              <button
                onClick={handleTextSubmit}
                disabled={!text.trim()}
                aria-label="发送"
                className="w-8 h-8 rounded-full bg-[var(--color-primary)]/80 flex items-center justify-center disabled:opacity-30 active:scale-90 transition-transform"
              >
                <Send size={14} className="text-white" />
              </button>
              <button
                onClick={handleCancel}
                aria-label="取消"
                className="w-8 h-8 flex items-center justify-center"
              >
                <X size={16} className="text-slate-400" />
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
