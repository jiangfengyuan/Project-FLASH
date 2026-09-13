import { NavigationState, ThemeState, SettingsState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
const BRAND = '#6C5CE7';

@Component
export struct HarmonyFeaturesPage {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink settings: SettingsState;
  actions?: PageActions;

  @Builder
  private harmonyFeaturesPage() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 6 }) {
          Text('系统能力').fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          Text('仅展示真实检测与当前接入状态；需审核的系统权限不会在未获准时调用。')
            .fontSize(12).fontColor(this.theme.themeMuted).lineHeight(19).width('100%')
        }.width('100%').padding(16).backgroundColor(this.theme.themeTint).borderRadius(20)

        Column({ space: 2 }) {
          this.capabilityRow('✦', '星闪', this.settings.nearLinkSupported ? '此设备支持' : '此设备暂不支持',
            this.settings.nearLinkSupported ? '#16845B' : this.theme.themeMuted)
          this.capabilityRow('▣', '多设备适配', this.navigation.isExpandedWindow ? '大屏侧边导航' :
            (this.navigation.isMediumWindow ? '中屏响应式布局' : '手机紧凑布局'), '#16845B')
          this.capabilityRow('●', '实况窗', this.settings.liveViewEnabled ? '接口可用，仍需真机准入' : '等待场景准入',
            this.settings.liveViewEnabled ? '#16845B' : '#B54708')
          this.capabilityRow('◉', '闪控球 / 闪控窗', this.settings.floatingBallSupported ? '系统支持，等待权限准入' : '当前设备不支持',
            this.settings.floatingBallSupported ? '#B54708' : this.theme.themeMuted)
          this.capabilityRow('⌁', '碰一碰', '等待手动签名与 App Linking 配置', '#B54708')
          this.capabilityRow('✧', 'Harmony Intelligence', '快速记录意图待平台审核', '#B54708')
        }.width('100%').padding({ left: 14, right: 14 }).backgroundColor(this.theme.themeSurface).borderRadius(20)

        Column({ space: 8 }) {
          Text('为什么部分能力没有直接开启？').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          Text('实况窗、闪控球、碰一碰和小艺意图均涉及场景、签名、真机或平台审核。Flash 会在取得正式资格后启用，不申请与产品场景不符的受限权限。')
            .fontSize(12).fontColor(this.theme.themeMuted).lineHeight(20).width('100%')
        }.width('100%').padding(16).backgroundColor('#FFF8E7').borderRadius(20)
      }.width('100%').padding({ left: 16, right: 16, bottom: 30 })
    }.width('100%').layoutWeight(1)
  }

  @Builder
  private capabilityRow(icon: string, title: string, status: string, statusColor: string) {
    Row({ space: 12 }) {
      Text(icon).fontSize(22).fontColor(BRAND).width(34).textAlign(TextAlign.Center)
      Text(title).fontSize(14).fontColor(this.theme.themeText).layoutWeight(1)
      Text(status).fontSize(11).fontColor(statusColor).textAlign(TextAlign.End).maxLines(2).width(150)
    }.width('100%').height(68)
  }

  build() {
    this.harmonyFeaturesPage()
  }
}

