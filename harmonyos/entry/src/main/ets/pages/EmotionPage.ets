import { shortDay } from '../data/DateUtils';
import { EmotionRecord, emotionName, SubEmotion, subEmotionName } from '../models/Models';
import { ThemeState, EmotionState, FeedbackState, DeleteKind } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import { BRAND, RADIUS_CARD, brandText, cardShadowColor, dangerText, hairlineColor } from '../components/CommonBuilders';

@Component
export struct EmotionPage {
  @ObjectLink theme: ThemeState;
  @ObjectLink emotion: EmotionState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;

  private emotionSymbol(level: number): Resource {
    if (level < 0) return $r('sys.symbol.face_sading');
    if (level > 0) return $r('sys.symbol.face_laughing');
    return $r('sys.symbol.face_smiling');
  }

  private emotionColor(level: number): string {
    if (level < 0) return '#E36570';
    if (level > 0) return '#1E9E62';
    return '#8A94A6';
  }

  @Builder
  private emotionPage() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 14 }) {
          SymbolGlyph(this.emotionSymbol(this.emotion.emotionLevel))
            .fontSize(64)
            .fontColor([this.emotionColor(this.emotion.emotionLevel)])
          Text(emotionName(this.emotion.emotionLevel)).fontSize(20).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
          Slider({ value: this.emotion.emotionLevel, min: -3, max: 3, step: 1, style: SliderStyle.OutSet })
            .blockColor(brandText(this.theme)).selectedColor(brandText(this.theme)).trackColor(this.theme.themeControl)
            .onChange((value: number) => this.emotion.emotionLevel = Math.round(value))
          Row() {
            Row() {
              SymbolGlyph($r('sys.symbol.face_sading')).fontSize(18).fontColor(['#E36570'])
            }.layoutWeight(1).justifyContent(FlexAlign.Start)
            Row() {
              SymbolGlyph($r('sys.symbol.face_smiling')).fontSize(18).fontColor(['#8A94A6'])
            }.layoutWeight(1).justifyContent(FlexAlign.Center)
            Row() {
              SymbolGlyph($r('sys.symbol.face_laughing')).fontSize(18).fontColor(['#1E9E62'])
            }.layoutWeight(1).justifyContent(FlexAlign.End)
          }.width('100%')
        }.width('100%').padding(20).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)
          .border({ width: 0.5, color: hairlineColor(this.theme) })
          .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })

        if (this.emotion.emotionLevel < 0) {
          Column({ space: 12 }) {
            Text('更接近哪种感受？').fontSize(16).fontColor(this.theme.themeText).width('100%')
            Row({ space: 8 }) {
              this.subEmotionChip(SubEmotion.SAD)
              this.subEmotionChip(SubEmotion.ANGRY)
              this.subEmotionChip(SubEmotion.UNCOMFORTABLE)
            }.width('100%')
          }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)
          .border({ width: 0.5, color: hairlineColor(this.theme) })
          .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })
        }

        TextArea({ placeholder: '想补充些什么？（可选）', text: this.emotion.emotionNote })
          .height(90).maxLength(2000).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
          .backgroundColor(this.theme.themeSurface).borderRadius(16)
          .border({ width: 0.5, color: hairlineColor(this.theme) })
          .onChange((value: string) => this.emotion.emotionNote = value.slice(0, 2000))
        Button('保存情绪').width('100%').height(46).backgroundColor(BRAND).onClick(() => requireActions(this.actions).emotionController.saveEmotion())

        if (this.emotion.emotions.length > 0) {
          Column({ space: 4 }) {
            Text('最近情绪').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
            ForEach(this.emotion.emotions.slice(0, 10), (item: EmotionRecord) => {
              Row({ space: 12 }) {
                SymbolGlyph(this.emotionSymbol(item.level))
                  .fontSize(24)
                  .fontColor([this.emotionColor(item.level)])
                Column({ space: 4 }) {
                  Text(`${emotionName(item.level)} ${subEmotionName(item.subEmotion)}`).fontSize(14).fontColor(this.theme.themeText)
                  Text(`${shortDay(item.recordDate)} ${item.note ?? ''}`).fontSize(11).fontColor(this.theme.themeMuted).maxLines(1)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Button('删除', { type: ButtonType.Normal }).fontSize(11).fontColor(dangerText(this.theme))
                  .backgroundColor(this.theme.themeDanger).onClick(() => this.feedback.destructive = { kind: DeleteKind.EMOTION, id: item.id })
              }.width('100%').padding({ top: 8, bottom: 8 })
            }, (item: EmotionRecord) => item.id)
          }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(RADIUS_CARD)
          .border({ width: 0.5, color: hairlineColor(this.theme) })
          .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })
        }
      }.width('100%').padding({ left: 16, right: 16, bottom: 30 })
    }.width('100%').layoutWeight(1)
  }

  @Builder
  private subEmotionChip(value: string) {
    Text(subEmotionName(value)).fontSize(13)
      .fontColor(this.emotion.selectedSubEmotion === value ? Color.White : this.theme.themeText)
      .textAlign(TextAlign.Center).layoutWeight(1).height(44)
      .backgroundColor(this.emotion.selectedSubEmotion === value ? BRAND : this.theme.themeControl).borderRadius(22)
      .stateStyles({
        normal: { .opacity(1) },
        pressed: { .opacity(0.7) }
      })
      .animation({ duration: 120, curve: Curve.EaseOut })
      .onClick(() => this.emotion.selectedSubEmotion = value)
  }

  build() {
    this.emotionPage()
  }
}
