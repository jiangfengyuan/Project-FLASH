import { tr } from '../data/I18n';
import { HapticEvent, playHaptic } from '../data/Haptics';
import { ThemeState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  HandRing, brandFill, onBrandFill, brandText, displayFontFamily, hairlineColor, iconSemantic, TYPE_TITLE, TYPE_BODY
} from './CommonBuilders';

interface WelcomeCard {
  id: number;
  emoji: string;
  title: string;
  subtitle: string;
  tint: string;
}

/** 欢迎页（对齐 iOS）：首次启动三页横滑，手绘圈图标；「开始使用」后不再出现。 */
@Component
export struct WelcomeOverlay {
  @ObjectLink theme: ThemeState;
  actions?: PageActions;
  @State private page: number = 0;
  private swiper: SwiperController = new SwiperController();

  private cards(): WelcomeCard[] {
    return [
      { id: 0, emoji: '⚡', title: tr('欢迎来到 Flash'), subtitle: tr('一闪而过的想法，值得被记住'), tint: brandText(this.theme) },
      { id: 1, emoji: '📝', title: tr('随手记录'), subtitle: tr('日志与灵感，一键即达'), tint: iconSemantic(this.theme, 'calendar') },
      { id: 2, emoji: '🙂', title: tr('情绪觉察'), subtitle: tr('七级情绪记录，看见自己的变化'), tint: iconSemantic(this.theme, 'emotion') }
    ];
  }

  build() {
    Column() {
      Swiper(this.swiper) {
        ForEach(this.cards(), (card: WelcomeCard) => {
          Column({ space: 24 }) {
            Stack() {
              HandRing({ seed: card.title, tint: card.tint, sizeVp: 128 })
              Text(card.emoji).fontSize(48).accessibilityLevel('no')
            }
            Text(card.title).fontSize(TYPE_TITLE).fontFamily(displayFontFamily()).fontWeight(FontWeight.Medium)
              .fontColor(this.theme.themeText).textAlign(TextAlign.Center)
            Text(card.subtitle).fontSize(TYPE_BODY).fontColor(this.theme.themeMuted).textAlign(TextAlign.Center).lineHeight(24)
          }.width('100%').height('100%').justifyContent(FlexAlign.Center).padding(32)
        }, (card: WelcomeCard) => `${card.id}`)
      }
      .layoutWeight(1)
      .loop(false)
      .indicator(new DotIndicator().selectedColor(brandText(this.theme)).color(hairlineColor(this.theme)))
      .onChange((index: number) => {
        this.page = index;
        playHaptic(HapticEvent.SELECTION);
      })
      Button(this.page >= 2 ? tr('开始使用') : tr('下一步'))
        .width('88%').height(46).margin({ top: 16, bottom: 32 })
        .fontColor(onBrandFill(this.theme)).backgroundColor(brandFill(this.theme))
        .onClick(() => {
          if (this.page >= 2) requireActions(this.actions).controller.finishWelcome();
          else this.swiper.showNext();
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.themeBackground)
    .hitTestBehavior(HitTestMode.Block)
  }
}
