import { FileText, Lightbulb, CalendarDays, Smile } from 'lucide-react';
import { motion } from 'framer-motion';
import { useNavigationStore, type Tab, TAB_PAGES } from '@/stores/navigationStore';
import { useReducedMotion } from '@/lib/motion';
import { haptic, HAPTIC_TAP } from '@/lib/haptics';

const tabConfig: Record<
  Tab,
  { icon: React.ComponentType<{ size?: number; className?: string }>; label: string }
> = {
  log: { icon: FileText, label: 'Log' },
  idea: { icon: Lightbulb, label: 'Idea' },
  calendar: { icon: CalendarDays, label: '日历' },
  emotion: { icon: Smile, label: '情绪' },
};

const tabs = TAB_PAGES.map((key) => ({ key, ...tabConfig[key] }));

export default function BottomNav() {
  const reduced = useReducedMotion();
  const activeTab = useNavigationStore((state) => state.activeTab);
  const setActiveTab = useNavigationStore((state) => state.setActiveTab);

  return (
    <nav className="liquid-glass-nav fixed bottom-0 left-0 right-0 z-50 flex items-center justify-around h-16 pb-2">
      {tabs.map(({ key, icon: Icon, label }) => {
        const isActive = activeTab === key;
        return (
          <button
            key={key}
            onClick={() => {
              haptic(HAPTIC_TAP);
              setActiveTab(key);
            }}
            aria-label={label}
            aria-current={isActive ? 'page' : undefined}
            className="relative flex flex-col items-center justify-center w-16 h-14 gap-0.5"
          >
            {isActive && (
              <motion.div
                layoutId="activeTab"
                className="absolute inset-x-2 inset-y-0 rounded-2xl bg-white/10"
                transition={
                  reduced ? { duration: 0 } : { type: 'spring', stiffness: 300, damping: 30 }
                }
              />
            )}
            <div className="relative z-10">
              <Icon
                size={22}
                className={`transition-colors duration-200 ${
                  isActive ? 'text-white' : 'text-slate-400'
                }`}
              />
            </div>
            <span
              className={`relative z-10 text-[10px] transition-colors duration-200 ${
                isActive ? 'text-white font-medium' : 'text-slate-500'
              }`}
            >
              {label}
            </span>
          </button>
        );
      })}
    </nav>
  );
}
