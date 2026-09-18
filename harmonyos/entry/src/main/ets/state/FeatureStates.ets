import { Category, EmotionRecord, LogItem, SubEmotion, TaskItem } from '../models/Models';
import { LanDevice } from '../data/LocalBackupTransfer';
// 与 components/CommonBuilders.ets 的浅色令牌保持一致（CommonBuilders 反向依赖
// 本文件的类型，无法直接引用其常量，改动令牌时需同步）。
const LIGHT_BACKGROUND = '#FFF7F9FA';
const LIGHT_SURFACE = '#FFFFFFFF';
const LIGHT_TEXT = '#FF2D3436';
const LIGHT_MUTED = '#FF636E72';

@Observed
export class NavigationState {
  activeTab: number = 0;
  detail: string = '';
  isMediumWindow: boolean = false;
  isExpandedWindow: boolean = false;
  contentOpacity: number = 1;
  contentOffset: number = 0;
  fabExpanded: boolean = false;
  fabProgress: number = 0;
}

@Observed
export class ThemeState {
  themeMode: string = 'light';
  themeBackground: string = LIGHT_BACKGROUND;
  themeSurface: string = LIGHT_SURFACE;
  themeText: string = LIGHT_TEXT;
  themeMuted: string = LIGHT_MUTED;
  themeControl: string = '#FFEDF0F5';
  themeTint: string = '#FFEAF2FF';
  themeDanger: string = '#FFFFF1F0';
  themeNavigation: string = '#FFFFFFFF';
  themeGradientStart: string = '#FFF7F9FA';
  themeGradientMiddle: string = '#FFF7F9FA';
  themeGradientEnd: string = '#FFF7F9FA';
}

@Observed
export class HomeState {
  todayLogCount: number = 0;
  todayIdeaCount: number = 0;
  todayEmotionCount: number = 0;
  todayTaskCount: number = 0;
  todayTaskDoneCount: number = 0;
  recentLogs: LogItem[] = [];
}

@Observed
export class LogsState {
  logs: LogItem[] = [];
  searchResults: LogItem[] = [];
  quickText: string = '';
  searchText: string = '';
  quickCategory: string = '';
  editingLogId: string = '';
  editText: string = '';
  editCategory: string = '';
  editTag: string = '';
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
}

@Observed
export class EmotionState {
  emotions: EmotionRecord[] = [];
  emotionLevel: number = 0;
  emotionNote: string = '';
  selectedSubEmotion: string = SubEmotion.SAD;
  busy: boolean = false;
}

@Observed
export class CalendarState {
  tasks: TaskItem[] = [];
  editingTaskId: string = '';
  taskTitle: string = '';
  taskNotes: string = '';
  taskDate: string = '';
  taskTime: string = '09:00';
  taskTimeZone: string = '';
  taskAllDay: boolean = true;
  taskReminderMinutes: number = -1;
  calendarDayLimit: number = 30;
  activityDays: string[] = [];
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
}

@Observed
export class FeedbackState {
  notice?: ToastNotice;
  destructive?: DeleteRequest;
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
