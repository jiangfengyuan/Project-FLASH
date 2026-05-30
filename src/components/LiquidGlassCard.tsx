import { type ReactNode } from 'react';
import { motion } from 'framer-motion';
import { cn } from '@/lib/utils';

interface LiquidGlassCardProps {
  children: ReactNode;
  className?: string;
  colorTag?: string;
  onClick?: () => void;
  index?: number;
}

export default function LiquidGlassCard({
  children,
  className,
  colorTag,
  onClick,
  index = 0,
}: LiquidGlassCardProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 8, scale: 0.97 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      transition={{ duration: 0.35, delay: index * 0.05, ease: 'easeOut' }}
      onClick={onClick}
      className={cn(
        'liquid-glass relative overflow-hidden',
        onClick && 'active:scale-[0.98] transition-transform',
        className
      )}
    >
      {colorTag && (
        <div
          className="absolute left-0 top-4 bottom-4 w-[3px] rounded-full"
          style={{ backgroundColor: colorTag }}
        />
      )}
      <div className={colorTag ? 'pl-3' : ''}>{children}</div>
    </motion.div>
  );
}
