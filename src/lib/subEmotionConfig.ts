import { Frown, Angry, Meh } from 'lucide-react';
import type { SubEmotion } from '@/lib/constants';

export interface SubEmotionConfigItem {
  label: string;
  color: string;
  icon: React.ComponentType<{ size?: number; className?: string }>;
}

export const SUB_EMOTION_CONFIG: Record<NonNullable<SubEmotion>, SubEmotionConfigItem> = {
  sad: { label: '伤心', color: '#A78BFA', icon: Frown },
  angry: { label: '生气', color: '#F87171', icon: Angry },
  uncomfortable: { label: '难受', color: '#FB923C', icon: Meh },
};
