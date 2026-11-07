import { dayString } from '../data/DateUtils';
import { Category, EmotionRecord, LogItem, SubEmotion, TaskItem } from '../models/Models';
import { LanDevice } from '../data/LocalBackupTransfer';
// 与 components/CommonBuilders.ets 的浅色令牌保持一致（CommonBuilders 反向依赖
// 本文件的类型，无法直接引用其常量，改动令牌时需同步）。
const LIGHT_BACKGROUND = '#FFFFF9ED';
const LIGHT_SURFACE = '#FFFFFDF6';
const LIGHT_TEXT = '#FF2E2A26';
const LIGHT_MUTED = '#FF5E5044';

export function normalizeThemeMode(mode: string): string {
  return mode === 'dark' || mode === 'system' ? mode : 'light';
}

export function resolveThemeDark(mode: string, systemDark: boolean): boolean {
  const normalized = normalizeThemeMode(mode);
  return normalized === 'dark' || (normalized === 'system' && systemDark);
}

@Observed
export class NavigationState {
  activeTab: number = 0;
  detail: string = '';
  isMediumWindow: boolean = false;
  isExpandedWindow: boolean = false;
  statusBarHeight: number = 0;
  navigationBarHeight: number = 0;
  foldable: boolean = false;
  foldStatus: number = 0;
  contentOpacity: number = 1;
  contentOffset: number = 0;
}

// display.FoldStatus 原值桥接：0 未知 / 1 展开 / 2 折叠 / 3 半折叠。
export const FOLD_STATUS_EXPANDED = 1;
export const FOLD_STATUS_HALF_FOLDED = 3;

// 宽屏布局裁决：半折叠强制单栏居中限宽；展开态折叠屏视同 840vp 双栏。
export function contentLayout(isExpandedWindow: boolean, foldable: boolean, foldStatus: number): string {
  if (foldable && foldStatus === FOLD_STATUS_HALF_FOLDED) return 'centered';
  if (isExpandedWindow || (foldable && foldStatus === FOLD_STATUS_EXPANDED)) return 'dual';
  return 'single';
}

@Observed
export class ThemeState {
  themeMode: string = 'light';
  systemDark: boolean = false;
  themeBackground: string = LIGHT_BACKGROUND;
  themeSurface: string = LIGHT_SURFACE;
  themeText: string = LIGHT_TEXT;
  themeMuted: string = LIGHT_MUTED;
  themeControl: string = '#FFF3EADA';
  themeTint: string = '#FFEADFCB';
  themeDanger: string = '#FFF3EADA';
  themeNavigation: string = '#FFFFFDF6';

  isDark(): boolean {
    return resolveThemeDark(this.themeMode, this.systemDark);
  }
}

@Observed
export class SystemEnvironment {
  systemDark: boolean = false;
  statusBarHeightPx: number = 0;
  navigationBarHeightPx: number = 0;
  foldable: boolean = false;
  foldStatus: number = 0;
}

export const systemEnvironment: SystemEnvironment = new SystemEnvironment();

@Observed
export class HomeState {
  todayLogCount: number = 0;
  todayIdeaCount: number = 0;
  todayEmotionCount: number = 0;
  todayTaskCount: number = 0;
  todayTaskDoneCount: number = 0;
  recentLogs: LogItem[] = [];
  // 未完成待办（全部，不限今日），与 iOS 今日一览同口径。
  openTaskCount: number = 0;
  // 今天最新一条情绪的等级；没有记录时为 undefined。
  latestEmotionLevel?: number = undefined;
  unviewedIdeaIds: string[] = [];
  // 未读灵感数（本地已读状态，不进备份）；提醒与角标按 IDEA_REMINDER_THRESHOLD 显示。
  unviewedIdeaCount: number = 0;
}

@Observed
export class LogsState {
  logs: LogItem[] = [];
  logsVersion: number = 0;
  searchResults: LogItem[] = [];
  quickText: string = '';
  searchText: string = '';
  quickCategory: string = '';
  editingLogId: string = '';
  editText: string = '';
  editCategory: string = '';
  editTag: string = '';
  editDate: string = '';
  editImportance: number = 0;
  editError: string = '';
  editDiscard: boolean = false;
  captureText: string = '';
  captureCategory: string = Category.LOG;
  // 记录页筛选：filterCategory 为 all/log/idea/inbox，filterDate 为 all/today/week/month，
  // filterImportance 为 -1 全部 / 0 无重要度 / 1 有重要度。关闭面板后状态保留。
  filterCategory: string = 'all';
  filterTag: string = '';
  filterDate: string = 'all';
  filterImportance: number = -1;
  sortAscending: boolean = false;
  logDisplayLimit: number = 50;
  busy: boolean = false;
  // 已收藏：可与类型筛选叠加（对齐 iOS）。
  favoritesOnly: boolean = false;
  // 待整理的批量选择。
  selecting: boolean = false;
  selectedIds: string[] = [];
  // 编辑器里的收藏开关。
  editFavorite: boolean = false;
  // 日志流（日志管理）筛选：多选标签、日期上下界、三种排序、已收藏。
  flowQuery: string = '';
  flowTags: string[] = [];
  flowStart: string = '';
  flowEnd: string = '';
  flowSort: string = 'newest';
  flowFavorites: boolean = false;
  // 系统分享的文字：由用户确认后才保存，不覆盖草稿。
  quickShared: boolean = false;
}

@Observed
export class EmotionState {
  emotions: EmotionRecord[] = [];
  emotionsVersion: number = 0;
  emotionLevel: number = 0;
  emotionNote: string = '';
  // 当前状态（具体心情）：快捷 chip 或自由文本，随情绪记录保存。
  emotionStatus: string = '';
  selectedSubEmotion: string = SubEmotion.SAD;
  // 可选强度 1–5；0 表示未选。再点同一档清除。
  emotionIntensity: number = 0;
  busy: boolean = false;
  // 保存成功动效信号：savedFlash 递增触发页面差异化反馈，savedLevel 记录情绪极性。
  savedFlash: number = 0;
  savedLevel: number = 0;
}

@Observed
export class CalendarState {
  displayedMonth: string = dayString().slice(0, 7) + '-01';
  selectedDay: string = dayString();
  tasks: TaskItem[] = [];
  editingTaskId: string = '';
  taskTitle: string = '';
  taskNotes: string = '';
  taskDate: string = '';
  taskTime: string = '09:00';
  taskTimeZone: string = '';
  taskAllDay: boolean = true;
  taskReminderMinutes: number = -1;
  // 灵感转任务：保留来源回链。
  taskSourceLogId: string = '';
  taskFavorite: boolean = false;
  calendarDayLimit: number = 30;
  activityDays: string[] = [];
  dataVersion: number = 0;
  logsByDay: Map<string, LogItem[]> = new Map<string, LogItem[]>();
  emotionsByDay: Map<string, EmotionRecord[]> = new Map<string, EmotionRecord[]>();
  tasksByDay: Map<string, TaskItem[]> = new Map<string, TaskItem[]>();
  busy: boolean = false;
}

export enum TransferPhase {
  IDLE = 'idle',
  SENDING = 'sending',
  RECEIVING = 'receiving',
  CONNECTING = 'connecting'
}

export enum ImportPhase {
  IDLE = 'idle',
  PREVIEW = 'preview',
  APPLYING = 'applying'
}

@Observed
export class BackupState {
  importPhase: ImportPhase = ImportPhase.IDLE;
  importSummary: string = '';
  lanMode: TransferPhase = TransferPhase.IDLE;
  lanPin: string = '';
  lanEnteredPin: string = '';
  lanDevices: LanDevice[] = [];
  selectedLanDevice: string = '';
  recoveryAvailable: boolean = false;
  busy: boolean = false;
  fileBusy: boolean = false;
}

@Observed
export class SettingsState {
  showWelcome: boolean = false;
  nearLinkSupported: boolean = false;
  floatingBallSupported: boolean = false;
  liveViewEnabled: boolean = false;
  agentFrameworkSupported: boolean = false;
  agentRuntimeSupported: boolean = false;
  fileSandboxShareSupported: boolean = false;
  notificationSettingsSupported: boolean = false;
  // 系统分享面板（ShareKit systemShare）能力探测；不可用时隐藏分享入口。
  systemShareSupported: boolean = false;
  // 减少动态效果：系统无公开查询接口，此为应用内设置（Preferences 持久化）。
  reduceMotion: boolean = false;
  // 灵感提醒（对齐 iOS）：开关与频率（daily / every3days / weekly）。
  ideaReminderEnabled: boolean = true;
  ideaReminderFrequency: string = 'daily';
}

// 减少动态效果的全局生效标记：由 AppController 随设置读写，
// components/DesignTokens 的 motionDuration 据此把动效时长归零。
let reduceMotionFlag: boolean = false;

export function setReduceMotionEnabled(enabled: boolean): void {
  reduceMotionFlag = enabled;
}

export function isReduceMotionEnabled(): boolean {
  return reduceMotionFlag;
}

export enum DeleteKind {
  LOG = 'log',
  EMOTION = 'emotion',
  TASK = 'task',
  ALL = 'all'
}

export interface DeleteRequest {
  kind: DeleteKind;
  id: string;
}

export interface ToastNotice {
  message: string;
  level: string;
  actionLabel?: string;
  action?: () => void;
}

// Toast 级别归一：success/error/info，未知值按 info 处理。
export function normalizeToastLevel(level: string): string {
  return level === 'success' || level === 'error' ? level : 'info';
}

@Observed
export class FeedbackState {
  notice?: ToastNotice;
  destructive?: DeleteRequest;
  // 启动加载三态：loading/ready/error；error 时 startupError 携带原因，全页错误+重试。
  startup: string = 'loading';
  startupError: string = '';
}

export class AppSession {
  readonly navigation: NavigationState = new NavigationState();
  readonly theme: ThemeState = new ThemeState();
  readonly home: HomeState = new HomeState();
  readonly logs: LogsState = new LogsState();
  readonly emotion: EmotionState = new EmotionState();
  readonly calendar: CalendarState = new CalendarState();
  readonly backup: BackupState = new BackupState();
  readonly settings: SettingsState = new SettingsState();
  readonly feedback: FeedbackState = new FeedbackState();
}
