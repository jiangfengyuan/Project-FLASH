import type { ColorTag, Category, EmotionLevel, SubEmotion } from '@/lib/constants';
import { getTodayStr } from '@/lib/utils';

export const DEMO_LOGS: {
  id: string;
  content: string;
  colorTag: ColorTag;
  category: Category;
  importance: number;
  createdAt: string;
  recordDate: string;
}[] = [
  {
    id: '1',
    content: '课堂上想到的关于AI辅助学习的创意点子，可以快速记下来了',
    colorTag: 'inspiration',
    category: 'log',
    importance: 0,
    createdAt: new Date(Date.now() - 3600000).toISOString(),
    recordDate: getTodayStr(),
  },
  {
    id: '2',
    content: '下午3点小组讨论，记得带笔记本',
    colorTag: 'urgent',
    category: 'log',
    importance: 0,
    createdAt: new Date(Date.now() - 7200000).toISOString(),
    recordDate: getTodayStr(),
  },
  {
    id: '3',
    content: '今天在图书馆看到一本关于认知科学的书，觉得很有意思',
    colorTag: 'idea',
    category: 'idea',
    importance: 2,
    createdAt: new Date(Date.now() - 86400000).toISOString(),
    recordDate: getTodayStr(new Date(Date.now() - 86400000)),
  },
  {
    id: '4',
    content: '晚上记得去超市买牛奶和面包',
    colorTag: 'daily',
    category: 'log',
    importance: 0,
    createdAt: new Date(Date.now() - 172800000).toISOString(),
    recordDate: getTodayStr(new Date(Date.now() - 172800000)),
  },
  {
    id: '5',
    content: '心理课的笔记：情绪ABC理论，A是诱发事件，B是信念，C是情绪结果',
    colorTag: 'memo',
    category: 'log',
    importance: 0,
    createdAt: new Date(Date.now() - 259200000).toISOString(),
    recordDate: getTodayStr(new Date(Date.now() - 259200000)),
  },
];

export const DEMO_EMOTIONS: {
  id: string;
  level: EmotionLevel;
  subEmotion: SubEmotion;
  status: string | null;
  note: string | null;
  recordDate: string;
  createdAt: string;
}[] = [
  {
    id: 'e1',
    level: 2,
    subEmotion: null,
    status: '学习中',
    note: '今天高效完成了论文大纲',
    recordDate: getTodayStr(),
    createdAt: new Date(Date.now() - 3600000).toISOString(),
  },
  {
    id: 'e2',
    level: -1,
    subEmotion: 'uncomfortable',
    status: '通勤',
    note: '地铁太挤了，有点烦躁',
    recordDate: getTodayStr(new Date(Date.now() - 86400000)),
    createdAt: new Date(Date.now() - 86400000).toISOString(),
  },
  {
    id: 'e3',
    level: 3,
    subEmotion: null,
    status: '聚会',
    note: '和老同学聚餐，超级开心！',
    recordDate: getTodayStr(new Date(Date.now() - 172800000)),
    createdAt: new Date(Date.now() - 172800000).toISOString(),
  },
  {
    id: 'e4',
    level: 0,
    subEmotion: null,
    status: '工作',
    note: '平淡的一天',
    recordDate: getTodayStr(new Date(Date.now() - 259200000)),
    createdAt: new Date(Date.now() - 259200000).toISOString(),
  },
  {
    id: 'e5',
    level: -2,
    subEmotion: 'sad',
    status: '深夜',
    note: '想起一些往事，有点难过',
    recordDate: getTodayStr(new Date(Date.now() - 345600000)),
    createdAt: new Date(Date.now() - 345600000).toISOString(),
  },
];
