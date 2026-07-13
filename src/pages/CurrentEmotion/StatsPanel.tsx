import { useMemo, useState } from 'react';
import { motion } from 'framer-motion';
import { subDays, parseISO } from 'date-fns';
import {
  ResponsiveContainer,
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
  BarChart,
  Bar,
} from 'recharts';
import { useEmotionStore } from '@/stores/emotionStore';
import { getDailyAverages, getSubEmotionDistribution } from '@/lib/emotionStats';
import { LEVEL_COLORS } from '@/lib/constants';

const DAYS_OPTIONS = [
  { label: '近 7 天', value: 7 },
  { label: '近 30 天', value: 30 },
];

export default function StatsPanel() {
  const emotions = useEmotionStore((s) => s.emotions);
  const [days, setDays] = useState(7);

  const averages = useMemo(() => getDailyAverages(emotions, days), [emotions, days]);
  const distribution = useMemo(() => getSubEmotionDistribution(emotions, days), [emotions, days]);

  const hasData = useMemo(() => {
    const end = new Date();
    const start = subDays(end, days - 1);
    return emotions.some((e) => {
      const d = parseISO(e.recordDate);
      return d >= start && d <= end;
    });
  }, [emotions, days]);

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.3 }}
      className="flex-1 overflow-y-auto no-scrollbar px-4 pb-4 space-y-5"
    >
      <div className="flex gap-2">
        {DAYS_OPTIONS.map((opt) => (
          <button
            key={opt.value}
            onClick={() => setDays(opt.value)}
            className={`px-4 py-1.5 rounded-full text-xs transition-colors ${
              days === opt.value ? 'bg-white/20 text-white' : 'bg-white/5 text-slate-400'
            }`}
          >
            {opt.label}
          </button>
        ))}
      </div>

      {!hasData ? (
        <div className="py-16 text-center text-slate-500 text-sm">最近 {days} 天还没有情绪记录</div>
      ) : (
        <>
          <section>
            <h3 className="text-sm font-medium text-white mb-3">情绪等级趋势</h3>
            <div className="h-56 liquid-glass-sm rounded-2xl p-3">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={averages}>
                  <CartesianGrid stroke="rgba(255,255,255,0.05)" />
                  <XAxis
                    dataKey="date"
                    tick={{ fill: '#94A3B8', fontSize: 10 }}
                    tickFormatter={(d: string) => d.slice(5)}
                  />
                  <YAxis domain={[-3, 3]} tick={{ fill: '#94A3B8', fontSize: 10 }} />
                  <Tooltip
                    contentStyle={{
                      backgroundColor: 'rgba(15, 23, 42, 0.9)',
                      border: 'none',
                      borderRadius: 8,
                    }}
                    labelStyle={{ color: '#94A3B8' }}
                  />
                  <Line
                    type="monotone"
                    dataKey="average"
                    stroke={LEVEL_COLORS[1]}
                    strokeWidth={2}
                    dot={{ r: 3, fill: LEVEL_COLORS[1] }}
                    animationDuration={500}
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </section>

          {distribution.length > 0 && (
            <section>
              <h3 className="text-sm font-medium text-white mb-3">子情绪分布</h3>
              <div className="h-40 liquid-glass-sm rounded-2xl p-3">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={distribution} layout="vertical">
                    <CartesianGrid stroke="rgba(255,255,255,0.05)" horizontal={false} />
                    <XAxis type="number" tick={{ fill: '#94A3B8', fontSize: 10 }} />
                    <YAxis
                      dataKey="name"
                      type="category"
                      tick={{ fill: '#CBD5E1', fontSize: 11 }}
                      width={50}
                    />
                    <Tooltip
                      contentStyle={{
                        backgroundColor: 'rgba(15, 23, 42, 0.9)',
                        border: 'none',
                        borderRadius: 8,
                      }}
                    />
                    <Bar
                      dataKey="count"
                      fill="#A78BFA"
                      radius={[0, 4, 4, 0]}
                      animationDuration={400}
                    />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </section>
          )}
        </>
      )}
    </motion.div>
  );
}
