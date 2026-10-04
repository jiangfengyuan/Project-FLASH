import { NavigationState, ThemeState, SettingsState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  FlashCard, brandText, hairlineColor, cardShadowColor, statusText, RADIUS_CARD,
  TYPE_SECTION, TYPE_GROUP, TYPE_BODY, TYPE_SECONDARY, TYPE_CAPTION
} from '../components/CommonBuilders';

@Component
export struct HarmonyFeaturesPage {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink settings: SettingsState;
  actions?: PageActions;

  @Builder
  private harmonyFeaturesPage() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 6 }) {
          Text('系统能力').fontSize(TYPE_GROUP).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          Text('仅展示真实检测与当前接入状态；需审核的系统权限不会在未获准时调用。')
            .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).lineHeight(19).width('100%')
        }.width('100%').padding(20).backgroundColor(this.theme.themeTint).borderRadius(RADIUS_CARD)
          .border({ width: 0.5, color: hairlineColor(this.theme) })
          .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })

        FlashCard({ theme: this.theme, space: 2 }) {
          this.capabilityRow('✦', '星闪', this.settings.nearLinkSupported ? '此设备支持' : '此设备暂不支持',
            this.settings.nearLinkSupported ? statusText(this.theme, 'ok') : this.theme.themeMuted)
          this.capabilityRow('▣', '多设备适配', this.navigation.isExpandedWindow ? '大屏侧边导航' :
            (this.navigation.isMediumWindow ? '中屏响应式布局' : '手机紧凑布局'), statusText(this.theme, 'ok'))
          this.capabilityRow('●', '实况窗', this.settings.liveViewEnabled ? '接口可用，仍需真机准入' : '等待场景准入',
            this.settings.liveViewEnabled ? statusText(this.theme, 'ok') : statusText(this.theme, 'warn'))
          this.capabilityRow('◉', '闪控球 / 闪控窗', this.settings.floatingBallSupported ? '系统支持，等待权限准入' : '当前设备不支持',
            this.settings.floatingBallSupported ? statusText(this.theme, 'warn') : this.theme.themeMuted)
          this.capabilityRow('❖', '端侧智能体 A2A', this.settings.agentFrameworkSupported ? '设备支持，待场景接入' : '此设备暂不支持',
            this.settings.agentFrameworkSupported ? statusText(this.theme, 'ok') : this.theme.themeMuted)
          this.capabilityRow('⬡', '智能体运行时', this.settings.agentRuntimeSupported ? '设备支持，待场景接入' : '此设备暂不支持',
            this.settings.agentRuntimeSupported ? statusText(this.theme, 'ok') : this.theme.themeMuted)
          this.capabilityRow('▤', '沙箱共享导出', this.settings.fileSandboxShareSupported ? '已接入，受目录权限约束' : '此设备暂不支持',
            this.settings.fileSandboxShareSupported ? statusText(this.theme, 'ok') : this.theme.themeMuted)
          this.capabilityRow('♪', '通知设置半模态', this.settings.notificationSettingsSupported ? '已接入（设置页入口）' : '当前设备不支持',
            this.settings.notificationSettingsSupported ? statusText(this.theme, 'ok') : this.theme.themeMuted)
          this.capabilityRow('⌁', '碰一碰', '等待手动签名与 App Linking 配置', statusText(this.theme, 'warn'))
          this.capabilityRow('✧', 'Harmony Intelligence', '快速记录意图待平台审核', statusText(this.theme, 'warn'))
        }

        Column({ space: 8 }) {
          Text('为什么部分能力没有直接开启？').fontSize(TYPE_GROUP).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
          Text('实况窗、闪控球、碰一碰和小艺意图均涉及场景、签名、真机或平台审核。Flash 会在取得正式资格后启用，不申请与产品场景不符的受限权限。')
            .fontSize(TYPE_SECONDARY).fontColor(this.theme.themeMuted).lineHeight(20).width('100%')
        }.width('100%').padding(20).backgroundColor(this.theme.themeControl).borderRadius(RADIUS_CARD)
          .border({ width: 0.5, color: hairlineColor(this.theme) })
      }.width('100%').padding({ left: 20, right: 20, bottom: 30 })
    }.width('100%').layoutWeight(1)
  }

  @Builder
  private capabilityRow(icon: string, title: string, status: string, statusColor: string) {
    Row({ space: 12 }) {
      Text(icon).fontSize(TYPE_SECTION).fontColor(brandText(this.theme)).width(34).textAlign(TextAlign.Center)
      Text(title).fontSize(TYPE_BODY).fontColor(this.theme.themeText).layoutWeight(1)
      Text(status).fontSize(TYPE_CAPTION).fontColor(statusColor).textAlign(TextAlign.End).maxLines(2).width(150).lineHeight(16)
    }.width('100%').height(64)
  }

  build() {
    this.harmonyFeaturesPage()
  }
}
