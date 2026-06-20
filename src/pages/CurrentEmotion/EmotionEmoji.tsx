import { useMemo } from 'react';
import { motion } from 'framer-motion';
import { LEVEL_COLORS } from '@/lib/constants';
import type { EmotionLevel } from '@/lib/constants';
import { useReducedMotion } from '@/lib/motion';

interface EmotionEmojiProps {
  level: EmotionLevel;
  size?: number;
}

function getPaths(level: EmotionLevel) {
  switch (level) {
    case 3:
      return {
        eyes: (
          <>
            <path
              d="M35 50 Q42 42 49 50"
              stroke="white"
              strokeWidth="3"
              fill="none"
              strokeLinecap="round"
            />
            <path
              d="M71 50 Q78 42 85 50"
              stroke="white"
              strokeWidth="3"
              fill="none"
              strokeLinecap="round"
            />
          </>
        ),
        mouth: (
          <path
            d="M40 72 Q60 88 80 72"
            stroke="white"
            strokeWidth="3"
            fill="none"
            strokeLinecap="round"
          />
        ),
      };
    case 2:
      return {
        eyes: (
          <>
            <path
              d="M35 50 Q42 44 49 50"
              stroke="white"
              strokeWidth="3"
              fill="none"
              strokeLinecap="round"
            />
            <path
              d="M71 50 Q78 44 85 50"
              stroke="white"
              strokeWidth="3"
              fill="none"
              strokeLinecap="round"
            />
          </>
        ),
        mouth: (
          <path
            d="M42 74 Q60 84 78 74"
            stroke="white"
            strokeWidth="3"
            fill="none"
            strokeLinecap="round"
          />
        ),
      };
    case 1:
      return {
        eyes: (
          <>
            <path
              d="M36 50 Q42 45 48 50"
              stroke="white"
              strokeWidth="3"
              fill="none"
              strokeLinecap="round"
            />
            <path
              d="M72 50 Q78 45 84 50"
              stroke="white"
              strokeWidth="3"
              fill="none"
              strokeLinecap="round"
            />
          </>
        ),
        mouth: (
          <path
            d="M45 76 Q60 82 75 76"
            stroke="white"
            strokeWidth="3"
            fill="none"
            strokeLinecap="round"
          />
        ),
      };
    case 0:
      return {
        eyes: (
          <>
            <line
              x1="36"
              y1="50"
              x2="48"
              y2="50"
              stroke="white"
              strokeWidth="3"
              strokeLinecap="round"
            />
            <line
              x1="72"
              y1="50"
              x2="84"
              y2="50"
              stroke="white"
              strokeWidth="3"
              strokeLinecap="round"
            />
          </>
        ),
        mouth: (
          <line
            x1="45"
            y1="76"
            x2="75"
            y2="76"
            stroke="white"
            strokeWidth="3"
            strokeLinecap="round"
          />
        ),
      };
    case -1:
      return {
        eyes: (
          <>
            <line
              x1="36"
              y1="48"
              x2="48"
              y2="52"
              stroke="white"
              strokeWidth="3"
              strokeLinecap="round"
            />
            <line
              x1="48"
              y1="48"
              x2="36"
              y2="52"
              stroke="white"
              strokeWidth="3"
              strokeLinecap="round"
            />
            <line
              x1="72"
              y1="48"
              x2="84"
              y2="52"
              stroke="white"
              strokeWidth="3"
              strokeLinecap="round"
            />
            <line
              x1="84"
              y1="48"
              x2="72"
              y2="52"
              stroke="white"
              strokeWidth="3"
              strokeLinecap="round"
            />
          </>
        ),
        mouth: (
          <path
            d="M45 78 Q60 72 75 78"
            stroke="white"
            strokeWidth="3"
            fill="none"
            strokeLinecap="round"
          />
        ),
      };
    case -2:
      return {
        eyes: (
          <>
            <path
              d="M36 48 Q42 54 48 48"
              stroke="white"
              strokeWidth="3"
              fill="none"
              strokeLinecap="round"
            />
            <path
              d="M72 48 Q78 54 84 48"
              stroke="white"
              strokeWidth="3"
              fill="none"
              strokeLinecap="round"
            />
          </>
        ),
        mouth: (
          <path
            d="M45 80 Q60 70 75 80"
            stroke="white"
            strokeWidth="3"
            fill="none"
            strokeLinecap="round"
          />
        ),
      };
    case -3:
      return {
        eyes: (
          <>
            <path
              d="M38 50 L46 56 M46 50 L38 56"
              stroke="white"
              strokeWidth="3"
              strokeLinecap="round"
            />
            <path
              d="M74 50 L82 56 M82 50 L74 56"
              stroke="white"
              strokeWidth="3"
              strokeLinecap="round"
            />
          </>
        ),
        mouth: (
          <path
            d="M42 82 Q60 68 78 82"
            stroke="white"
            strokeWidth="3"
            fill="none"
            strokeLinecap="round"
          />
        ),
      };
  }
}

export default function EmotionEmoji({ level, size = 120 }: EmotionEmojiProps) {
  const reduced = useReducedMotion();
  const { eyes, mouth } = useMemo(() => getPaths(level), [level]);

  return (
    <motion.svg
      width={size}
      height={size}
      viewBox="0 0 120 120"
      initial={false}
      animate={reduced ? { scale: 1 } : { scale: [0.95, 1.05, 1] }}
      transition={reduced ? { duration: 0 } : { duration: 0.8, ease: 'easeOut' }}
    >
      <circle
        cx="60"
        cy="60"
        r="55"
        stroke={LEVEL_COLORS[level]}
        strokeWidth="2.5"
        fill="none"
        opacity="0.6"
      />
      {eyes}
      {mouth}
    </motion.svg>
  );
}
