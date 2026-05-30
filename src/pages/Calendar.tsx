import { useState, useMemo } from 'react';
import { motion } from 'framer-motion';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import { useLogStore, TAG_COLORS, type ColorTag } from '@/stores/logStore';
import { useEmotionStore, LEVEL_COLORS, type EmotionLevel } from '@/stores/emotionStore';
import LiquidGlassCard from '@/components/LiquidGlassCard';
import {
  format,
  startOfMonth,
  endOfMonth,
  startOfWeek,
  endOfWeek,
  addDays,
  isSameMonth,
  isToday,
  addMonths,
  subMonths,
} from 'date-fns';

const WEEKDAYS = ['Su', 'M', 'T', 'W', 'TH', 'F', 'Sa'];

export default function Calendar() {
  const [currentMonth, setCurrentMonth] = useState(new Date());
  const [selectedDate, setSelectedDate] = useState<string | null>(null);
  const { logs, getLogsByDate } = useLogStore();
  const { getEmotionsByDate } = useEmotionStore();

  const todayStr = new Date().toISOString().split('T')[0];

  // Generate calendar grid
  const calendarDays = useMemo(() => {
    const monthStart = startOfMonth(currentMonth);
    const monthEnd = endOfMonth(monthStart);
    const calendarStart = startOfWeek(monthStart);
    const calendarEnd = endOfWeek(monthEnd);

    const days: {
      date: Date;
      dateStr: string;
      isCurrentMonth: boolean;
      isToday: boolean;
      tagColor: string | null;
      emotionColors: string[];
      recordCount: number;
    }[] = [];

    let day = calendarStart;
    while (day <= calendarEnd) {
      const dateStr = format(day, 'yyyy-MM-dd');
      const dayLogs = getLogsByDate(dateStr);
      const dayEmotions = getEmotionsByDate(dateStr);

      // Get dominant tag color
      let tagColor: string | null = null;
      if (dayLogs.length > 0) {
        const tagCounts = new Map<string, number>();
        dayLogs.forEach((l) => {
          tagCounts.set(l.colorTag, (tagCounts.get(l.colorTag) || 0) + 1);
        });
        let maxTag: ColorTag = dayLogs[0].colorTag;
        let maxCount = 0;
        tagCounts.forEach((count, tag) => {
          if (count > maxCount) {
            maxCount = count;
            maxTag = tag as ColorTag;
          }
        });
        tagColor = TAG_COLORS[maxTag] || null;
      }

      // Get emotion colors for the day (unique colors, deduped)
      const emotionColors: string[] = [];
      if (dayEmotions.length > 0) {
        const seen = new Set<string>();
        dayEmotions.forEach((e) => {
          const c = LEVEL_COLORS[e.level as EmotionLevel];
          if (!seen.has(c)) {
            seen.add(c);
            emotionColors.push(c);
          }
        });
      }

      days.push({
        date: new Date(day),
        dateStr,
        isCurrentMonth: isSameMonth(day, monthStart),
        isToday: isToday(day),
        tagColor,
        emotionColors,
        recordCount: dayLogs.length,
      });

      day = addDays(day, 1);
    }

    return days;
  }, [currentMonth, logs]);

  const selectedDayLogs = selectedDate ? getLogsByDate(selectedDate) : [];

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="px-4 pt-3 pb-2">
        <div className="flex items-center justify-between">
          <h1 className="text-lg font-semibold text-white">
            {format(currentMonth, 'yyyy年 M月')}
          </h1>
          <div className="flex gap-1">
            <button
              onClick={() => setCurrentMonth(subMonths(currentMonth, 1))}
              className="w-8 h-8 flex items-center justify-center rounded-full bg-white/5 active:bg-white/10"
            >
              <ChevronLeft size={18} className="text-slate-300" />
            </button>
            <button
              onClick={() => setCurrentMonth(addMonths(currentMonth, 1))}
              className="w-8 h-8 flex items-center justify-center rounded-full bg-white/5 active:bg-white/10"
            >
              <ChevronRight size={18} className="text-slate-300" />
            </button>
          </div>
        </div>
      </div>

      {/* Calendar Grid */}
      <div className="px-4 pb-2">
        <div className="liquid-glass p-4">
          {/* Weekday headers */}
          <div className="grid grid-cols-7 gap-1 mb-2">
            {WEEKDAYS.map((d) => (
              <div key={d} className="text-center text-[10px] text-slate-500 font-medium py-1">
                {d}
              </div>
            ))}
          </div>

          {/* Days */}
          <div className="grid grid-cols-7 gap-1">
            {calendarDays.map((day, i) => (
              <motion.button
                key={day.dateStr}
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: i * 0.01 }}
                onClick={() =>
                  setSelectedDate(selectedDate === day.dateStr ? null : day.dateStr)
                }
                className={`relative flex flex-col items-center justify-center py-2 rounded-xl transition-all ${
                  day.isCurrentMonth ? '' : 'opacity-30'
                } ${selectedDate === day.dateStr ? 'bg-white/10' : 'active:bg-white/5'}`}
              >
                {/* Date number */}
                <span
                  className={`text-sm font-medium ${
                    day.isToday
                      ? 'w-7 h-7 rounded-full bg-blue-500 flex items-center justify-center text-white'
                      : day.isCurrentMonth
                      ? 'text-white'
                      : 'text-slate-600'
                  }`}
                >
                  {format(day.date, 'd')}
                </span>

                {/* Tag color dot */}
                {day.tagColor && (
                  <div
                    className="w-1.5 h-1.5 rounded-full mt-0.5"
                    style={{
                      backgroundColor: day.tagColor,
                      boxShadow: `0 0 4px ${day.tagColor}80`,
                    }}
                  />
                )}

                {/* Emotion color bar - pieced stripe showing all emotions */}
                {day.emotionColors.length > 0 && (
                  <div className="w-5 h-[3px] rounded-full mt-0.5 overflow-hidden flex">
                    {day.emotionColors.map((c, ci) => (
                      <div
                        key={ci}
                        className="flex-1 h-full"
                        style={{ backgroundColor: c }}
                      />
                    ))}
                  </div>
                )}

                {/* Record count badge */}
                {day.recordCount > 1 && (
                  <span className="absolute top-0.5 right-0.5 text-[8px] text-slate-500">
                    {day.recordCount}
                  </span>
                )}
              </motion.button>
            ))}
          </div>
        </div>
      </div>

      {/* Selected day records */}
      {selectedDate && selectedDayLogs.length > 0 && (
        <div className="px-4 pb-2">
          <h3 className="text-xs text-slate-400 mb-2">
            {format(new Date(selectedDate), 'M月d日')} 的记录
          </h3>
          <div className="space-y-2 max-h-40 overflow-y-auto no-scrollbar">
            {selectedDayLogs.map((log, i) => (
              <LiquidGlassCard key={log.id} colorTag={TAG_COLORS[log.colorTag]} index={i}>
                <div className="py-2 pr-4">
                  <p className="text-[13px] text-white line-clamp-2">{log.content}</p>
                </div>
              </LiquidGlassCard>
            ))}
          </div>
        </div>
      )}

      {/* Today's Records */}
      <div className="flex-1 overflow-y-auto no-scrollbar px-4 pb-4 pt-2">
        <h3 className="text-xs text-slate-400 mb-2 sticky top-0">今日记录</h3>
        {(() => {
          const todayLogs = getLogsByDate(todayStr);
          return todayLogs.length > 0 ? (
            <div className="space-y-3">
              {todayLogs.map((log, i) => (
                <LiquidGlassCard
                  key={log.id}
                  colorTag={TAG_COLORS[log.colorTag]}
                  index={i}
                >
                  <div className="py-3 pr-4">
                    <p className="text-[14px] text-white">{log.content}</p>
                    <span className="text-[10px] text-slate-500 mt-1 block">
                      {format(new Date(log.createdAt), 'HH:mm')}
                    </span>
                  </div>
                </LiquidGlassCard>
              ))}
            </div>
          ) : (
            <p className="text-sm text-slate-600 text-center py-8">今天还没有记录</p>
          );
        })()}
      </div>

      {/* Legend Bar */}
      <div className="px-4 pb-2">
        <div className="liquid-glass-sm flex items-center justify-around py-2.5">
          <div className="flex items-center gap-1.5">
            <div className="w-4 h-[3px] rounded-full overflow-hidden flex">
              <div className="flex-1 h-full bg-[#FFB347]" />
              <div className="flex-1 h-full bg-[#90EE90]" />
              <div className="flex-1 h-full bg-[#B0E0E6]" />
              <div className="flex-1 h-full bg-[#B0C4DE]" />
              <div className="flex-1 h-full bg-[#800080]" />
            </div>
            <span className="text-[10px] text-slate-400">情绪</span>
          </div>
          <div className="flex items-center gap-1.5">
            <div className="w-2 h-2 rounded-full bg-blue-400" />
            <span className="text-[10px] text-slate-400">Tag</span>
          </div>
          <div className="flex items-center gap-1.5">
            <div className="w-2 h-2 rounded-full bg-slate-500" />
            <span className="text-[10px] text-slate-400">日历</span>
          </div>
        </div>
      </div>
    </div>
  );
}
