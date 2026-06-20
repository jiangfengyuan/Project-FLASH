import { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { useReducedMotion } from '@/lib/motion';

interface Particle {
  id: number;
  x: number;
  color: string;
  delay: number;
  size: number;
}

interface ConfettiEffectProps {
  color: string;
  onComplete: () => void;
}

export default function ConfettiEffect({ color, onComplete }: ConfettiEffectProps) {
  const reduced = useReducedMotion();
  const [particles] = useState<Particle[]>(() =>
    Array.from({ length: reduced ? 0 : 30 }, (_, i) => ({
      id: i,
      x: Math.random() * 100,
      color,
      delay: Math.random() * 0.3,
      size: 4 + Math.random() * 8,
    }))
  );

  useEffect(() => {
    const timer = setTimeout(onComplete, reduced ? 1 : 1500);
    return () => clearTimeout(timer);
  }, [onComplete, reduced]);

  if (reduced) return null;

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
