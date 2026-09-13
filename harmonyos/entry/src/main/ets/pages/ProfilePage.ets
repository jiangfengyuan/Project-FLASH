import { ThemeState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import { PageHeader, DOCK_CLEARANCE, RADIUS_CARD, BRAND } from '../components/CommonBuilders';

@Component
export struct ProfilePage {
  @ObjectLink theme: ThemeState;
  actions?: PageActions;

  @Builder
  private profilePage() {
    Scroll() {
      Column({ space: 14 }) {
        PageHeader(this.theme, '设置', '数据、备份与应用设置')
        Column({ space: 2 }) {
          this.menuRow($r('sys.symbol.calendar'), '日历', '按日期回看日志与情绪', 'calendar')
          this.menuRow($r('sys.symbol.face_smiling'), '情绪记录', '七级情绪与子情绪', 'emotion')
          this.menuRow($r('sys.symbol.doc_text'), '记录管理', '搜索、查看和删除记录', 'logs')
          this.menuRow($r('sys.symbol.bolt'), '鸿蒙体验', '星闪、实况窗、智慧服务与多设备', 'harmony')
          this.menuRow($r('sys.symbol.gearshape'), '设置与备份', '跨设备 JSON 与版本信息', 'settings')
        }.width('100%').backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD).padding({ left: 14, right: 14 })
        Column({ space: 6 }) {
          Text('Flash Aero').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.theme.themeText)
          Text('v0.1.0 · HarmonyOS 原生版').fontSize(13).fontColor(this.theme.themeMuted)
          Text('让每一次闪念都有落点').fontSize(12).fontColor(this.theme.themeMuted)
        }.width('100%').height(130).justifyContent(FlexAlign.Center).backgroundColor(this.theme.themeTint).borderRadius(RADIUS_CARD)
      }.width('100%').padding({ left: 20, right: 20, bottom: DOCK_CLEARANCE })
    }.width('100%').height('100%').backgroundColor(this.theme.themeBackground)
  }

  @Builder
  private menuRow(icon: Resource, title: string, subtitle: string, destination: string) {
    Row({ space: 12 }) {
      SymbolGlyph(icon).fontSize(22).fontColor([BRAND]).width(36)
      Column({ space: 2 }) {
        Text(title).fontSize(16).fontColor(this.theme.themeText).width('100%')
        Text(subtitle).fontSize(11).fontColor(this.theme.themeMuted).width('100%')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text('›').fontSize(26).fontColor('#98A2B3')
    }.width('100%').height(70).onClick(() => requireActions(this.actions).openDetail(destination))
  }

  build() {
    this.profilePage()
  }
}

