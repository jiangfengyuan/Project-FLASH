import { shortDay } from '../data/DateUtils';
import { EmotionRecord, emotionEmoji, emotionName, SubEmotion, subEmotionName } from '../models/Models';
import { ThemeState, EmotionState, FeedbackState, DeleteKind } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
const BRAND = '#6C5CE7';

@Component
export struct EmotionPage {
  @ObjectLink theme: ThemeState;
  @ObjectLink emotion: EmotionState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;

  @Builder
  private emotionPage() {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 14 }) {
          Text(emotionEmoji(this.emotion.emotionLevel)).fontSize(64)
          Text(emotionName(this.emotion.emotionLevel)).fontSize(20).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
          Slider({ value: this.emotion.emotionLevel, min: -3, max: 3, step: 1, style: SliderStyle.OutSet })
            .blockColor(BRAND).selectedColor(BRAND).trackColor('#DCE6F7')
            .onChange((value: number) => this.emotion.emotionLevel = Math.round(value))
          Row() {
            Text('😡').layoutWeight(1).fontSize(18)
            Text('😐').layoutWeight(1).fontSize(18).textAlign(TextAlign.Center)
            Text('😍').layoutWeight(1).fontSize(18).textAlign(TextAlign.End)
          }.width('100%')
        }.width('100%').padding(20).backgroundColor(this.theme.themeSurface).borderRadius(20)

        if (this.emotion.emotionLevel < 0) {
          Column({ space: 10 }) {
            Text('更接近哪种感受？').fontSize(16).fontColor(this.theme.themeText).width('100%')
            Row({ space: 8 }) {
              this.subEmotionChip(SubEmotion.SAD)
              this.subEmotionChip(SubEmotion.ANGRY)
              this.subEmotionChip(SubEmotion.UNCOMFORTABLE)
            }.width('100%')
          }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(20)
        }

        TextArea({ placeholder: '想补充些什么？（可选）', text: this.emotion.emotionNote })
          .height(90).maxLength(2000).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
          .backgroundColor(this.theme.themeSurface).borderRadius(16)
          .onChange((value: string) => this.emotion.emotionNote = value.slice(0, 2000))
        Button('保存情绪').width('100%').height(46).backgroundColor(BRAND).onClick(() => requireActions(this.actions).emotionController.saveEmotion())

        if (this.emotion.emotions.length > 0) {
          Column({ space: 4 }) {
            Text('最近情绪').fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText).width('100%')
            ForEach(this.emotion.emotions.slice(0, 10), (item: EmotionRecord) => {
              Row({ space: 10 }) {
                Text(emotionEmoji(item.level)).fontSize(28)
                Column({ space: 2 }) {
                  Text(`${emotionName(item.level)} ${subEmotionName(item.subEmotion)}`).fontSize(14).fontColor(this.theme.themeText)
                  Text(`${shortDay(item.recordDate)} ${item.note ?? ''}`).fontSize(11).fontColor(this.theme.themeMuted).maxLines(1)
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                Button('删除', { type: ButtonType.Normal }).fontSize(11).fontColor('#B42318')
                  .backgroundColor(this.theme.themeDanger).onClick(() => this.feedback.destructive = { kind: DeleteKind.EMOTION, id: item.id })
              }.width('100%').padding({ top: 9, bottom: 9 })
            }, (item: EmotionRecord) => item.id)
          }.width('100%').padding(16).backgroundColor(this.theme.themeSurface).borderRadius(20)
        }
      }.width('100%').padding({ left: 16, right: 16, bottom: 30 })
    }.width('100%').layoutWeight(1)
  }

  @Builder
  private subEmotionChip(value: string) {
    Text(subEmotionName(value)).fontSize(13)
      .fontColor(this.emotion.selectedSubEmotion === value ? Color.White : this.theme.themeText)
      .textAlign(TextAlign.Center).layoutWeight(1).height(36).padding({ top: 9 })
      .backgroundColor(this.emotion.selectedSubEmotion === value ? BRAND : '#EEF2F8').borderRadius(18)
      .onClick(() => this.emotion.selectedSubEmotion = value)
  }

  build() {
    this.emotionPage()
  }
}

