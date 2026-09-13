import { shortDay } from '../data/DateUtils';
import { Category, colorTagColor, colorTagName, LogItem } from '../models/Models';
import { ThemeState, FeedbackState, DeleteKind } from '../state/FeatureStates';
import { PageActions } from '../state/PageActions';
const BRAND = '#6C5CE7';

@Builder
export function PageHeader(theme: ThemeState, title: string, subtitle: string) {
    Column({ space: 3 }) {
      Text(title).fontSize(28).fontWeight(FontWeight.Bold).fontColor(theme.themeText).width('100%')
      Text(subtitle).fontSize(13).fontColor(theme.themeMuted).width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 20, right: 20, top: 18, bottom: 12 })
  }

@Builder
export function EmptyState(theme: ThemeState, emoji: string, text: string) {
    Column({ space: 8 }) {
      Text(emoji).fontSize(34)
      Text(text).fontSize(14).fontColor(theme.themeMuted)
    }.width('100%').height(130).justifyContent(FlexAlign.Center).backgroundColor(theme.themeSurface).borderRadius(20)
  }

@Builder
export function RecordRow(theme: ThemeState, feedback: FeedbackState, actions: PageActions, item: LogItem) {
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
        Text(item.content).fontSize(15).fontColor(theme.themeText).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${shortDay(item.recordDate)} · ${item.createdAt.slice(11, 16)}`).fontSize(11).fontColor(theme.themeMuted)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column({ space: 5 }) {
        Button('编辑', { type: ButtonType.Normal })
          .fontSize(11).fontColor(BRAND).backgroundColor(theme.themeTint).height(28)
          .onClick(() => actions.logsController.startEditLog(item))
        Button('删除', { type: ButtonType.Normal })
          .fontSize(11).fontColor('#B42318').backgroundColor(theme.themeDanger).height(28)
          .onClick(() => feedback.destructive = { kind: DeleteKind.LOG, id: item.id })
      }
    }.width('100%').padding({ top: 10, bottom: 10 })
  }


