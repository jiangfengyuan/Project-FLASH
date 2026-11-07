import { common } from '@kit.AbilityKit';
import { Category, COLOR_TAGS, colorTagName, LogItem } from '../models/Models';
import { shareLog, systemShareSupported } from '../data/ShareService';
import { tr } from '../data/I18n';
import { HapticEvent, playHaptic } from '../data/Haptics';
import { NavigationState, ThemeState, LogsState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  FilterChip, FormGroup, RADIUS_CARD, SegmentedControl, cardShadowColor, dangerText, brandFill, onBrandFill, brandText, BODY_LINE_HEIGHT,
  floatingSurface, hairlineColor, supportsBlurMaterial, scrimColor,
  DIALOG_WIDTH_FORM, DIALOG_WIDTH_PERCENT, TYPE_GROUP, TYPE_BODY, TYPE_SECONDARY, TYPE_CAPTION
} from './CommonBuilders';

interface ImportanceOption {
  value: number;
  label: string;
}

const IMPORTANCE_OPTIONS: ImportanceOption[] = [
  { value: 0, label: '无' },
  { value: 1, label: '!' },
  { value: 2, label: '!!' },
  { value: 3, label: '!!!' },
  { value: 4, label: '!!!!' }
];

@Component
export struct EditLogDialog {
  @ObjectLink navigation: NavigationState;
  @ObjectLink theme: ThemeState;
  @ObjectLink logs: LogsState;
  actions?: PageActions;

  private close(): void {
    requireActions(this.actions).logsController.requestCloseEdit();
  }

  private current(): LogItem | undefined {
    return this.logs.logs.find((item: LogItem) => item.id === this.logs.editingLogId);
  }

  private convertToTask(): void {
    const item = this.current();
    if (!item) return;
    requireActions(this.actions).calendarController.openTaskFromIdea(item.id, item.content);
  }

  private share(): void {
    const item = this.current();
    if (!item) return;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    shareLog(context, item).catch((error: Error) => {
      requireActions(this.actions).controller.runtime.notify(error.message || tr('分享失败'), 'error');
    });
  }

  private remove(): void {
    const item = this.current();
    if (!item) return;
    requireActions(this.actions).logsController.closeEdit();
    playHaptic(HapticEvent.LIGHT);
    requireActions(this.actions).logsController.deleteWithUndo(item);
  }

  private async save(): Promise<void> {
    await requireActions(this.actions).logsController.saveEditedLog();
    if (this.logs.editingLogId === '') playHaptic(HapticEvent.SUCCESS);
  }

  @Builder
  private editLogDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column().width('100%').height('100%').backgroundColor(scrimColor(this.theme))
        .backdropBlur(supportsBlurMaterial() ? 12 : 0)
        .onClick(() => this.close())
      Scroll() {
        Column({ space: 14 }) {
          Row() {
            Button(tr('关闭'), { type: ButtonType.Normal })
              .fontSize(TYPE_BODY).fontColor(this.theme.themeMuted).backgroundColor(Color.Transparent).height(44)
              .onClick(() => this.close())
            Blank()
            Text(this.logs.editCategory === Category.IDEA ? tr('编辑灵感') : tr('编辑记录')).fontSize(TYPE_GROUP).fontWeight(FontWeight.Medium).fontColor(this.theme.themeText)
            Blank()
            Button(this.logs.busy ? tr('保存中…') : tr('保存'), { type: ButtonType.Normal })
              .fontSize(TYPE_BODY).fontColor(onBrandFill(this.theme)).backgroundColor(brandFill(this.theme)).height(44)
              .enabled(!this.logs.busy && requireActions(this.actions).logsController.editValidation() === '')
              .onClick(() => this.save())
          }.width('100%')

          if (this.logs.editDiscard) {
            Text(tr('放弃未保存的修改？')).fontSize(TYPE_BODY).fontColor(this.theme.themeText)
            Row({ space: 12 }) {
              Button(tr('继续编辑')).height(44).onClick(() => this.logs.editDiscard = false)
              Button(tr('放弃修改')).height(44).onClick(() => requireActions(this.actions).logsController.closeEdit())
            }
          }
          if (this.logs.editError || requireActions(this.actions).logsController.editValidation()) {
            Text(this.logs.editError || requireActions(this.actions).logsController.editValidation())
              .fontSize(TYPE_SECONDARY).fontColor(dangerText(this.theme)).width('100%')
          }

          FormGroup(this.theme, tr('正文与类型'))
          TextArea({ placeholder: tr('记录内容'), text: this.logs.editText })
            .height(150).lineHeight(BODY_LINE_HEIGHT).fontColor(this.theme.themeText).placeholderColor(this.theme.themeMuted)
            .backgroundColor(this.theme.themeControl).borderRadius(14)
            .onChange((value: string) => this.logs.editText = value)
          Text(`${this.logs.editText.length}/100000`).fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted).width('100%').textAlign(TextAlign.End)
          SegmentedControl(this.theme, [tr('日志'), tr('灵感')], this.logs.editCategory === Category.IDEA ? 1 : 0,
            (index: number) => this.logs.editCategory = index === 1 ? Category.IDEA : Category.LOG)

          FormGroup(this.theme, tr('标签'))
          Scroll() {
            Row({ space: 8 }) {
              ForEach(COLOR_TAGS, (tag: string) => {
                FilterChip(this.theme, colorTagName(tag), this.logs.editTag === tag,
                  () => this.logs.editTag = tag)
              }, (tag: string) => tag)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')

          FormGroup(this.theme, tr('重要度与日期'))
          Column({ space: 8 }) {
            // 重要度选项对齐 Android RecordDetailScreen：无 / !! / !!! / !!!!（0/2/3/4）。
            Row({ space: 8 }) {
              ForEach(IMPORTANCE_OPTIONS, (option: ImportanceOption) => {
                FilterChip(this.theme, tr(option.label), this.logs.editImportance === option.value,
                  () => this.logs.editImportance = option.value)
              }, (option: ImportanceOption) => `${option.value}`)
            }.width('100%')
            TextInput({ placeholder: tr('记录日期 YYYY-MM-DD'), text: this.logs.editDate })
              .fontColor(this.theme.themeText).backgroundColor(this.theme.themeControl).height(44)
              .onChange((value: string) => this.logs.editDate = value)
          }.width('100%')
          Text(tr('日期决定日历归属与回顾统计；重要度用于筛选与详情展示。'))
            .fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted).width('100%')

          Row() {
            Text(tr('收藏')).fontSize(TYPE_BODY).fontColor(this.theme.themeText).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.logs.editFavorite })
              .onChange((value: boolean) => this.logs.editFavorite = value)
          }.width('100%')

          // 转为任务、系统分享与删除（分享是 HarmonyOS 保留的能力）。
          Row({ space: 8 }) {
            if (this.logs.editCategory === Category.IDEA) {
              Button(tr('转为任务'), { type: ButtonType.Normal }).height(44).fontSize(TYPE_SECONDARY)
                .fontColor(brandText(this.theme)).backgroundColor(this.theme.themeControl)
                .onClick(() => this.convertToTask())
            }
            if (systemShareSupported()) {
              Button(tr('分享'), { type: ButtonType.Normal }).height(44).fontSize(TYPE_SECONDARY)
                .fontColor(brandText(this.theme)).backgroundColor(this.theme.themeControl)
                .onClick(() => this.share())
            }
            Blank()
            Button(tr('删除'), { type: ButtonType.Normal }).height(44).fontSize(TYPE_SECONDARY)
              .fontColor(dangerText(this.theme)).backgroundColor(this.theme.themeControl)
              .onClick(() => this.remove())
          }.width('100%')
        }
        .width('100%')
        .enabled(!this.logs.busy)
        .padding(22)
      }.width(this.navigation.isMediumWindow ? DIALOG_WIDTH_FORM : DIALOG_WIDTH_PERCENT).constraintSize({ maxHeight: '90%' })
        .backgroundColor(floatingSurface(this.theme))
        .backgroundBlurStyle(supportsBlurMaterial() ? BlurStyle.COMPONENT_ULTRA_THICK : BlurStyle.NONE)
        .borderRadius(RADIUS_CARD)
        .border({ width: 0.5, color: hairlineColor(this.theme) })
        .shadow({ radius: 24, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 10 })
    }.width('100%').height('100%')
  }

  build() {
    this.editLogDialog()
  }
}
