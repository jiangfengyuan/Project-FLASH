import type { LogItem } from '@/stores/logStore';

// ===================== Color Tags (Logs / Ideas) =====================

export type ColorTag = 'urgent' | 'inspiration' | 'daily' | 'memo' | 'emotion' | 'idea';

export const COLOR_TAGS: ColorTag[] = ['urgent', 'inspiration', 'daily', 'memo', 'emotion', 'idea'];

export const TAG_COLORS: Record<ColorTag, string> = {
  urgent: '#FF6B6B',
  inspiration: '#FFD93D',
  daily: '#4D96FF',
  memo: '#6BCB77',
  emotion: '#9B59B6',
  idea: '#FF9F43',
};

export const TAG_NAMES: Record<ColorTag, string> = {
  urgent: '紧急',
  inspiration: '灵感',
  daily: '日常',
  memo: '备忘',
  emotion: '情绪',
  idea: '想法',
};

// ===================== Categories =====================

export type Category = 'log' | 'idea';

export interface CategoryLabel {
  text: string;
  bg: string;
  color: string;
}

export const CATEGORY_LABELS: Record<Category, CategoryLabel> = {
  log: { text: 'LOG', bg: 'rgba(77,150,255,0.15)', color: '#4D96FF' },
  idea: { text: 'IDEA', bg: 'rgba(255,159,67,0.15)', color: '#FF9F43' },
};

export function getCategoryLabel(category: Category): CategoryLabel {
  return CATEGORY_LABELS[category];
}

// ===================== Importance =====================

export const IMPORTANCE_MARKS = ['', '', '!!', '!!!', '!!!!'] as const;

export const IMPORTANCE_COLORS = ['', '', '#FF9F43', '#FF6B6B', '#DC2626'] as const;

export function getImportanceFromContent(content: string): number {
  if (content.includes('!!!!')) return 4;
  if (content.includes('!!!')) return 3;
  if (content.includes('!!')) return 2;
  return 0;
}

export function getImportanceDisplay(importance: number): {
  mark: string;
  color: string;
} {
  const mark = IMPORTANCE_MARKS[importance] ?? '';
  return {
    mark,
    color: mark ? (IMPORTANCE_COLORS[importance] ?? '#FF9F43') : '',
  };
}

// ===================== Emotion Levels =====================

export type EmotionLevel = 3 | 2 | 1 | 0 | -1 | -2 | -3;
export type SubEmotion = 'sad' | 'angry' | 'uncomfortable' | null;

export const LEVEL_NAMES: Record<EmotionLevel, string> = {
  3: '非常开心',
  2: '很开心',
  1: '开心',
  0: '中性',
  '-1': '不开心',
  '-2': '很不开心',
  '-3': '非常不开心',
};

export const LEVEL_COLORS: Record<EmotionLevel, string> = {
  3: '#FFB347',
  2: '#F0D878',
  1: '#90EE90',
  0: '#B0E0E6',
  '-1': '#B0C4DE',
  '-2': '#DDA0DD',
  '-3': '#800080',
};

// ===================== Time =====================

export const MS_PER_HOUR = 60 * 60 * 1000;
export const MS_PER_DAY = 24 * MS_PER_HOUR;

// ===================== Detail Drawer =====================

export type DetailVariant = 'log' | 'idea';

export type DetailDrawerLog = LogItem;
