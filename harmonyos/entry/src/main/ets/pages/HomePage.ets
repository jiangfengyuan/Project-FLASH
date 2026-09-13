import { LogItem } from '../models/Models';
import { NavigationState, ThemeState, HomeState, FeedbackState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import { PageHeader, EmptyState, RecordRow } from '../components/CommonBuilders';
const BRAND = '#6C5CE7';

@Component
export struct HomePage {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink home: HomeState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;

  @Builder
  private homePage() {
    Scroll() {
      Column({ space: 14 }) {
        PageHeader(this.theme, `${this.greeting()} 👋`, '今天也记录一点什么吧。')
        Column({ space: 12 }) {
          Row({ space: 12 }) {
            Text('⌕').fontSize(28).fontColor(BRAND)
            Column({ space: 3 }) {
              Text('搜索日志与灵感').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
              Text('按关键词或标签查找').fontSize(12).fontColor(this.theme.themeMuted).width('100%')
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Text('搜索').fontSize(13).fontWeight(FontWeight.Medium).fontColor(BRAND)
          }
          .width('100%')
          .height(72)
          .padding({ left: 18, right: 18 })
          .backgroundColor(this.theme.themeTint)
          .border({ width: 1, color: '#D7CCFF' })
          .borderRadius(36)
          .onClick(() => requireActions(this.actions).switchTab(1))
          .animation({ duration: 180, curve: Curve.EaseOut })

          if (this.navigation.isMediumWindow) {
            Row({ space: 10 }) {
              this.moduleCard('📖', '日志', this.home.todayLogCount, '#8B5CF6', this.theme.themeTint, 'explore')
              this.moduleCard('💡', '想法', this.home.todayIdeaCount, '#F5B800', '#FFF7D6', 'explore')
              this.moduleCard('📅', '日程', -1, '#22B573', '#E2F7EC', 'calendar')
              this.moduleCard('♥', '情绪', this.home.todayEmotionCount, '#FF6B9D', '#FFE8F0', 'emotion')
            }.width('100%')
          } else {
            Column({ space: 10 }) {
              Row({ space: 10 }) {
                this.moduleCard('📖', '日志', this.home.todayLogCount, '#8B5CF6', this.theme.themeTint, 'explore')
                this.moduleCard('💡', '想法', this.home.todayIdeaCount, '#F5B800', '#FFF7D6', 'explore')
              }.width('100%')
              Row({ space: 10 }) {
                this.moduleCard('📅', '日程', -1, '#22B573', '#E2F7EC', 'calendar')
                this.moduleCard('♥', '情绪', this.home.todayEmotionCount, '#FF6B9D', '#FFE8F0', 'emotion')
              }.width('100%')
            }.width('100%')
          }

          Column({ space: 10 }) {
            Text('今日概览').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
            Row() {
              this.overviewItem(`${this.home.todayLogCount}`, '日志')
              this.overviewItem(`${this.home.todayIdeaCount}`, '想法')
              this.overviewItem(`${this.home.todayEmotionCount}`, '情绪')
              this.overviewItem(this.latestEmotionEmoji(), '当前')
            }.width('100%')
          }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(20)

          if (this.home.recentLogs.length > 0) {
            Column() {
              Text('最近动态').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%').margin({ bottom: 5 })
              ForEach(this.home.recentLogs.slice(0, 5), (item: LogItem) => RecordRow(this.theme, this.feedback, requireActions(this.actions), item), (item: LogItem) => item.id)
            }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(20)
          } else {
            EmptyState(this.theme, '⚡', '第一条记录，正在等你')
          }
        }.padding({ left: 16, right: 16, bottom: 90 }).width('100%')
      }.width('100%')
    }.width('100%').height('100%').backgroundColor(this.theme.themeBackground)
  }

  private greeting(): string {
    const hour = new Date().getHours();
    if (hour >= 5 && hour <= 10) return '早上好';
    if (hour <= 12) return '中午好';
    if (hour <= 17) return '下午好';
    if (hour <= 22) return '晚上好';
    return '夜深了';
  }

  private latestEmotionEmoji(): string {
    return this.home.latestEmoji;
  }

  @Builder
  private moduleCard(icon: string, title: string, count: number, color: string, background: string, destination: string) {
    Column({ space: 8 }) {
      Row() {
        Text(icon).fontSize(23)
        Blank()
        if (count >= 0) Text(`${count}`).fontSize(18).fontWeight(FontWeight.Bold).fontColor(color)
      }.width('100%')
      Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
      Text(count >= 0 ? '今日新增' : '查看').fontSize(11).fontColor(this.theme.themeMuted).width('100%')
    }
    .layoutWeight(1)
    .height(112)
    .padding(14)
    .backgroundColor(background)
    .borderRadius(20)
    .onClick(() => {
      if (destination === 'explore') requireActions(this.actions).switchTab(1);
      else requireActions(this.actions).openDetail(destination);
    })
    .animation({ duration: 180, curve: Curve.EaseOut })
  }

  @Builder
  private overviewItem(value: string, label: string) {
    Column({ space: 3 }) {
      Text(value).fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText)
      Text(label).fontSize(11).fontColor(this.theme.themeMuted)
    }.layoutWeight(1)
  }

  build() {
    this.homePage()
  }
}

