import { useState, useRef, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Save, Frown, Angry, Meh } from 'lucide-react';
import { useEmotionStore } from '@/stores/emotionStore';
import { LEVEL_NAMES, LEVEL_COLORS, type EmotionLevel, type SubEmotion } from '@/lib/constants';
import { useToastStore } from '@/stores/toastStore';
import { useReducedMotion, fadeTransition } from '@/lib/motion';
import { haptic, HAPTIC_SUCCESS, HAPTIC_TAP } from '@/lib/haptics';
import { getTodayStr } from '@/lib/utils';
import EmotionEmoji from './EmotionEmoji';
import ConfettiEffect from './ConfettiEffect';
import HistoryList from './HistoryList';
import StatsPanel from './StatsPanel';

const LEVELS: EmotionLevel[] = [3, 2, 1, 0, -1, -2, -3];

const SUB_EMOTIONS: {
  key: SubEmotion;
  label: string;
  icon: React.ComponentType<{ size?: number; className?: string }>;
  color: string;
}[] = [
  { key: 'sad', label: '伤心', icon: Frown, color: '#A78BFA' },
  { key: 'angry', label: '生气', icon: Angry, color: '#F87171' },
  { key: 'uncomfortable', label: '难受', icon: Meh, color: '#FB923C' },
];

export default function CurrentEmotion() {
  const reduced = useReducedMotion();
  const currentLevel = useEmotionStore((state) => state.currentLevel);
  const currentSubEmotion = useEmotionStore((state) => state.currentSubEmotion);
  const addEmotion = useEmotionStore((state) => state.addEmotion);
  const setCurrentLevel = useEmotionStore((state) => state.setCurrentLevel);
  const setCurrentSubEmotion = useEmotionStore((state) => state.setCurrentSubEmotion);
  const showToast = useToastStore((state) => state.showToast);

  const sliderValue = currentLevel;
  const [showEdit, setShowEdit] = useState(false);
  const [status, setStatus] = useState('');
  const [note, setNote] = useState('');
  const [showConfetti, setShowConfetti] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const [activeTab, setActiveTab] = useState<'record' | 'stats'>('record');
  const sliderRef = useRef<HTMLDivElement>(null);

  const isNegative = sliderValue < 0;

  const handleSliderChange = useCallback(
    (clientX: number) => {
      if (!sliderRef.current) return;
      const rect = sliderRef.current.getBoundingClientRect();
      const padding = 20;
      const effectiveWidth = rect.width - padding * 2;
      const x = Math.max(0, Math.min(effectiveWidth, clientX - rect.left - padding));
      const pct = x / effectiveWidth;
      const idx = 6 - Math.round(pct * 6);
      const clampedIdx = Math.max(0, Math.min(6, idx));
      const newLevel = LEVELS[clampedIdx];
      if (newLevel !== currentLevel) {
        setCurrentLevel(newLevel);
        haptic(HAPTIC_TAP);
      }
    },
    [currentLevel, setCurrentLevel]
  );

  const handlePointerDown = (e: React.PointerEvent) => {
    setIsDragging(true);
    (e.target as HTMLElement).setPointerCapture(e.pointerId);
    handleSliderChange(e.clientX);
  };

  const handlePointerMove = (e: React.PointerEvent) => {
    if (!isDragging) return;
    handleSliderChange(e.clientX);
  };

  const handlePointerUp = () => {
    setIsDragging(false);
  };

  const handleSave = () => {
    addEmotion({
      level: sliderValue,
      subEmotion: currentSubEmotion,
      status: status || null,
      note: note || null,
      recordDate: getTodayStr(),
    })
      .then(() => {
        showToast('情绪已记录', 'success');
        haptic(HAPTIC_SUCCESS);
        setShowConfetti(true);
        setShowEdit(false);
        setStatus('');
        setNote('');
        setCurrentSubEmotion(null);
      })
      .catch(() => {
        showToast('保存失败，请重试', 'error');
      });
  };

  return (
    <div className="flex flex-col h-full relative">
      <div className="px-4 pt-3 pb-2">
        <h1 className="text-lg font-semibold text-white">此刻情绪</h1>
      </div>

      <div className="px-4 pb-2">
        <div className="flex p-1 rounded-xl bg-white/5">
          <button
            onClick={() => setActiveTab('record')}
            className={`flex-1 py-1.5 text-xs rounded-lg transition-colors ${activeTab === 'record' ? 'bg-white/15 text-white' : 'text-slate-400'}`}
          >
            记录
          </button>
          <button
            onClick={() => setActiveTab('stats')}
            className={`flex-1 py-1.5 text-xs rounded-lg transition-colors ${activeTab === 'stats' ? 'bg-white/15 text-white' : 'text-slate-400'}`}
          >
            统计
          </button>
        </div>
      </div>

      {activeTab === 'record' && (
        <>
          <div className="flex flex-col items-center justify-center py-6">
            <motion.div
              key={sliderValue}
              initial={{ scale: 0.8, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              transition={
                reduced
                  ? { duration: 0 }
                  : { type: 'spring', damping: 0.7, stiffness: 150, duration: 0.3 }
              }
            >
              <EmotionEmoji level={sliderValue} size={140} />
            </motion.div>
            <motion.p
              key={`label-${sliderValue}`}
              initial={{ opacity: 0, y: 5 }}
              animate={{ opacity: 1, y: 0 }}
              transition={fadeTransition(reduced)}
              className="mt-4 text-lg font-medium"
              style={{ color: LEVEL_COLORS[sliderValue] }}
            >
              {LEVEL_NAMES[sliderValue]}
            </motion.p>
          </div>

          {/* Draggable Slider */}
          <div className="px-6 py-4">
            <div
              ref={sliderRef}
              role="slider"
              aria-valuemin={-3}
              aria-valuemax={3}
              aria-valuenow={sliderValue}
              aria-label="情绪等级"
              className="relative h-12 rounded-full cursor-pointer select-none touch-none"
              style={{
                background:
                  'linear-gradient(to right, #800080, #B0C4DE, #B0E0E6, #90EE90, #FFB347)',
                boxShadow: 'inset 0 2px 8px rgba(0,0,0,0.3)',
              }}
              onPointerDown={handlePointerDown}
              onPointerMove={handlePointerMove}
              onPointerUp={handlePointerUp}
              onPointerCancel={handlePointerUp}
            >
              <div className="absolute inset-0 flex items-center justify-between px-5 pointer-events-none">
                {LEVELS.slice()
                  .reverse()
                  .map((l) => (
                    <div
                      key={l}
                      className={`w-1 h-3 rounded-full transition-opacity ${
                        l === sliderValue ? 'bg-white opacity-100' : 'bg-white/30'
                      }`}
                    />
                  ))}
              </div>

              <div
                className="absolute top-1/2 -mt-5 w-10 h-10 rounded-full flex items-center justify-center"
                style={{
                  left: `${((sliderValue + 3) / 6) * 100}%`,
                  transform: 'translateX(-50%)',
                  background: 'rgba(255,255,255,0.2)',
                  backdropFilter: 'blur(12px)',
                  border: '1px solid rgba(255,255,255,0.3)',
                  boxShadow: '0 4px 16px rgba(0,0,0,0.3), inset 0 1px 2px rgba(255,255,255,0.2)',
                  cursor: isDragging ? 'grabbing' : 'grab',
                  transition: reduced ? 'none' : 'left 0.2s ease-out',
                }}
              >
                <div
                  className="w-3 h-3 rounded-full"
                  style={{ backgroundColor: LEVEL_COLORS[sliderValue] }}
                />
              </div>
            </div>
          </div>

          <AnimatePresence>
            {isNegative && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                transition={fadeTransition(reduced)}
                className="overflow-hidden"
              >
                <div className="px-4 pb-3">
                  <div className="liquid-glass-sm p-2 flex gap-2 justify-center">
                    {SUB_EMOTIONS.map(({ key, label, icon: Icon, color }) => (
                      <button
                        key={key}
                        onClick={() => {
                          haptic(HAPTIC_TAP);
                          setCurrentSubEmotion(currentSubEmotion === key ? null : key);
                        }}
                        aria-pressed={currentSubEmotion === key}
                        className={`flex items-center gap-1.5 px-4 py-2 rounded-full text-xs transition-all ${
                          currentSubEmotion === key
                            ? 'text-white border'
                            : 'bg-white/5 text-slate-400 border border-transparent'
                        }`}
                        style={
                          currentSubEmotion === key
                            ? { backgroundColor: `${color}30`, borderColor: `${color}60`, color }
                            : {}
                        }
                      >
                        <Icon size={14} />
                        {label}
                      </button>
                    ))}
                  </div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          <div className="px-4 pb-2">
            <button
              onClick={() => {
                haptic(HAPTIC_TAP);
                setShowEdit(!showEdit);
              }}
              aria-expanded={showEdit}
              className="liquid-glass-pill w-full py-2.5 text-sm text-slate-300 active:scale-[0.98] transition-transform"
            >
              {showEdit ? '收起详情' : '添加详情'}
            </button>
          </div>

          <AnimatePresence>
            {showEdit && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                transition={fadeTransition(reduced)}
                className="overflow-hidden px-4 pb-3"
              >
                <div className="liquid-glass p-4 space-y-3">
                  <input
                    value={status}
                    onChange={(e) => setStatus(e.target.value)}
                    placeholder="具体心情/状态（如：工作中）"
                    maxLength={20}
                    aria-label="状态"
                    className="w-full bg-transparent text-sm text-white placeholder-slate-500 outline-none border-b border-white/10 pb-2"
                  />
                  <textarea
                    value={note}
                    onChange={(e) => setNote(e.target.value)}
                    placeholder="今天发生了什么..."
                    maxLength={200}
                    rows={3}
                    aria-label="备注"
                    className="w-full bg-transparent text-sm text-white placeholder-slate-500 outline-none resize-none leading-relaxed"
                  />
                  <div className="flex justify-between items-center">
                    <span className="text-[10px] text-slate-500" aria-live="polite">
                      {note.length}/200
                    </span>
                    <button
                      onClick={handleSave}
                      className="liquid-glass-pill px-6 py-2 text-sm text-white font-medium flex items-center gap-2 active:scale-95 transition-transform"
                      style={{ background: `${LEVEL_COLORS[sliderValue]}30` }}
                    >
                      <Save size={14} />
                      保存
                    </button>
                  </div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          {!showEdit && (
            <div className="px-4 pb-3">
              <button
                onClick={handleSave}
                className="w-full liquid-glass-pill py-3 text-white font-medium active:scale-[0.98] transition-transform flex items-center justify-center gap-2"
                style={{ background: `${LEVEL_COLORS[sliderValue]}25` }}
              >
                <Save size={16} />
                记录此刻
              </button>
            </div>
          )}

          <HistoryList />

          {showConfetti && (
            <ConfettiEffect
              color={LEVEL_COLORS[sliderValue]}
              onComplete={() => setShowConfetti(false)}
            />
          )}
        </>
      )}

      {activeTab === 'stats' && <StatsPanel />}
    </div>
  );
}
