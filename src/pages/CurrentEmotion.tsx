import { useState, useRef, useEffect, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Trash2, Heart, Flame, Cloud, Save } from 'lucide-react';
import { useEmotionStore, LEVEL_NAMES, LEVEL_COLORS, type EmotionLevel, type SubEmotion } from '@/stores/emotionStore';
import LiquidGlassCard from '@/components/LiquidGlassCard';
import { format } from 'date-fns';

const LEVELS: EmotionLevel[] = [3, 2, 1, 0, -1, -2, -3];

const SUB_EMOTIONS: { key: SubEmotion; label: string; icon: React.ComponentType<{ size?: number; className?: string }> }[] = [
  { key: 'sad', label: '伤心', icon: Heart },
  { key: 'angry', label: '生气', icon: Flame },
  { key: 'uncomfortable', label: '难受', icon: Cloud },
];

interface Particle {
  id: number;
  x: number;
  color: string;
  delay: number;
  size: number;
}

function ConfettiEffect({ color, onComplete }: { color: string; onComplete: () => void }) {
  const [particles] = useState<Particle[]>(() =>
    Array.from({ length: 30 }, (_, i) => ({
      id: i,
      x: Math.random() * 100,
      color,
      delay: Math.random() * 0.3,
      size: 4 + Math.random() * 8,
    }))
  );

  useEffect(() => {
    const timer = setTimeout(onComplete, 1500);
    return () => clearTimeout(timer);
  }, [onComplete]);

  return (
    <div className="fixed inset-0 z-[100] pointer-events-none overflow-hidden">
      {particles.map((p) => (
        <motion.div
          key={p.id}
          initial={{ x: `${p.x}vw`, y: '100vh', opacity: 1, scale: 1, rotate: 0 }}
          animate={{ y: '-20vh', opacity: 0, scale: 0.3, rotate: 720 }}
          transition={{ duration: 1.2, delay: p.delay, ease: 'easeOut' }}
          className="absolute rounded-full"
          style={{
            width: p.size,
            height: p.size,
            backgroundColor: p.color,
            boxShadow: `0 0 ${p.size}px ${String(p.color)}80`,
          }}
        />
      ))}
    </div>
  );
}

function EmotionEmoji({ level, size = 120 }: { level: EmotionLevel; size?: number }) {
  const getPaths = () => {
    switch (level) {
      case 3:
        return {
          eyes: <><path d="M35 50 Q42 42 49 50" stroke="white" strokeWidth="3" fill="none" strokeLinecap="round" /><path d="M71 50 Q78 42 85 50" stroke="white" strokeWidth="3" fill="none" strokeLinecap="round" /></>,
          mouth: <path d="M40 72 Q60 88 80 72" stroke="white" strokeWidth="3" fill="none" strokeLinecap="round" />,
        };
      case 2:
        return {
          eyes: <><path d="M35 50 Q42 44 49 50" stroke="white" strokeWidth="3" fill="none" strokeLinecap="round" /><path d="M71 50 Q78 44 85 50" stroke="white" strokeWidth="3" fill="none" strokeLinecap="round" /></>,
          mouth: <path d="M42 74 Q60 84 78 74" stroke="white" strokeWidth="3" fill="none" strokeLinecap="round" />,
        };
      case 1:
        return {
          eyes: <><path d="M36 50 Q42 45 48 50" stroke="white" strokeWidth="3" fill="none" strokeLinecap="round" /><path d="M72 50 Q78 45 84 50" stroke="white" strokeWidth="3" fill="none" strokeLinecap="round" /></>,
          mouth: <path d="M45 76 Q60 82 75 76" stroke="white" strokeWidth="3" fill="none" strokeLinecap="round" />,
        };
      case 0:
        return {
          eyes: <><line x1="36" y1="50" x2="48" y2="50" stroke="white" strokeWidth="3" strokeLinecap="round" /><line x1="72" y1="50" x2="84" y2="50" stroke="white" strokeWidth="3" strokeLinecap="round" /></>,
          mouth: <line x1="45" y1="76" x2="75" y2="76" stroke="white" strokeWidth="3" strokeLinecap="round" />,
        };
      case -1:
        return {
          eyes: <><line x1="36" y1="48" x2="48" y2="52" stroke="white" strokeWidth="3" strokeLinecap="round" /><line x1="48" y1="48" x2="36" y2="52" stroke="white" strokeWidth="3" strokeLinecap="round" /><line x1="72" y1="48" x2="84" y2="52" stroke="white" strokeWidth="3" strokeLinecap="round" /><line x1="84" y1="48" x2="72" y2="52" stroke="white" strokeWidth="3" strokeLinecap="round" /></>,
          mouth: <path d="M45 78 Q60 72 75 78" stroke="white" strokeWidth="3" fill="none" strokeLinecap="round" />,
        };
      case -2:
        return {
          eyes: <><path d="M36 48 Q42 54 48 48" stroke="white" strokeWidth="3" fill="none" strokeLinecap="round" /><path d="M72 48 Q78 54 84 48" stroke="white" strokeWidth="3" fill="none" strokeLinecap="round" /></>,
          mouth: <path d="M45 80 Q60 70 75 80" stroke="white" strokeWidth="3" fill="none" strokeLinecap="round" />,
        };
      case -3:
        return {
          eyes: <><path d="M38 50 L46 56 M46 50 L38 56" stroke="white" strokeWidth="3" strokeLinecap="round" /><path d="M74 50 L82 56 M82 50 L74 56" stroke="white" strokeWidth="3" strokeLinecap="round" /></>,
          mouth: <path d="M42 82 Q60 68 78 82" stroke="white" strokeWidth="3" fill="none" strokeLinecap="round" />,
        };
    }
  };

  const { eyes, mouth } = getPaths();

  return (
    <motion.svg
      width={size}
      height={size}
      viewBox="0 0 120 120"
      initial={false}
      animate={{ scale: [0.95, 1.05, 1] }}
      transition={{ duration: 0.8, ease: 'easeOut' }}
    >
      <circle cx="60" cy="60" r="55" stroke={LEVEL_COLORS[level]} strokeWidth="2.5" fill="none" opacity="0.6" />
      {eyes}
      {mouth}
    </motion.svg>
  );
}

export default function CurrentEmotion() {
  const { emotions, currentSubEmotion, addEmotion, deleteEmotion, setCurrentLevel, setCurrentSubEmotion } = useEmotionStore();
  const [sliderValue, setSliderValue] = useState<number>(1);
  const [showEdit, setShowEdit] = useState(false);
  const [status, setStatus] = useState('');
  const [note, setNote] = useState('');
  const [showConfetti, setShowConfetti] = useState(false);
  const sliderRef = useRef<HTMLDivElement>(null);
  const isDragging = useRef(false);

  const isNegative = sliderValue < 0;

  const handleSliderChange = useCallback(
    (clientX: number) => {
      if (!sliderRef.current) return;
      const rect = sliderRef.current.getBoundingClientRect();
      const padding = 20;
      const effectiveWidth = rect.width - padding * 2;
      const x = Math.max(0, Math.min(effectiveWidth, clientX - rect.left - padding));
      const pct = x / effectiveWidth;
      const idx = Math.round(pct * 6);
      const clampedIdx = Math.max(0, Math.min(6, idx));
      const newLevel = LEVELS[clampedIdx];
      if (newLevel !== sliderValue) {
        setSliderValue(newLevel);
        setCurrentLevel(newLevel);
        if (typeof navigator !== 'undefined' && navigator.vibrate) {
          navigator.vibrate(10);
        }
      }
    },
    [sliderValue, setCurrentLevel]
  );

  const handlePointerDown = (e: React.PointerEvent) => {
    isDragging.current = true;
    (e.target as HTMLElement).setPointerCapture(e.pointerId);
    handleSliderChange(e.clientX);
  };

  const handlePointerMove = (e: React.PointerEvent) => {
    if (!isDragging.current) return;
    handleSliderChange(e.clientX);
  };

  const handlePointerUp = () => {
    isDragging.current = false;
  };

  const handleSave = () => {
    addEmotion({
      level: sliderValue as EmotionLevel,
      subEmotion: currentSubEmotion,
      status: status || null,
      note: note || null,
      recordDate: new Date().toISOString().split('T')[0],
    });
    setShowConfetti(true);
    setShowEdit(false);
    setStatus('');
    setNote('');
  };

  return (
    <div className="flex flex-col h-full relative">
      <div className="px-4 pt-3 pb-2">
        <h1 className="text-lg font-semibold text-white">此刻情绪</h1>
      </div>

      <div className="flex flex-col items-center justify-center py-6">
        <motion.div
          key={sliderValue}
          initial={{ scale: 0.8, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ type: 'spring', damping: 0.7, stiffness: 150, duration: 0.3 }}
        >
          <EmotionEmoji level={sliderValue as EmotionLevel} size={140} />
        </motion.div>
        <motion.p
          key={`label-${sliderValue}`}
          initial={{ opacity: 0, y: 5 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-4 text-lg font-medium"
          style={{ color: LEVEL_COLORS[sliderValue as EmotionLevel] }}
        >
          {LEVEL_NAMES[sliderValue as EmotionLevel]}
        </motion.p>
      </div>

      {/* Draggable Slider */}
      <div className="px-6 py-4">
        <div
          ref={sliderRef}
          className="relative h-12 rounded-full cursor-pointer select-none touch-none"
          style={{
            background: 'linear-gradient(to right, #90EE90, #B0E0E6, #FFB347, #FFB347)',
            boxShadow: 'inset 0 2px 8px rgba(0,0,0,0.3)',
          }}
          onPointerDown={handlePointerDown}
          onPointerMove={handlePointerMove}
          onPointerUp={handlePointerUp}
          onPointerCancel={handlePointerUp}
        >
          {/* Track tick marks */}
          <div className="absolute inset-0 flex items-center justify-between px-5 pointer-events-none">
            {LEVELS.map((l) => (
              <div
                key={l}
                className={`w-1 h-3 rounded-full transition-opacity ${
                  l === sliderValue ? 'bg-white opacity-100' : 'bg-white/30'
                }`}
              />
            ))}
          </div>

          {/* Draggable Thumb */}
          <motion.div
            className="absolute top-1/2 w-10 h-10 rounded-full flex items-center justify-center"
            style={{
              left: `${((sliderValue + 3) / 6) * 100}%`,
              x: '-50%',
              y: '-50%',
              background: 'rgba(255,255,255,0.2)',
              backdropFilter: 'blur(12px)',
              border: '1px solid rgba(255,255,255,0.3)',
              boxShadow: '0 4px 16px rgba(0,0,0,0.3), inset 0 1px 2px rgba(255,255,255,0.2)',
              cursor: isDragging.current ? 'grabbing' : 'grab',
            }}
            transition={{ type: 'spring', stiffness: 400, damping: 35 }}
          >
            <div
              className="w-3 h-3 rounded-full"
              style={{ backgroundColor: LEVEL_COLORS[sliderValue as EmotionLevel] }}
            />
          </motion.div>
        </div>
      </div>

      <AnimatePresence>
        {isNegative && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            className="overflow-hidden"
          >
            <div className="px-4 pb-3">
              <div className="liquid-glass-sm p-2 flex gap-2 justify-center">
                {SUB_EMOTIONS.map(({ key, label, icon: Icon }) => (
                  <button
                    key={key}
                    onClick={() => setCurrentSubEmotion(currentSubEmotion === key ? null : key)}
                    className={`flex items-center gap-1.5 px-4 py-2 rounded-full text-xs transition-all ${
                      currentSubEmotion === key
                        ? 'bg-purple-500/30 text-purple-200 border border-purple-400/30'
                        : 'bg-white/5 text-slate-400 border border-transparent'
                    }`}
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
          onClick={() => setShowEdit(!showEdit)}
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
            className="overflow-hidden px-4 pb-3"
          >
            <div className="liquid-glass p-4 space-y-3">
              <input
                value={status}
                onChange={(e) => setStatus(e.target.value)}
                placeholder="具体心情/状态（如：工作中）"
                maxLength={20}
                className="w-full bg-transparent text-sm text-white placeholder-slate-500 outline-none border-b border-white/10 pb-2"
              />
              <textarea
                value={note}
                onChange={(e) => setNote(e.target.value)}
                placeholder="今天发生了什么..."
                maxLength={200}
                rows={3}
                className="w-full bg-transparent text-sm text-white placeholder-slate-500 outline-none resize-none leading-relaxed"
              />
              <div className="flex justify-between items-center">
                <span className="text-[10px] text-slate-500">{note.length}/200</span>
                <button
                  onClick={handleSave}
                  className="liquid-glass-pill px-6 py-2 text-sm text-white font-medium flex items-center gap-2 active:scale-95 transition-transform"
                  style={{ background: `${LEVEL_COLORS[sliderValue as EmotionLevel]}30` }}
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
            style={{ background: `${LEVEL_COLORS[sliderValue as EmotionLevel]}25` }}
          >
            <Save size={16} />
            记录此刻
          </button>
        </div>
      )}

      <div className="flex-1 overflow-y-auto no-scrollbar px-4 pb-4">
        <h3 className="text-xs text-slate-400 mb-2 sticky top-0 backdrop-blur-sm py-1">
          历史记录
        </h3>
        <div className="space-y-2">
          {emotions.map((record, i) => (
            <LiquidGlassCard key={record.id} index={i} className="!rounded-2xl">
              <div className="p-3 flex items-center gap-3">
                <div className="flex-shrink-0">
                  <EmotionEmoji level={record.level} size={40} />
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-medium" style={{ color: LEVEL_COLORS[record.level] }}>
                      {LEVEL_NAMES[record.level]}
                    </span>
                    {record.subEmotion && (
                      <span className="text-[10px] px-2 py-0.5 rounded-full bg-purple-500/20 text-purple-300">
                        {record.subEmotion === 'sad' ? '伤心' : record.subEmotion === 'angry' ? '生气' : '难受'}
                      </span>
                    )}
                  </div>
                  {record.status && <p className="text-xs text-slate-400 mt-0.5">{record.status}</p>}
                  {record.note && <p className="text-xs text-slate-500 mt-0.5 line-clamp-2">{record.note}</p>}
                  <span className="text-[10px] text-slate-600 mt-1 block font-mono">
                    {format(new Date(record.createdAt), 'MM/dd HH:mm')}
                  </span>
                </div>
                <button
                  onClick={() => deleteEmotion(record.id)}
                  className="flex-shrink-0 w-8 h-8 flex items-center justify-center rounded-full active:bg-red-500/20 transition-colors"
                >
                  <Trash2 size={14} className="text-slate-500" />
                </button>
              </div>
            </LiquidGlassCard>
          ))}
        </div>
      </div>

      {showConfetti && (
        <ConfettiEffect
          color={LEVEL_COLORS[sliderValue as EmotionLevel]}
          onComplete={() => setShowConfetti(false)}
        />
      )}
    </div>
  );
}
