import { common } from '@kit.AbilityKit';
import { mediaquery } from '@kit.ArkUI';
import { BackupDiff } from '../data/BackupDiff';
import { BackupFiles } from '../data/BackupFiles';
import { BackupImport, BackupService } from '../data/BackupService';
import { FlashStore } from '../data/FlashStore';
import { HarmonyCapabilities, HarmonyCapabilitySnapshot } from '../data/HarmonyCapabilities';
import {
  LanDevice,
  LocalBackupDiscovery,
  LocalBackupReceiver,
  LocalBackupSender
} from '../data/LocalBackupTransfer';
import { dayOffset, dayString, monthTitle, shortDay } from '../data/DateUtils';
import {
  Category,
  ColorTag,
  colorTagColor,
  colorTagName,
  EmotionRecord,
  emotionEmoji,
  emotionName,
  LogItem,
  SubEmotion,
  subEmotionName
} from '../models/Models';

const BRAND = '#6C5CE7';
const BACKGROUND = '#00FFFFFF';
const SURFACE = '#EFFFFFFF';
const TEXT = '#172033';
const MUTED = '#667085';

@Entry
@Component
struct Index {
  @State private activeTab: number = 0;
  @State private detail: string = '';
  @State private logs: LogItem[] = [];
  @State private searchResults: LogItem[] = [];
  @State private emotions: EmotionRecord[] = [];
  @State private todayLogCount: number = 0;
  @State private todayIdeaCount: number = 0;
  @State private todayEmotionCount: number = 0;
  @State private quickText: string = '';
  @State private ideaText: string = '';
  @State private emotionLevel: number = 0;
  @State private emotionNote: string = '';
  @State private selectedSubEmotion: string = SubEmotion.SAD;
  @State private searchText: string = '';
  @State private showWelcome: boolean = false;
  @State private toast: string = '';
  @State private importSummary: string = '';
  @State private lanMode: string = '';
  @State private lanPin: string = '';
  @State private lanEnteredPin: string = '';
  @State private lanDevices: LanDevice[] = [];
  @State private selectedLanDevice: string = '';
  @State private isMediumWindow: boolean = false;
  @State private isExpandedWindow: boolean = false;
  @State private contentOpacity: number = 1;
  @State private contentOffset: number = 0;
  @State private nearLinkSupported: boolean = false;
  @State private floatingBallSupported: boolean = false;
  @State private liveViewEnabled: boolean = false;
  @State private fabExpanded: boolean = false;
  @State private quickCategory: string = '';
  @State private pendingDeleteLogId: string = '';
  @State private pendingDeleteEmotionId: string = '';
  @State private showClearConfirm: boolean = false;
  @State private editingLogId: string = '';
  @State private editText: string = '';
  @State private logDisplayLimit: number = 50;
  @State private calendarDayLimit: number = 30;
  @State private operationBusy: boolean = false;
  @State private fabProgress: number = 0;
  private pendingImport?: BackupImport;
  private lanSender?: LocalBackupSender;
  private lanDiscovery?: LocalBackupDiscovery;
  private mediumQuery?: mediaquery.MediaQueryListener;
  private expandedQuery?: mediaquery.MediaQueryListener;
  private navigationToken: number = 0;
  private fabToken: number = 0;
  private dateTimer: number = 0;
  private searchTimer: number = 0;
  private observedDay: string = '';
  private activityDays: string[] = [];
  private logsByDay: Map<string, LogItem[]> = new Map<string, LogItem[]>();
  private emotionsByDay: Map<string, EmotionRecord[]> = new Map<string, EmotionRecord[]>();

  aboutToAppear(): void {
    const query = this.getUIContext().getMediaQuery();
    this.mediumQuery = query.matchMediaSync('(min-width: 600vp)');
    this.expandedQuery = query.matchMediaSync('(min-width: 840vp)');
    this.isMediumWindow = this.mediumQuery.matches;
    this.isExpandedWindow = this.expandedQuery.matches;
    this.mediumQuery.on('change', (result: mediaquery.MediaQueryResult) => {
      this.isMediumWindow = result.matches;
    });
    this.expandedQuery.on('change', (result: mediaquery.MediaQueryResult) => {
      this.isExpandedWindow = result.matches;
    });
    this.observedDay = dayString();
    this.dateTimer = setInterval(() => {
      const current = dayString();
      if (current !== this.observedDay) {
        this.observedDay = current;
        this.refresh();
      }
    }, 60000);
    this.prepare();
  }

  aboutToDisappear(): void {
    this.stopLan();
    this.mediumQuery?.off('change');
    this.expandedQuery?.off('change');
    clearInterval(this.dateTimer);
    clearTimeout(this.searchTimer);
  }

  private async prepare(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await FlashStore.instance.initialize(context);
      this.showWelcome = !FlashStore.instance.welcomed;
      this.refresh();
      if (FlashStore.instance.recoveryWarning) this.notify(FlashStore.instance.recoveryWarning);
      const capability: HarmonyCapabilitySnapshot = await HarmonyCapabilities.inspect();
      this.nearLinkSupported = capability.nearLinkSupported;
      this.floatingBallSupported = capability.floatingBallSupported;
      this.liveViewEnabled = capability.liveViewEnabled;
    } catch (error) {
      this.notify(`本地数据加载失败：${this.errorMessage(error as Error)}`);
    }
  }

  private switchTab(index: number): void {
    if (index === this.activeTab && this.detail === '') return;
    const token = ++this.navigationToken;
    this.fabToken++;
    this.fabExpanded = false;
    this.fabProgress = 0;
    this.getUIContext().animateTo({ duration: 110, curve: Curve.EaseIn }, () => {
      this.contentOpacity = 0;
      this.contentOffset = -8;
    });
    setTimeout(() => {
      if (token !== this.navigationToken) return;
      this.activeTab = index;
      this.detail = '';
      this.contentOffset = 12;
      this.getUIContext().animateTo({ duration: 230, curve: Curve.EaseOut }, () => {
        this.contentOpacity = 1;
        this.contentOffset = 0;
      });
    }, 110);
  }

  private openDetail(destination: string): void {
    const token = ++this.navigationToken;
    this.fabToken++;
    this.fabExpanded = false;
    this.fabProgress = 0;
    this.getUIContext().animateTo({ duration: 120, curve: Curve.EaseIn }, () => {
      this.contentOpacity = 0;
      this.contentOffset = -12;
    });
    setTimeout(() => {
      if (token !== this.navigationToken) return;
      this.detail = destination;
      this.contentOffset = 18;
      this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
        this.contentOpacity = 1;
        this.contentOffset = 0;
      });
    }, 120);
  }

  private closeDetail(): void {
    const token = ++this.navigationToken;
    this.getUIContext().animateTo({ duration: 110, curve: Curve.EaseIn }, () => {
      this.contentOpacity = 0;
      this.contentOffset = 14;
    });
    setTimeout(() => {
      if (token !== this.navigationToken) return;
      this.detail = '';
      this.contentOffset = -10;
      this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.contentOpacity = 1;
        this.contentOffset = 0;
      });
    }, 110);
  }

  private toggleFab(): void {
    const token = ++this.fabToken;
    if (!this.fabExpanded) {
      this.fabExpanded = true;
      this.fabProgress = 0;
      this.getUIContext().animateTo({ duration: 210, curve: Curve.EaseOut }, () => this.fabProgress = 1);
    } else {
      this.getUIContext().animateTo({ duration: 160, curve: Curve.EaseIn }, () => this.fabProgress = 0);
      setTimeout(() => {
        if (token === this.fabToken) this.fabExpanded = false;
      }, 160);
    }
  }

  private dismissFab(): void {
    if (!this.fabExpanded) return;
    this.toggleFab();
  }

  private refresh(): void {
    this.logs = FlashStore.instance.logs.slice();
    this.emotions = FlashStore.instance.emotions.slice();
    this.rebuildCalendarIndex();
    this.updateSearchResults();
    const today = dayString();
    this.todayLogCount = this.logs.filter((item: LogItem) =>
      item.recordDate === today && item.category === Category.LOG).length;
    this.todayIdeaCount = this.logs.filter((item: LogItem) =>
      item.recordDate === today && item.category === Category.IDEA).length;
    this.todayEmotionCount = this.emotions.filter((item: EmotionRecord) => item.recordDate === today).length;
  }

  private notify(message: string): void {
    this.toast = message;
    setTimeout(() => {
      if (this.toast === message) this.toast = '';
    }, 2200);
  }

  private async saveQuickCategory(): Promise<void> {
    if (!this.quickText.trim() || this.quickCategory === '' || this.operationBusy) return;
    this.operationBusy = true;
    try {
      const isIdea = this.quickCategory === Category.IDEA;
      await FlashStore.instance.addLog(this.quickText, isIdea ? Category.IDEA : Category.LOG,
        isIdea ? ColorTag.IDEA : ColorTag.DAILY);
      this.quickText = '';
      this.quickCategory = '';
      this.refresh();
      this.notify(isIdea ? '灵感已保存' : '日志已记录');
    } catch (error) {
      this.notify(this.errorMessage(error as Error));
    } finally {
      this.operationBusy = false;
    }
  }

  private greeting(): string {
    const hour = new Date().getHours();
    if (hour >= 5 && hour <= 10) return '早上好';
    if (hour <= 12) return '中午好';
    if (hour <= 17) return '下午好';
    if (hour <= 22) return '晚上好';
    return '夜深了';
  }

  private async saveIdea(): Promise<void> {
    if (!this.ideaText.trim() || this.operationBusy) return;
    this.operationBusy = true;
    try {
      await FlashStore.instance.addLog(this.ideaText, Category.IDEA, ColorTag.IDEA);
      this.ideaText = '';
      this.refresh();
      this.notify('灵感已保存');
    } catch (error) {
      this.notify(this.errorMessage(error as Error));
    } finally {
      this.operationBusy = false;
    }
  }

  private async saveEmotion(): Promise<void> {
    if (this.operationBusy) return;
    this.operationBusy = true;
    try {
      await FlashStore.instance.addEmotion(this.emotionLevel,
        this.emotionLevel < 0 ? this.selectedSubEmotion : undefined, this.emotionNote);
      this.emotionNote = '';
      this.refresh();
      this.notify('情绪已记录');
    } catch (error) {
      this.notify(this.errorMessage(error as Error));
    } finally {
      this.operationBusy = false;
    }
  }

  private async removeLog(id: string): Promise<void> {
    await FlashStore.instance.deleteLog(id);
    this.refresh();
  }

  private async removeEmotion(id: string): Promise<void> {
    await FlashStore.instance.deleteEmotion(id);
    this.refresh();
  }

  private startEditLog(item: LogItem): void {
    this.editingLogId = item.id;
    this.editText = item.content;
  }

  private async saveEditedLog(): Promise<void> {
    if (!this.editingLogId || !this.editText.trim() || this.operationBusy) return;
    this.operationBusy = true;
    try {
      await FlashStore.instance.updateLog(this.editingLogId, this.editText.slice(0, 10000));
      this.editingLogId = '';
      this.editText = '';
      this.refresh();
      this.notify('记录已更新');
    } catch (error) {
      this.notify(this.errorMessage(error as Error));
    } finally {
      this.operationBusy = false;
    }
  }

  private async confirmDestructiveAction(): Promise<void> {
    try {
      if (this.pendingDeleteLogId) {
        const id = this.pendingDeleteLogId;
        this.pendingDeleteLogId = '';
        await this.removeLog(id);
        this.notify('记录已删除');
      } else if (this.pendingDeleteEmotionId) {
        const id = this.pendingDeleteEmotionId;
        this.pendingDeleteEmotionId = '';
        await this.removeEmotion(id);
        this.notify('情绪记录已删除');
      } else if (this.showClearConfirm) {
        this.showClearConfirm = false;
        await FlashStore.instance.clearAll();
        this.refresh();
        this.notify('本地数据已清空');
      }
    } catch (error) {
      this.notify(this.errorMessage(error as Error));
    }
  }

  private async finishWelcome(): Promise<void> {
    await FlashStore.instance.setWelcomed();
    this.showWelcome = false;
  }

  private errorMessage(error: Error): string {
    return error.message || '操作失败';
  }

  private async exportBackup(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const json = BackupService.exportJSON(this.logs, this.emotions, 'Flash Aero HarmonyOS');
      await BackupFiles.exportJSON(context, json);
      this.notify('备份已导出');
    } catch (error) {
      this.notify(this.errorMessage(error as Error));
    }
  }

  private async chooseBackup(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const incoming = BackupService.parse(await BackupFiles.importJSON(context));
      this.stageImport(incoming);
    } catch (error) {
      this.pendingImport = undefined;
      this.importSummary = '';
      this.notify(this.errorMessage(error as Error));
    }
  }

  private stageImport(incoming: BackupImport): void {
    const difference = BackupDiff.analyze(this.logs, this.emotions, incoming.logs, incoming.emotions);
    this.pendingImport = incoming;
    this.importSummary = `日志：新增 ${difference.logs.added}、变更 ${difference.logs.changed}、本机独有 ${difference.logs.localOnly}\n` +
      `情绪：新增 ${difference.emotions.added}、变更 ${difference.emotions.changed}、本机独有 ${difference.emotions.localOnly}\n` +
      `无效项目：${incoming.skippedLogs + incoming.skippedEmotions}`;
  }

  private async startLanSend(): Promise<void> {
    this.stopLan();
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const json = BackupService.exportJSON(this.logs, this.emotions, 'Flash Aero LAN transfer');
      const sender = new LocalBackupSender(context, json, (success: boolean) => {
        // An older session may finish while a new one is starting; never clear the new session's state.
        if (this.lanSender !== sender) return;
        this.lanMode = '';
        this.lanPin = '';
        this.lanSender = undefined;
        this.notify(success ? '备份已发送' : '配对已结束');
      });
      this.lanSender = sender;
      this.lanMode = 'sending';
      this.lanPin = sender.pin;
      await sender.start();
    } catch (error) {
      this.stopLan();
      this.notify(this.errorMessage(error as Error));
    }
  }

  private startLanReceive(): void {
    this.stopLan();
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.lanMode = 'receiving';
    this.lanDiscovery = new LocalBackupDiscovery(context, (devices: LanDevice[]) => {
      this.lanDevices = devices.slice();
      if (this.selectedLanDevice !== '' && !devices.some((device: LanDevice) => device.id === this.selectedLanDevice)) {
        this.selectedLanDevice = '';
      }
    });
    try {
      this.lanDiscovery.start();
    } catch (error) {
      this.stopLan();
      this.notify(this.errorMessage(error as Error));
    }
  }

  private async receiveLan(): Promise<void> {
    const device = this.lanDevices.find((item: LanDevice) => item.id === this.selectedLanDevice);
    if (!device) { this.notify('请先选择发送设备'); return; }
    if (!/^\d{4}$/.test(this.lanEnteredPin)) { this.notify('请输入四位数字 PIN'); return; }
    this.lanMode = 'connecting';
    try {
      const incoming = BackupService.parse(await LocalBackupReceiver.receive(device, this.lanEnteredPin));
      this.stopLan();
      this.stageImport(incoming);
      this.notify('备份已接收，请选择合并或覆盖');
    } catch (error) {
      this.lanMode = 'receiving';
      this.notify(this.errorMessage(error as Error));
    }
  }

  private stopLan(): void {
    if (this.lanSender) this.lanSender.stop(false);
    if (this.lanDiscovery) this.lanDiscovery.stop();
    this.lanSender = undefined;
    this.lanDiscovery = undefined;
    this.lanMode = '';
    this.lanPin = '';
    this.lanEnteredPin = '';
    this.lanDevices = [];
    this.selectedLanDevice = '';
  }

  private async applyBackup(merge: boolean): Promise<void> {
    if (!this.pendingImport || this.operationBusy) return;
    this.operationBusy = true;
    try {
      if (merge) {
        await FlashStore.instance.mergeAll(this.pendingImport.logs, this.pendingImport.emotions);
      } else {
        await FlashStore.instance.replaceAll(this.pendingImport.logs, this.pendingImport.emotions);
      }
      this.pendingImport = undefined;
      this.importSummary = '';
      this.refresh();
      this.notify(merge ? '备份已合并' : '本地数据已覆盖');
    } catch (error) {
      this.notify(this.errorMessage(error as Error));
    } finally {
      this.operationBusy = false;
    }
  }

  @Builder
  private header(title: string, subtitle: string) {
    Column({ space: 3 }) {
      Text(title).fontSize(28).fontWeight(FontWeight.Bold).fontColor(TEXT).width('100%')
      Text(subtitle).fontSize(13).fontColor(MUTED).width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 20, right: 20, top: 18, bottom: 12 })
  }

  @Builder
  private tabButton(index: number, emoji: string, label: string) {
    Column({ space: 2 }) {
      Text(emoji).fontSize(20)
      Text(label).fontSize(11).fontColor(this.activeTab === index ? BRAND : MUTED)
    }
    .layoutWeight(1)
    .height(56)
    .justifyContent(FlexAlign.Center)
    .onClick(() => this.switchTab(index))
  }

  @Builder
  private logRow(item: LogItem) {
    Row({ space: 10 }) {
      Column().width(5).height(44).borderRadius(3).backgroundColor(colorTagColor(item.colorTag))
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(item.category === Category.IDEA ? '灵感' : colorTagName(item.colorTag))
            .fontSize(11).fontColor(colorTagColor(item.colorTag))
          if (item.importance > 0) {
            Text(`重要度 ${item.importance}`).fontSize(10).fontColor('#D97706')
          }
        }.width('100%')
        Text(item.content).fontSize(15).fontColor(TEXT).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${shortDay(item.recordDate)} · ${item.createdAt.slice(11, 16)}`).fontSize(11).fontColor(MUTED)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column({ space: 5 }) {
        Button('编辑', { type: ButtonType.Normal })
          .fontSize(11).fontColor(BRAND).backgroundColor('#F0EBFF').height(28)
          .onClick(() => this.startEditLog(item))
        Button('删除', { type: ButtonType.Normal })
          .fontSize(11).fontColor('#B42318').backgroundColor('#FFF1F0').height(28)
          .onClick(() => this.pendingDeleteLogId = item.id)
      }
    }.width('100%').padding({ top: 10, bottom: 10 })
  }

  @Builder
  private homePage() {
    Scroll() {
      Column({ space: 14 }) {
        this.header(`${this.greeting()} 👋`, '今天也记录一点什么吧。')
        Column({ space: 12 }) {
          if (this.isMediumWindow) {
            Row({ space: 10 }) {
              this.moduleCard('📖', '日志', this.todayLogCount, '#8B5CF6', '#F0EBFF', 'explore')
              this.moduleCard('💡', '想法', this.todayIdeaCount, '#F5B800', '#FFF7D6', 'explore')
              this.moduleCard('📅', '日程', -1, '#22B573', '#E2F7EC', 'calendar')
              this.moduleCard('♥', '情绪', this.todayEmotionCount, '#FF6B9D', '#FFE8F0', 'emotion')
            }.width('100%')
          } else {
            Column({ space: 10 }) {
              Row({ space: 10 }) {
                this.moduleCard('📖', '日志', this.todayLogCount, '#8B5CF6', '#F0EBFF', 'explore')
                this.moduleCard('💡', '想法', this.todayIdeaCount, '#F5B800', '#FFF7D6', 'explore')
              }.width('100%')
              Row({ space: 10 }) {
                this.moduleCard('📅', '日程', -1, '#22B573', '#E2F7EC', 'calendar')
                this.moduleCard('♥', '情绪', this.todayEmotionCount, '#FF6B9D', '#FFE8F0', 'emotion')
              }.width('100%')
            }.width('100%')
          }

          Column({ space: 10 }) {
            Text('今日概览').fontSize(16).fontWeight(FontWeight.Medium).fontColor(TEXT).width('100%')
            Row() {
              this.overviewItem(`${this.todayLogCount}`, '日志')
              this.overviewItem(`${this.todayIdeaCount}`, '想法')
              this.overviewItem(`${this.todayEmotionCount}`, '情绪')
              this.overviewItem(this.latestEmotionEmoji(), '当前')
            }.width('100%')
          }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(20)

          if (this.logs.length > 0) {
            Column() {
              Text('最近动态').fontSize(17).fontWeight(FontWeight.Medium).fontColor(TEXT).width('100%').margin({ bottom: 5 })
              ForEach(this.logs.slice(0, 5), (item: LogItem) => this.logRow(item), (item: LogItem) => item.id)
            }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(20)
          } else {
            this.emptyState('⚡', '第一条记录，正在等你')
          }
        }.padding({ left: 16, right: 16, bottom: 90 }).width('100%')
      }.width('100%')
    }.width('100%').height('100%').backgroundColor(BACKGROUND)
  }

  private latestEmotionEmoji(): string {
    return this.emotions.length === 0 ? '—' : emotionEmoji(this.emotions[0].level);
  }

  @Builder
  private moduleCard(icon: string, title: string, count: number, color: string, background: string, destination: string) {
    Column({ space: 8 }) {
      Row() {
        Text(icon).fontSize(23)
        Blank()
        if (count >= 0) Text(`${count}`).fontSize(18).fontWeight(FontWeight.Bold).fontColor(color)
      }.width('100%')
      Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(TEXT).width('100%')
      Text(count >= 0 ? '今日新增' : '查看').fontSize(11).fontColor(MUTED).width('100%')
    }
    .layoutWeight(1)
    .height(112)
    .padding(14)
    .backgroundColor(background)
    .borderRadius(20)
    .onClick(() => {
      if (destination === 'explore') this.switchTab(1);
      else this.openDetail(destination);
    })
    .animation({ duration: 180, curve: Curve.EaseOut })
  }

  @Builder
  private overviewItem(value: string, label: string) {
    Column({ space: 3 }) {
      Text(value).fontSize(18).fontWeight(FontWeight.Bold).fontColor(TEXT)
      Text(label).fontSize(11).fontColor(MUTED)
    }.layoutWeight(1)
  }

  @Builder
  private metric(value: string, label: string, background: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(28).fontWeight(FontWeight.Bold).fontColor(TEXT)
      Text(label).fontSize(12).fontColor(MUTED)
    }.layoutWeight(1).height(88).justifyContent(FlexAlign.Center).backgroundColor(background).borderRadius(18)
  }

  @Builder
  private emptyState(emoji: string, text: string) {
    Column({ space: 8 }) {
      Text(emoji).fontSize(34)
      Text(text).fontSize(14).fontColor(MUTED)
    }.width('100%').height(130).justifyContent(FlexAlign.Center).backgroundColor(SURFACE).borderRadius(20)
  }

  @Builder
  private explorePage() {
    Scroll() {
      Column({ space: 14 }) {
        this.header('探索', '日志与灵感汇聚成你的个人信息流')
        Column({ space: 10 }) {
          TextArea({ placeholder: '记录一个新灵感…', text: this.ideaText })
            .height(76).maxLength(10000).backgroundColor('#FFF8E7').borderRadius(14)
            .onChange((value: string) => this.ideaText = value.slice(0, 10000))
          Button('保存灵感').width('100%').height(42).backgroundColor('#FF9F43').onClick(() => this.saveIdea())
        }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(20)

        TextInput({ placeholder: '搜索日志与灵感', text: this.searchText })
          .height(44).backgroundColor(SURFACE).borderRadius(14)
          .onChange((value: string) => {
            this.searchText = value;
            this.logDisplayLimit = 50;
            this.scheduleSearch();
          })

        Column() {
          ForEach(this.displayedLogs(), (item: LogItem) => this.logRow(item), (item: LogItem) => item.id)
          if (this.filteredLogCount() === 0) {
            this.emptyState('🔎', '没有找到匹配的内容')
          }
          if (this.hasMoreLogs()) {
            Button(`加载更多（剩余 ${this.filteredLogCount() - this.displayedLogs().length} 条）`)
              .width('100%').height(40).fontColor(BRAND).backgroundColor('#F0EBFF')
              .onClick(() => this.logDisplayLimit += 50)
          }
        }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(20)
      }.width('100%').padding({ left: 16, right: 16, bottom: 90 })
    }.width('100%').height('100%').backgroundColor(BACKGROUND)
  }

  private filteredLogs(): LogItem[] {
    return this.searchResults;
  }

  private updateSearchResults(): void {
    const query = this.searchText.trim().toLowerCase();
    this.searchResults = !query ? this.logs.slice() : this.logs.filter((item: LogItem) =>
      item.content.toLowerCase().includes(query) || colorTagName(item.colorTag).includes(query));
  }

  private scheduleSearch(): void {
    clearTimeout(this.searchTimer);
    this.searchTimer = setTimeout(() => this.updateSearchResults(), 160);
  }

  private displayedLogs(): LogItem[] {
    return this.filteredLogs().slice(0, this.logDisplayLimit);
  }

  private filteredLogCount(): number {
    return this.filteredLogs().length;
  }

  private hasMoreLogs(): boolean {
    return this.filteredLogCount() > this.logDisplayLimit;
  }

  @Builder
  private statsPage() {
    Scroll() {
      Column({ space: 14 }) {
        this.header('统计', '看见记录背后的节奏与情绪')
        Row({ space: 10 }) {
          this.metric(`${this.logs.length}`, '全部记录', '#EAF2FF')
          this.metric(`${this.averageEmotion()}`, '平均情绪', '#F4EAFE')
        }.width('100%')
        Column({ space: 12 }) {
          Text('近 7 天情绪').fontSize(17).fontWeight(FontWeight.Medium).fontColor(TEXT).width('100%')
          ForEach(this.lastSevenDays(), (day: string) => {
            Row({ space: 10 }) {
              Text(shortDay(day)).fontSize(12).fontColor(MUTED).width(58)
              Stack({ alignContent: Alignment.Start }) {
                Row().height(10).width('100%').backgroundColor('#EEF1F6').borderRadius(5)
                Row().height(10).width(`${this.dayBar(day)}%`).backgroundColor(BRAND).borderRadius(5)
              }.layoutWeight(1).height(12)
              Text(this.dayEmotionLabel(day)).fontSize(12).fontColor(TEXT).width(34)
            }.width('100%')
          }, (day: string) => day)
        }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(20)

        Column({ space: 10 }) {
          Text('记录构成').fontSize(17).fontWeight(FontWeight.Medium).fontColor(TEXT).width('100%')
          this.statLine('日志', this.logs.filter((item: LogItem) => item.category === Category.LOG).length, '#4D96FF')
          this.statLine('灵感', this.logs.filter((item: LogItem) => item.category === Category.IDEA).length, '#FF9F43')
          this.statLine('情绪', this.emotions.length, '#9B59B6')
        }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(20)
      }.width('100%').padding({ left: 16, right: 16, bottom: 90 })
    }.width('100%').height('100%').backgroundColor(BACKGROUND)
  }

  private averageEmotion(): string {
    if (this.emotions.length === 0) return '—';
    const total = this.emotions.reduce((sum: number, item: EmotionRecord) => sum + item.level, 0);
    return (total / this.emotions.length).toFixed(1);
  }

  private lastSevenDays(): string[] {
    const days: string[] = [];
    for (let index = -6; index <= 0; index++) days.push(dayOffset(index));
    return days;
  }

  private dayAverage(day: string): number | undefined {
    const matches = this.emotions.filter((item: EmotionRecord) => item.recordDate === day);
    if (matches.length === 0) return undefined;
    return matches.reduce((sum: number, item: EmotionRecord) => sum + item.level, 0) / matches.length;
  }

  private dayBar(day: string): number {
    const average = this.dayAverage(day);
    return average === undefined ? 0 : Math.max(8, Math.round((average + 3) / 6 * 100));
  }

  private dayEmotionLabel(day: string): string {
    const average = this.dayAverage(day);
    return average === undefined ? '—' : average.toFixed(1);
  }

  @Builder
  private statLine(label: string, value: number, color: string) {
    Row({ space: 10 }) {
      Row().width(10).height(10).borderRadius(5).backgroundColor(color)
      Text(label).fontSize(14).fontColor(TEXT).layoutWeight(1)
      Text(`${value}`).fontSize(15).fontWeight(FontWeight.Medium).fontColor(TEXT)
    }.width('100%')
  }

  @Builder
  private profilePage() {
    Scroll() {
      Column({ space: 14 }) {
        this.header('我的', '数据、备份与应用设置')
        Column({ space: 2 }) {
          this.menuRow('📅', '日历', '按日期回看日志与情绪', 'calendar')
          this.menuRow('😊', '情绪记录', '七级情绪与子情绪', 'emotion')
          this.menuRow('🗂️', '记录管理', '搜索、查看和删除记录', 'logs')
          this.menuRow('◉', '鸿蒙体验', '星闪、实况窗、智慧服务与多设备', 'harmony')
          this.menuRow('⚙️', '设置与备份', '跨设备 JSON 与版本信息', 'settings')
        }.width('100%').backgroundColor(SURFACE).borderRadius(20).padding({ left: 14, right: 14 })
        Column({ space: 6 }) {
          Text('Flash Aero').fontSize(22).fontWeight(FontWeight.Bold).fontColor(TEXT)
          Text('v0.1.0 · HarmonyOS 原生版').fontSize(13).fontColor(MUTED)
          Text('让每一次闪念都有落点').fontSize(12).fontColor(MUTED)
        }.width('100%').height(130).justifyContent(FlexAlign.Center).backgroundColor('#EAF2FF').borderRadius(20)
      }.width('100%').padding({ left: 16, right: 16, bottom: 90 })
    }.width('100%').height('100%').backgroundColor(BACKGROUND)
  }

  @Builder
  private menuRow(icon: string, title: string, subtitle: string, destination: string) {
    Row({ space: 12 }) {
      Text(icon).fontSize(24).width(36)
      Column({ space: 2 }) {
        Text(title).fontSize(16).fontColor(TEXT).width('100%')
        Text(subtitle).fontSize(11).fontColor(MUTED).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text('›').fontSize(26).fontColor('#98A2B3')
    }.width('100%').height(70).onClick(() => this.openDetail(destination))
  }

  @Builder
  private detailPage() {
    Column() {
      Row({ space: 10 }) {
        Button('‹ 返回', { type: ButtonType.Normal }).fontColor(BRAND).backgroundColor(Color.Transparent)
          .onClick(() => this.closeDetail())
        Text(this.detailTitle()).fontSize(20).fontWeight(FontWeight.Bold).fontColor(TEXT)
      }.width('100%').height(60).padding({ left: 8, right: 16 })
      if (this.detail === 'emotion') this.emotionPage()
      else if (this.detail === 'calendar') this.calendarPage()
      else if (this.detail === 'logs') this.logManagerPage()
      else if (this.detail === 'harmony') this.harmonyFeaturesPage()
      else this.settingsPage()
    }.width('100%').height('100%').backgroundColor(BACKGROUND)
  }

  private detailTitle(): string {
    if (this.detail === 'emotion') return '记录情绪';
    if (this.detail === 'calendar') return '日历';
    if (this.detail === 'logs') return '记录管理';
    if (this.detail === 'harmony') return '鸿蒙体验';
    return '设置与备份';
  }

  @Builder
  private harmonyFeaturesPage() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 6 }) {
          Text('系统能力').fontSize(18).fontWeight(FontWeight.Medium).fontColor(TEXT).width('100%')
          Text('仅展示真实检测与当前接入状态；需审核的系统权限不会在未获准时调用。')
            .fontSize(12).fontColor(MUTED).lineHeight(19).width('100%')
        }.width('100%').padding(16).backgroundColor('#EAF2FF').borderRadius(20)

        Column({ space: 2 }) {
          this.capabilityRow('✦', '星闪', this.nearLinkSupported ? '此设备支持' : '此设备暂不支持',
            this.nearLinkSupported ? '#16845B' : MUTED)
          this.capabilityRow('▣', '多设备适配', this.isExpandedWindow ? '大屏侧边导航' :
            (this.isMediumWindow ? '中屏响应式布局' : '手机紧凑布局'), '#16845B')
          this.capabilityRow('●', '实况窗', this.liveViewEnabled ? '接口可用，仍需真机准入' : '等待场景准入',
            this.liveViewEnabled ? '#16845B' : '#B54708')
          this.capabilityRow('◉', '闪控球 / 闪控窗', this.floatingBallSupported ? '系统支持，等待权限准入' : '当前设备不支持',
            this.floatingBallSupported ? '#B54708' : MUTED)
          this.capabilityRow('⌁', '碰一碰', '等待手动签名与 App Linking 配置', '#B54708')
          this.capabilityRow('✧', 'Harmony Intelligence', '快速记录意图待平台审核', '#B54708')
        }.width('100%').padding({ left: 14, right: 14 }).backgroundColor(SURFACE).borderRadius(20)

        Column({ space: 8 }) {
          Text('为什么部分能力没有直接开启？').fontSize(16).fontWeight(FontWeight.Medium).fontColor(TEXT).width('100%')
          Text('实况窗、闪控球、碰一碰和小艺意图均涉及场景、签名、真机或平台审核。Flash 会在取得正式资格后启用，不申请与产品场景不符的受限权限。')
            .fontSize(12).fontColor(MUTED).lineHeight(20).width('100%')
        }.width('100%').padding(16).backgroundColor('#FFF8E7').borderRadius(20)
      }.width('100%').padding({ left: 16, right: 16, bottom: 30 })
    }.width('100%').layoutWeight(1)
  }

  @Builder
  private capabilityRow(icon: string, title: string, status: string, statusColor: string) {
    Row({ space: 12 }) {
      Text(icon).fontSize(22).fontColor(BRAND).width(34).textAlign(TextAlign.Center)
      Text(title).fontSize(14).fontColor(TEXT).layoutWeight(1)
      Text(status).fontSize(11).fontColor(statusColor).textAlign(TextAlign.End).maxLines(2).width(150)
    }.width('100%').height(68)
  }

  @Builder
  private emotionPage() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 14 }) {
          Text(emotionEmoji(this.emotionLevel)).fontSize(64)
          Text(emotionName(this.emotionLevel)).fontSize(20).fontWeight(FontWeight.Medium).fontColor(TEXT)
          Slider({ value: this.emotionLevel, min: -3, max: 3, step: 1, style: SliderStyle.OutSet })
            .blockColor(BRAND).selectedColor(BRAND).trackColor('#DCE6F7')
            .onChange((value: number) => this.emotionLevel = Math.round(value))
          Row() {
            Text('😡').layoutWeight(1).fontSize(18)
            Text('😐').layoutWeight(1).fontSize(18).textAlign(TextAlign.Center)
            Text('😍').layoutWeight(1).fontSize(18).textAlign(TextAlign.End)
          }.width('100%')
        }.width('100%').padding(20).backgroundColor(SURFACE).borderRadius(20)

        if (this.emotionLevel < 0) {
          Column({ space: 10 }) {
            Text('更接近哪种感受？').fontSize(16).fontColor(TEXT).width('100%')
            Row({ space: 8 }) {
              this.subEmotionChip(SubEmotion.SAD)
              this.subEmotionChip(SubEmotion.ANGRY)
              this.subEmotionChip(SubEmotion.UNCOMFORTABLE)
            }.width('100%')
          }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(20)
        }

        TextArea({ placeholder: '想补充些什么？（可选）', text: this.emotionNote })
          .height(90).maxLength(2000).backgroundColor(SURFACE).borderRadius(16)
          .onChange((value: string) => this.emotionNote = value.slice(0, 2000))
        Button('保存情绪').width('100%').height(46).backgroundColor(BRAND).onClick(() => this.saveEmotion())

        if (this.emotions.length > 0) {
          Column({ space: 4 }) {
            Text('最近情绪').fontSize(17).fontWeight(FontWeight.Medium).fontColor(TEXT).width('100%')
            ForEach(this.emotions.slice(0, 10), (item: EmotionRecord) => {
              Row({ space: 10 }) {
                Text(emotionEmoji(item.level)).fontSize(28)
                Column({ space: 2 }) {
                  Text(`${emotionName(item.level)} ${subEmotionName(item.subEmotion)}`).fontSize(14).fontColor(TEXT)
                  Text(`${shortDay(item.recordDate)} ${item.note ?? ''}`).fontSize(11).fontColor(MUTED).maxLines(1)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Button('删除', { type: ButtonType.Normal }).fontSize(11).fontColor('#B42318')
                  .backgroundColor('#FFF1F0').onClick(() => this.pendingDeleteEmotionId = item.id)
              }.width('100%').padding({ top: 9, bottom: 9 })
            }, (item: EmotionRecord) => item.id)
          }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(20)
        }
      }.width('100%').padding({ left: 16, right: 16, bottom: 30 })
    }.width('100%').layoutWeight(1)
  }

  @Builder
  private subEmotionChip(value: string) {
    Text(subEmotionName(value)).fontSize(13)
      .fontColor(this.selectedSubEmotion === value ? Color.White : TEXT)
      .textAlign(TextAlign.Center).layoutWeight(1).height(36).padding({ top: 9 })
      .backgroundColor(this.selectedSubEmotion === value ? BRAND : '#EEF2F8').borderRadius(18)
      .onClick(() => this.selectedSubEmotion = value)
  }

  @Builder
  private calendarPage() {
    Scroll() {
      Column({ space: 12 }) {
        Text(monthTitle(dayString())).fontSize(22).fontWeight(FontWeight.Bold).fontColor(TEXT).width('100%')
        ForEach(this.displayedActivityDays(), (day: string) => {
          Column({ space: 8 }) {
            Text(shortDay(day)).fontSize(15).fontWeight(FontWeight.Medium).fontColor(TEXT).width('100%')
            ForEach(this.logsByDay.get(day) ?? [],
              (item: LogItem) => this.logRow(item), (item: LogItem) => item.id)
            ForEach(this.emotionsByDay.get(day) ?? [],
              (item: EmotionRecord) => {
                Row({ space: 8 }) {
                  Text(emotionEmoji(item.level)).fontSize(22)
                  Text(`${emotionName(item.level)} ${item.note ?? ''}`).fontSize(14).fontColor(TEXT).layoutWeight(1)
                }.width('100%')
              }, (item: EmotionRecord) => item.id)
          }.width('100%').padding(14).backgroundColor(SURFACE).borderRadius(18)
        }, (day: string) => day)
        if (this.activityDays.length === 0) this.emptyState('📅', '还没有可回看的记录')
        if (this.activityDays.length > this.calendarDayLimit) {
          Button(`加载更早日期（剩余 ${this.activityDays.length - this.calendarDayLimit} 天）`)
            .width('100%').height(42).fontColor(BRAND).backgroundColor('#F0EBFF')
            .onClick(() => this.calendarDayLimit += 30)
        }
      }.width('100%').padding({ left: 16, right: 16, bottom: 30 })
    }.width('100%').layoutWeight(1)
  }

  private rebuildCalendarIndex(): void {
    const logsByDay = new Map<string, LogItem[]>();
    const emotionsByDay = new Map<string, EmotionRecord[]>();
    const values = new Set<string>();
    this.logs.forEach((item: LogItem) => {
      values.add(item.recordDate);
      const items = logsByDay.get(item.recordDate) ?? [];
      items.push(item);
      logsByDay.set(item.recordDate, items);
    });
    this.emotions.forEach((item: EmotionRecord) => {
      values.add(item.recordDate);
      const items = emotionsByDay.get(item.recordDate) ?? [];
      items.push(item);
      emotionsByDay.set(item.recordDate, items);
    });
    this.logsByDay = logsByDay;
    this.emotionsByDay = emotionsByDay;
    this.activityDays = Array.from(values.values()).sort().reverse();
  }

  private displayedActivityDays(): string[] {
    return this.activityDays.slice(0, this.calendarDayLimit);
  }

  @Builder
  private logManagerPage() {
    Column({ space: 12 }) {
      TextInput({ placeholder: '搜索记录', text: this.searchText })
        .height(44).backgroundColor(SURFACE).borderRadius(14)
        .onChange((value: string) => {
          this.searchText = value;
          this.logDisplayLimit = 50;
          this.scheduleSearch();
        })
      List({ space: 6 }) {
        ForEach(this.displayedLogs(), (item: LogItem) => {
          ListItem() { this.logRow(item) }.padding({ left: 14, right: 14 }).backgroundColor(SURFACE).borderRadius(14)
        }, (item: LogItem) => item.id)
        if (this.hasMoreLogs()) {
          ListItem() {
            Button(`加载更多（剩余 ${this.filteredLogCount() - this.displayedLogs().length} 条）`)
              .width('100%').height(42).fontColor(BRAND).backgroundColor('#F0EBFF')
              .onClick(() => this.logDisplayLimit += 50)
          }
        }
      }.layoutWeight(1).width('100%')
    }.width('100%').layoutWeight(1).padding({ left: 16, right: 16, bottom: 16 })
  }

  @Builder
  private settingsPage() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 8 }) {
          Text('跨设备备份').fontSize(17).fontWeight(FontWeight.Medium).fontColor(TEXT).width('100%')
          Text('备份格式与 Android、macOS 保持一致：flash-backup-v1').fontSize(12).fontColor(MUTED).width('100%')
          Button('导出备份 JSON').width('100%').height(42).backgroundColor(BRAND)
            .onClick(() => this.exportBackup())
          Button('导入并分析差异').width('100%').height(42).fontColor(BRAND).backgroundColor('#EAF2FF')
            .onClick(() => this.chooseBackup())
          if (this.importSummary !== '') {
            Column({ space: 10 }) {
              Text('差异分析').fontSize(15).fontWeight(FontWeight.Medium).fontColor(TEXT).width('100%')
              Text(this.importSummary).fontSize(12).fontColor(MUTED).lineHeight(20).width('100%')
              Row({ space: 8 }) {
                Button('合并').layoutWeight(1).height(38).backgroundColor(BRAND)
                  .onClick(() => this.applyBackup(true))
                Button('覆盖').layoutWeight(1).height(38).fontColor('#B42318').backgroundColor('#FFF1F0')
                  .onClick(() => this.applyBackup(false))
                Button('取消').layoutWeight(1).height(38).fontColor(MUTED).backgroundColor('#EEF1F6')
                  .onClick(() => {
                    this.pendingImport = undefined;
                    this.importSummary = '';
                  })
              }.width('100%')
            }.width('100%').padding(12).backgroundColor('#F6F8FC').borderRadius(14)
          }
        }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(20)

        Column({ space: 8 }) {
          Text('局域网传输').fontSize(17).fontWeight(FontWeight.Medium).fontColor(TEXT).width('100%')
          Text('与 Android、macOS 共用协议：四位 PIN、60 秒有效、最多尝试五次。')
            .fontSize(12).fontColor(MUTED).width('100%')
          if (this.lanMode === '') {
            Row({ space: 8 }) {
              Button('发送备份').layoutWeight(1).height(42).backgroundColor('#7A4CC2')
                .onClick(() => this.startLanSend())
              Button('接收备份').layoutWeight(1).height(42).fontColor('#7A4CC2').backgroundColor('#F3ECFF')
                .onClick(() => this.startLanReceive())
            }.width('100%')
          } else if (this.lanMode === 'sending') {
            Column({ space: 8 }) {
              Text('配对 PIN').fontSize(12).fontColor(MUTED)
              Text(this.lanPin).fontSize(38).fontWeight(FontWeight.Bold).fontColor('#7A4CC2').letterSpacing(8)
              Text('请在接收设备输入此 PIN；60 秒后自动失效。').fontSize(12).fontColor(MUTED)
              Button('取消发送').width('100%').height(38).fontColor(MUTED).backgroundColor('#EEF1F6')
                .onClick(() => this.stopLan())
            }.width('100%').padding(12).backgroundColor('#F8F4FF').borderRadius(14)
          } else {
            Column({ space: 8 }) {
              Text(this.lanDevices.length === 0 ? '正在搜索发送设备…' : '选择发送设备')
                .fontSize(13).fontColor(MUTED).width('100%')
              ForEach(this.lanDevices, (device: LanDevice) => {
                Button(device.name).width('100%').height(38)
                  .fontColor(this.selectedLanDevice === device.id ? Color.White : TEXT)
                  .backgroundColor(this.selectedLanDevice === device.id ? '#7A4CC2' : '#EEF1F6')
                  .onClick(() => this.selectedLanDevice = device.id)
              }, (device: LanDevice) => device.id)
              TextInput({ placeholder: '四位配对 PIN', text: this.lanEnteredPin })
                .type(InputType.Number).maxLength(4).height(42).backgroundColor(Color.White).borderRadius(12)
                .onChange((value: string) => this.lanEnteredPin = value.replace(/\D/g, '').slice(0, 4))
              Row({ space: 8 }) {
                Button(this.lanMode === 'connecting' ? '正在接收…' : '验证并接收').layoutWeight(1).height(40)
                  .backgroundColor('#7A4CC2').enabled(this.lanMode !== 'connecting')
                  .onClick(() => this.receiveLan())
                Button('取消').width(80).height(40).fontColor(MUTED).backgroundColor('#EEF1F6')
                  .onClick(() => this.stopLan())
              }.width('100%')
            }.width('100%').padding(12).backgroundColor('#F8F4FF').borderRadius(14)
          }
        }.width('100%').padding(16).backgroundColor(SURFACE).borderRadius(20)

        Button('清空全部本地数据').width('100%').height(44).fontColor('#B42318').backgroundColor('#FFF1F0')
          .onClick(() => this.showClearConfirm = true)
        Text('Flash Aero v0.1.0\nHarmonyOS 原生版 · com.flash.app.harmonyos')
          .fontSize(12).fontColor(MUTED).textAlign(TextAlign.Center).width('100%').margin({ top: 12 })
      }.width('100%').padding({ left: 16, right: 16, bottom: 30 })
    }.width('100%').layoutWeight(1)
  }

  @Builder
  private welcomeOverlay() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#99000000')
      Column({ space: 16 }) {
        Text('⚡').fontSize(56)
        Text('欢迎来到 Flash Aero').fontSize(24).fontWeight(FontWeight.Bold).fontColor(TEXT)
        Text('捕捉日志、灵感与情绪，让每一次闪念都有落点。')
          .fontSize(14).fontColor(MUTED).textAlign(TextAlign.Center).lineHeight(22)
        Button('开始使用').width('100%').height(46).backgroundColor(BRAND).onClick(() => this.finishWelcome())
      }.width('84%').padding(24).backgroundColor(SURFACE).borderRadius(26)
    }.width('100%').height('100%')
  }

  @Builder
  private currentPage() {
    if (this.detail !== '') {
      this.detailPage()
    } else if (this.activeTab === 0) {
      this.homePage()
    } else if (this.activeTab === 1) {
      this.explorePage()
    } else if (this.activeTab === 2) {
      this.statsPage()
    } else {
      this.profilePage()
    }
  }

  @Builder
  private bottomNavigation() {
    Row() {
      this.tabButton(0, '⌂', '首页')
      this.tabButton(1, '◇', '探索')
      this.tabButton(2, '▥', '统计')
      this.tabButton(3, '○', '我的')
    }
    .width('100%')
    .height(68)
    .padding({ left: 8, right: 8, bottom: 8 })
    .backgroundColor('#F8FFFFFF')
    .backdropBlur(18)
  }

  @Builder
  private railButton(index: number, emoji: string, label: string) {
    Column({ space: 5 }) {
      Text(emoji).fontSize(22).fontColor(this.activeTab === index ? BRAND : MUTED)
      Text(label).fontSize(11).fontColor(this.activeTab === index ? BRAND : MUTED)
    }
    .width(78)
    .height(68)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.activeTab === index ? '#EAF2FF' : Color.Transparent)
    .borderRadius(18)
    .onClick(() => this.switchTab(index))
  }

  @Builder
  private navigationRail() {
    Column({ space: 10 }) {
      Text('⚡').fontSize(30).margin({ top: 24, bottom: 18 })
      this.railButton(0, '⌂', '首页')
      this.railButton(1, '◇', '探索')
      this.railButton(2, '▥', '统计')
      this.railButton(3, '○', '我的')
      Blank()
      Text('Aero').fontSize(11).fontColor(MUTED).margin({ bottom: 20 })
    }
    .width(104)
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F8FFFFFF')
    .backdropBlur(18)
  }

  @Builder
  private fabOption(label: string, icon: string, color: string, action: () => void) {
    Row({ space: 10 }) {
      Text(label).fontSize(13).fontColor(TEXT).padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .backgroundColor(SURFACE).borderRadius(18)
      Button(icon, { type: ButtonType.Circle }).width(44).height(44).fontSize(20)
        .fontColor(Color.White).backgroundColor(color).onClick(action)
    }
  }

  @Builder
  private quickCreateFab() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.fabExpanded) {
        Column().width('100%').height('100%').backgroundColor('#52000000')
          .onClick(() => this.dismissFab())
      }
      Column({ space: 11 }) {
        if (this.fabExpanded) {
          Column({ space: 11 }) {
            this.fabOption('情绪', '♥', '#FF6B9D', () => {
              this.fabExpanded = false;
              this.fabProgress = 0;
              this.openDetail('emotion');
            })
            this.fabOption('灵感', '💡', '#F5B800', () => {
              this.fabExpanded = false;
              this.fabProgress = 0;
              this.quickCategory = Category.IDEA;
            })
            this.fabOption('日志', '📖', '#8B5CF6', () => {
              this.fabExpanded = false;
              this.fabProgress = 0;
              this.quickCategory = Category.LOG;
            })
            this.fabOption('日程', '📅', '#22B573', () => {
              this.fabExpanded = false;
              this.fabProgress = 0;
              this.openDetail('calendar');
            })
          }.opacity(this.fabProgress).translate({ y: 18 * (1 - this.fabProgress) })
        }
        Button('+', { type: ButtonType.Circle })
          .width(54).height(54).fontSize(28).fontColor(Color.White).backgroundColor(BRAND)
          .rotate({ angle: 45 * this.fabProgress })
          .onClick(() => this.toggleFab())
      }
      .alignItems(HorizontalAlign.End)
      .margin({ right: 18, bottom: this.isExpandedWindow ? 22 : 82 })
    }.width('100%').height('100%')
  }

  @Builder
  private quickInputDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#66000000')
        .onClick(() => {
          this.quickCategory = '';
          this.quickText = '';
        })
      Column({ space: 14 }) {
        Text(this.quickCategory === Category.IDEA ? '记录灵感' : '记录日志')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor(TEXT).width('100%')
        TextArea({
          placeholder: this.quickCategory === Category.IDEA ? '此刻的想法是…' : '闪过即留…',
          text: this.quickText
        })
          .height(110).maxLength(140).backgroundColor('#F3F6FB').borderRadius(14)
          .onChange((value: string) => this.quickText = value.slice(0, 140))
        Text(`${this.quickText.length}/140`).fontSize(11).fontColor(MUTED).width('100%').textAlign(TextAlign.End)
        Row({ space: 10 }) {
          Button('取消').layoutWeight(1).height(42).fontColor(MUTED).backgroundColor('#EEF1F6')
            .onClick(() => {
              this.quickCategory = '';
              this.quickText = '';
            })
          Button('保存').layoutWeight(1).height(42).backgroundColor(BRAND)
            .enabled(this.quickText.trim().length > 0).onClick(() => this.saveQuickCategory())
        }.width('100%')
      }.width(this.isMediumWindow ? 460 : '84%').padding(22).backgroundColor(SURFACE).borderRadius(24)
    }.width('100%').height('100%')
  }

  private cancelDestructiveAction(): void {
    this.pendingDeleteLogId = '';
    this.pendingDeleteEmotionId = '';
    this.showClearConfirm = false;
  }

  private destructiveTitle(): string {
    if (this.pendingDeleteLogId) return '删除这条记录？';
    if (this.pendingDeleteEmotionId) return '删除这条情绪记录？';
    return '清空全部本地数据？';
  }

  private destructiveMessage(): string {
    return this.showClearConfirm ? '日志、灵感和情绪数据将全部删除。此操作无法撤销，建议先导出备份。' :
      '删除后无法撤销。';
  }

  @Builder
  private destructiveConfirmDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#66000000').onClick(() => this.cancelDestructiveAction())
      Column({ space: 14 }) {
        Text(this.destructiveTitle()).fontSize(20).fontWeight(FontWeight.Bold).fontColor(TEXT).width('100%')
        Text(this.destructiveMessage()).fontSize(13).fontColor(MUTED).lineHeight(20).width('100%')
        Row({ space: 10 }) {
          Button('取消').layoutWeight(1).height(42).fontColor(MUTED).backgroundColor('#EEF1F6')
            .onClick(() => this.cancelDestructiveAction())
          Button(this.showClearConfirm ? '确认清空' : '确认删除').layoutWeight(1).height(42)
            .fontColor(Color.White).backgroundColor('#D92D20').onClick(() => this.confirmDestructiveAction())
        }.width('100%')
      }.width(this.isMediumWindow ? 460 : '84%').padding(22).backgroundColor(SURFACE).borderRadius(24)
    }.width('100%').height('100%')
  }

  @Builder
  private editLogDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor('#66000000').onClick(() => {
        this.editingLogId = '';
        this.editText = '';
      })
      Column({ space: 14 }) {
        Text('编辑记录').fontSize(20).fontWeight(FontWeight.Bold).fontColor(TEXT).width('100%')
        TextArea({ placeholder: '记录内容', text: this.editText })
          .height(130).maxLength(10000).backgroundColor('#F3F6FB').borderRadius(14)
          .onChange((value: string) => this.editText = value.slice(0, 10000))
        Text(`${this.editText.length}/10000`).fontSize(11).fontColor(MUTED).width('100%').textAlign(TextAlign.End)
        Row({ space: 10 }) {
          Button('取消').layoutWeight(1).height(42).fontColor(MUTED).backgroundColor('#EEF1F6')
            .onClick(() => {
              this.editingLogId = '';
              this.editText = '';
            })
          Button('保存修改').layoutWeight(1).height(42).backgroundColor(BRAND)
            .enabled(this.editText.trim().length > 0).onClick(() => this.saveEditedLog())
        }.width('100%')
      }.width(this.isMediumWindow ? 520 : '88%').padding(22).backgroundColor(SURFACE).borderRadius(24)
    }.width('100%').height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.isExpandedWindow && this.detail === '') {
        Row() {
          this.navigationRail()
          Row() {
            Stack() {
              this.currentPage()
            }
            .layoutWeight(1)
            .constraintSize({ maxWidth: 980 })
            .opacity(this.contentOpacity)
            .translate({ y: this.contentOffset })
          }.layoutWeight(1).height('100%').justifyContent(FlexAlign.Center)
        }.width('100%').height('100%')
      } else {
        Row() {
          Stack() {
            this.currentPage()
          }
          .layoutWeight(1)
          .constraintSize({ maxWidth: this.isMediumWindow ? 760 : 2000 })
          .opacity(this.contentOpacity)
          .translate({ y: this.contentOffset })
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)

        if (this.detail === '') {
          this.bottomNavigation()
        }
      }

      if (this.toast !== '') {
        Text(this.toast).fontSize(13).fontColor(Color.White).padding({ left: 18, right: 18, top: 10, bottom: 10 })
          .backgroundColor('#DD172033').borderRadius(18).margin({ bottom: 82 })
      }

      if (!this.showWelcome && this.detail === '' && this.activeTab === 0) this.quickCreateFab()
      if (this.quickCategory !== '') this.quickInputDialog()
      if (this.editingLogId !== '') this.editLogDialog()
      if (this.pendingDeleteLogId !== '' || this.pendingDeleteEmotionId !== '' || this.showClearConfirm) {
        this.destructiveConfirmDialog()
      }

      if (this.showWelcome) this.welcomeOverlay()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F9FA')
    .linearGradient({
      angle: 145,
      colors: [['#FFF4F0FF', 0.0], ['#FFF1F8FF', 0.48], ['#FFFFF3EC', 1.0]]
    })
  }
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
