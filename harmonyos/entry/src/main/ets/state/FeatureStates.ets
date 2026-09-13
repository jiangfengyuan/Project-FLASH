import { EmotionRecord, LogItem, SubEmotion, TaskItem } from '../models/Models';
import { LanDevice } from '../data/LocalBackupTransfer';
const LIGHT_BACKGROUND = '#00FFFFFF';
const LIGHT_SURFACE = '#EFFFFFFF';
const LIGHT_TEXT = '#172033';
const LIGHT_MUTED = '#667085';

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
  themeControl: string = '#EEF1F6';
  themeTint: string = '#EAF2FF';
  themeDanger: string = '#FFF1F0';
  themeNavigation: string = '#F8FFFFFF';
  themeGradientStart: string = '#FFF4F0FF';
  themeGradientMiddle: string = '#FFF1F8FF';
  themeGradientEnd: string = '#FFFFF3EC';
}

@Observed
export class HomeState {
  todayLogCount: number = 0;
  todayIdeaCount: number = 0;
  todayEmotionCount: number = 0;
  recentLogs: LogItem[] = [];
  latestEmoji: string = '—';
}

@Observed
export class LogsState {
  logs: LogItem[] = [];
  searchResults: LogItem[] = [];
  quickText: string = '';
  ideaText: string = '';
  searchText: string = '';
  quickCategory: string = '';
  editingLogId: string = '';
  editText: string = '';
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
