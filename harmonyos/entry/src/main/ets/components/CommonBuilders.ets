import { localTimeHM } from '../data/DateUtils';
import { tr } from '../data/I18n';
import { paperShadow, TornCardEdge, FoldMarks, StickyUnderSheet, HandRing } from './Paper';
import { HapticEvent, playHaptic } from '../data/Haptics';
import { Category, colorTagName, LogItem } from '../models/Models';
import { NavigationState, ThemeState, FeedbackState } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  BRAND, RADIUS_CARD, RADIUS_FOCUS, RADIUS_ROW, RADIUS_STAMP, CARD_PADDING, TOUCH_MIN, FAB_SIZE, DOCK_HEIGHT, CAPTURE_BAR_HEIGHT,
  MOTION_PRESS, MOTION_FADE, CHIP_SELECTED, BODY_LINE_HEIGHT, displayFontFamily, chipSelected, chipSelectedText, brandFill, onBrandFill, tertiaryText, parchmentColor,
  TYPE_DISPLAY, TYPE_TITLE, TYPE_SECTION, TYPE_GROUP, TYPE_BODY, TYPE_SECONDARY, TYPE_CAPTION,
  motionDuration, supportsBlurMaterial, floatingSurface, hairlineColor, cardShadowColor, dockShadowColor, FAB_SHADOW,
  brandText, dangerText, importanceText, colorTagLabelColor, statusText, ELEVATED_SHADOW_RADIUS, ELEVATED_SHADOW_Y
} from './DesignTokens';

// 设计令牌统一在 ./DesignTokens 维护，此处 re-export 保持既有 import 路径不变。
export {
  BRAND, PAGE_BACKGROUND_LIGHT, PAGE_BACKGROUND_DARK, CARD_SURFACE_LIGHT, CARD_SURFACE_DARK,
  TEXT_PRIMARY_LIGHT, TEXT_PRIMARY_DARK, TEXT_MUTED_LIGHT, TEXT_MUTED_DARK,
  WEAK_SURFACE_LIGHT, CONTROL_SURFACE_DARK, TINT_SURFACE_LIGHT, TINT_SURFACE_DARK,
  DANGER_SURFACE_LIGHT, DANGER_SURFACE_DARK,
  CHIP_SELECTED, RADIUS_CARD, RADIUS_FOCUS, TOUCH_MIN, FAB_SIZE, DOCK_HEIGHT, DOCK_CLEARANCE,
  MOTION_PRESS, MOTION_FADE, MOTION_PAGE, DISPLAY_FONT_NAME,
  TYPE_DISPLAY, TYPE_TITLE, TYPE_SECTION, TYPE_GROUP, TYPE_BODY, TYPE_SECONDARY, TYPE_CAPTION, TYPE_HERO,
  DIALOG_WIDTH, DIALOG_WIDTH_FORM, DIALOG_WIDTH_PERCENT,
  CONTENT_MAX_WIDE, CONTENT_MAX_MEDIUM, CONTENT_MAX_CENTERED,
  motionDuration,
  supportsBlurMaterial, floatingSurface, hairlineColor, cardShadowColor, dockShadowColor, FAB_SHADOW,
  brandText, dangerText, importanceText, dangerButtonColor, successText, successFill,
  scrimColor, toastSurface, toastLevelColor, iconSemantic, fabOptionColor, statLineColor,
  emotionColor, statusText, colorTagLabelColor, colorTagFill, moodColor,
  brandFill, onBrandFill, chipSelected, chipSelectedText, tertiaryText, parchmentColor, displayFontFamily, statFontFamily,
  pageGutter, setFontScale, CARD_PADDING, RADIUS_FIELD, RADIUS_ROW, RADIUS_CARD_SMALL, BODY_LINE_HEIGHT, CAPTURE_BAR_HEIGHT,
  CARD_SHADOW_RADIUS, CARD_SHADOW_Y, ELEVATED_SHADOW_RADIUS, ELEVATED_SHADOW_Y
} from './DesignTokens';
export { setReduceMotionEnabled, isReduceMotionEnabled } from '../state/FeatureStates';
export { TornDivider, TornSectionBreak, HandUnderline, HandRing, TornCardEdge, FoldMarks, StickyUnderSheet, paperShadow } from './Paper';

@Builder
export function PageHeader(theme: ThemeState, title: string, subtitle: string) {
    Column({ space: 4 }) {
      Text(title).fontSize(TYPE_TITLE).fontFamily(displayFontFamily()).fontWeight(FontWeight.Medium).fontColor(theme.themeText).width('100%')
      Text(subtitle).fontSize(TYPE_SECONDARY).fontColor(theme.themeMuted).lineHeight(19).width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 20, right: 20, top: 18, bottom: 12 })
  }

// 详情页页头：自绘返回栏的统一实现（Index 详情路由使用）。
@Builder
export function DetailHeader(theme: ThemeState, title: string, onBack: () => void) {
    Row({ space: 10 }) {
      Button(tr('‹ 返回'), { type: ButtonType.Normal }).height(TOUCH_MIN).fontColor(brandText(theme)).backgroundColor(Color.Transparent)
        .onClick(onBack)
      Text(title).fontSize(TYPE_SECTION).fontFamily(displayFontFamily()).fontWeight(FontWeight.Medium).fontColor(theme.themeText)
    }.width('100%').height(60).padding({ left: 8, right: 16 })
  }

// 三态套件：空态/加载/错误共用同一卡片容器语言。actionLabel 为空时不渲染操作按钮。
@Builder
export function EmptyState(theme: ThemeState, emoji: string, text: string, actionLabel: string = '', onAction: () => void = () => {}) {
    Column({ space: 12 }) {
      Stack() {
        HandRing({ seed: text, tint: brandText(theme), sizeVp: 76 })
        Text(emoji).fontSize(TYPE_DISPLAY - 6)
      }
      Text(text).fontSize(TYPE_GROUP).fontFamily(displayFontFamily()).fontColor(theme.themeText).textAlign(TextAlign.Center)
      if (actionLabel !== '') {
        Button(actionLabel).height(TOUCH_MIN).fontColor(onBrandFill(theme)).backgroundColor(brandFill(theme)).margin({ top: 4 })
          .onClick(onAction)
      }
    }.width('100%').padding(24).justifyContent(FlexAlign.Center)
  }

@Builder
export function LoadingState(theme: ThemeState, text: string) {
    Column({ space: 12 }) {
      LoadingProgress().width(36).height(36).color(brandText(theme))
      Text(text).fontSize(TYPE_BODY).fontColor(theme.themeMuted)
    }.width('100%').padding(24).justifyContent(FlexAlign.Center).backgroundColor(theme.themeSurface).borderRadius(RADIUS_CARD)
      .border({ width: 0.5, color: hairlineColor(theme) })
  }

@Builder
export function ErrorState(theme: ThemeState, text: string, onRetry: () => void) {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle')).fontSize(TYPE_DISPLAY).fontColor([dangerText(theme)])
      Text(text).fontSize(TYPE_BODY).fontColor(theme.themeMuted).textAlign(TextAlign.Center)
      Button(tr('重试')).height(TOUCH_MIN).fontColor(onBrandFill(theme)).backgroundColor(brandFill(theme)).margin({ top: 4 })
        .onClick(onRetry)
    }.width('100%').padding(24).justifyContent(FlexAlign.Center).backgroundColor(theme.themeSurface).borderRadius(RADIUS_CARD)
      .border({ width: 0.5, color: hairlineColor(theme) })
  }

@Builder
export function FormGroup(theme: ThemeState, title: string) {
  Text(title).fontSize(TYPE_GROUP).fontWeight(FontWeight.Medium).fontColor(theme.themeText).width('100%')
}

@Builder
export function FormRow(theme: ThemeState, label: string, value: string) {
  Row({ space: 12 }) {
    Text(label).fontSize(TYPE_BODY).fontColor(theme.themeMuted)
    Blank()
    Text(value).fontSize(TYPE_BODY).fontColor(theme.themeText).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
  }.width('100%').height(TOUCH_MIN)
}

@Builder
export function FilterChip(theme: ThemeState, label: string, selected: boolean, onSelect: () => void) {
  Text(label)
    .fontSize(TYPE_SECONDARY)
    .fontColor(selected ? chipSelectedText(theme) : theme.themeText)
    .fontWeight(selected ? FontWeight.Medium : FontWeight.Regular)
    .textAlign(TextAlign.Center)
    .padding({ left: 16, right: 16 })
    .height(TOUCH_MIN)
    .backgroundColor(selected ? chipSelected(theme) : theme.themeSurface)
    .border({ width: selected ? 0 : 0.75, color: hairlineColor(theme) })
    .borderRadius(TOUCH_MIN / 2)
    .accessibilitySelected(selected)
    // 按下轻微下陷（拟物按压）。
    .stateStyles({
      normal: { .scale({ x: 1, y: 1 }) },
      pressed: { .scale({ x: 0.97, y: 0.97 }) }
    })
    .onClick(() => {
      playHaptic(HapticEvent.SELECTION);
      onSelect();
    })
    .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
}

@Builder
export function SegmentedControl(theme: ThemeState, options: string[], selectedIndex: number, onSelect: (index: number) => void) {
  Row({ space: 4 }) {
    ForEach(options, (option: string, index: number) => {
      Row() {
        Text(option)
          .fontSize(TYPE_SECONDARY)
          .fontColor(index === selectedIndex ? chipSelectedText(theme) : theme.themeMuted)
          .fontWeight(index === selectedIndex ? FontWeight.Medium : FontWeight.Regular)
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(1)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(index === selectedIndex ? chipSelected(theme) : Color.Transparent)
      .borderRadius(18)
      .stateStyles({
        normal: { .opacity(1) },
        pressed: { .opacity(0.7) }
      })
      .accessibilitySelected(index === selectedIndex)
      .onClick(() => {
        playHaptic(HapticEvent.SELECTION);
        onSelect(index);
      })
    }, (option: string) => option)
  }
  .width('100%')
  .padding(4)
  .backgroundColor(theme.themeControl)
  .borderRadius(22)
  .border({ width: 0.5, color: hairlineColor(theme) })
  .animation({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut })
}

@Builder
export function DockItem(theme: ThemeState, icon: Resource, activeIcon: Resource, label: string, selected: boolean, onSelect: () => void, badge: number = 0) {
  Column() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 4 }) {
        SymbolGlyph(selected ? activeIcon : icon)
          .fontSize(22)
          .fontColor([selected ? brandText(theme) : theme.themeMuted])
        Text(label)
          .fontSize(TYPE_CAPTION)
          .fontColor(selected ? brandText(theme) : theme.themeMuted)
          .fontWeight(selected ? FontWeight.Medium : FontWeight.Regular)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      // 未读角标（Idea Reminder）：BRAND 底白字深浅模式均 ≥4.5:1。
      if (badge > 0) {
        Text(badge > 99 ? '99+' : `${badge}`)
          .fontSize(TYPE_CAPTION)
          .fontColor(onBrandFill(theme))
          .textAlign(TextAlign.Center)
          .constraintSize({ minWidth: 18 })
          .height(18)
          .padding({ left: 4, right: 4 })
          .backgroundColor(brandFill(theme))
          .borderRadius(9)
          .translate({ x: 14, y: -6 })
      }
    }
    .stateStyles({
      normal: { .scale({ x: 1, y: 1 }) },
      pressed: { .scale({ x: 0.92, y: 0.92 }) }
    })
    .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
  }
  .layoutWeight(1)
  .height(52)
  .justifyContent(FlexAlign.Center)
  .backgroundColor(selected ? parchmentColor(theme) : Color.Transparent)
  .borderRadius(26)
  .accessibilityGroup(true)
  .accessibilityText(label + (selected ? tr('，已选中') : '') + (badge > 0 ? tr('，{0} 条未读灵感', badge) : ''))
  .onClick(onSelect)
  .animation({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut })
}

@Builder
export function FlashDockBar(theme: ThemeState, navigation: NavigationState, onSelect: (index: number) => void, recordsBadge: number = 0) {
  Row({ space: 4 }) {
    DockItem(theme, $r('sys.symbol.house'), $r('sys.symbol.house_fill'), tr('此刻'), navigation.activeTab === 0, () => onSelect(0))
    DockItem(theme, $r('sys.symbol.doc_text'), $r('sys.symbol.doc_text_fill'), tr('记录'), navigation.activeTab === 1, () => onSelect(1), recordsBadge)
    DockItem(theme, $r('sys.symbol.face_smiling'), $r('sys.symbol.face_smiling'), tr('情绪'), navigation.activeTab === 2, () => onSelect(2))
    DockItem(theme, $r('sys.symbol.clock_arrow_2_circlepath'), $r('sys.symbol.clock_arrow_2_circlepath_fill'), tr('回顾'), navigation.activeTab === 3, () => onSelect(3))
    DockItem(theme, $r('sys.symbol.gearshape'), $r('sys.symbol.gearshape_fill'), tr('设置'), navigation.activeTab === 4, () => onSelect(4))
  }
  .width('100%')
  .height(DOCK_HEIGHT)
  .padding({ left: 8, right: 8 })
  .backgroundColor(floatingSurface(theme))
  .borderRadius(RADIUS_FOCUS)
  .border({ width: 0.75, color: hairlineColor(theme) })
  .shadow({ radius: ELEVATED_SHADOW_RADIUS, color: dockShadowColor(theme), offsetY: ELEVATED_SHADOW_Y })
}

// 常驻快速记录条（窄屏，底栏上方）：对齐 iOS 26 标签栏配件。
@Builder
export function QuickCaptureBar(theme: ThemeState, onTap: () => void) {
  Row({ space: 12 }) {
    SymbolGlyph($r('sys.symbol.square_and_pencil')).fontSize(18).fontColor([brandText(theme)])
    Text(tr('现在想记录什么？'))
      .fontSize(TYPE_BODY).fontFamily(displayFontFamily()).fontColor(theme.themeMuted)
      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
  }
  .width('100%')
  .height(CAPTURE_BAR_HEIGHT)
  .padding({ left: 20, right: 20 })
  .backgroundColor(floatingSurface(theme))
  .borderRadius(RADIUS_FOCUS)
  .border({ width: 0.75, color: hairlineColor(theme) })
  .shadow({ radius: ELEVATED_SHADOW_RADIUS, color: dockShadowColor(theme), offsetY: ELEVATED_SHADOW_Y })
  .accessibilityGroup(true)
  .accessibilityText(tr('快速记录'))
  .stateStyles({
    normal: { .scale({ x: 1, y: 1 }) },
    pressed: { .scale({ x: 0.98, y: 0.98 }) }
  })
  .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
  .onClick(onTap)
}

// 宽屏（≥ 840vp）右下角悬浮按钮：直接打开快速记录。
@Builder
export function FabButton(theme: ThemeState, onTap: () => void) {
  Stack() {
    Row().width(22).height(2.5).borderRadius(2).backgroundColor(onBrandFill(theme))
    Row().width(2.5).height(22).borderRadius(2).backgroundColor(onBrandFill(theme))
  }
  .width(FAB_SIZE)
  .height(FAB_SIZE)
  .borderRadius(FAB_SIZE / 2)
  .backgroundColor(brandFill(theme))
  .accessibilityText(tr('快速记录'))
  .shadow({ radius: ELEVATED_SHADOW_RADIUS, color: dockShadowColor(theme), offsetY: ELEVATED_SHADOW_Y })
  .stateStyles({
    normal: { .scale({ x: 1, y: 1 }) },
    pressed: { .scale({ x: 0.92, y: 0.92 }) }
  })
  .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
  .onClick(onTap)
}

// 印章徽章：小方框 + 标签色细描边 + 极淡底，替代胶囊色块。
@Builder
export function StampBadge(theme: ThemeState, tag: string) {
  Text(colorTagName(tag))
    .fontSize(TYPE_CAPTION)
    .fontColor(colorTagLabelColor(theme, tag))
    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
    .borderRadius(RADIUS_STAMP)
    .border({ width: 1, color: colorTagLabelColor(theme, tag) })
}

// 日历等紧凑位置的记录行：点按进入编辑，长按打开菜单。
@Builder
export function RecordRow(theme: ThemeState, feedback: FeedbackState, actions: PageActions, item: LogItem) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        StampBadge(theme, item.colorTag)
        if (item.importance > 0) {
          Text('!'.repeat(item.importance)).fontSize(TYPE_CAPTION).fontWeight(FontWeight.Bold).fontColor(importanceText(theme))
        }
        Blank()
        Text(localTimeHM(item.createdAt)).fontSize(TYPE_CAPTION).fontColor(tertiaryText(theme))
      }.width('100%')
      Text(item.content).fontSize(TYPE_BODY).fontColor(theme.themeText).lineHeight(BODY_LINE_HEIGHT).maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
    }
    .width('100%').padding({ top: 8, bottom: 8 })
    .stateStyles({
      normal: { .opacity(1) },
      pressed: { .opacity(0.85) }
    })
    .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
    .onClick(() => actions.logsController.openLog(item))
  }

// 全宽记录卡：此刻页「最近闪念」、记录页、日志流共用。点按进入编辑，长按打开菜单（编辑 / 收藏 /
// 转为任务 / 删除）；sticky 时身后错开一张便签底页。
@Component
export struct RecordCard {
  @ObjectLink theme: ThemeState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;
  @Prop item: LogItem = { id: '', content: '', colorTag: '', category: '', importance: 0, createdAt: '', recordDate: '' };
  @Prop unread: boolean = false;
  @Prop sticky: boolean = false;
  @Prop selected: boolean = false;
  @Prop selecting: boolean = false;

  @Builder
  private contextMenu() {
    Menu() {
      MenuItem({ content: tr('编辑') }).onClick(() => requireActions(this.actions).logsController.openLog(this.item))
      MenuItem({ content: this.item.isFavorite === true ? tr('取消收藏') : tr('收藏') })
        .onClick(() => requireActions(this.actions).logsController.toggleFavorite(this.item))
      if (this.item.category === Category.IDEA) {
        MenuItem({ content: tr('转为任务') })
          .onClick(() => requireActions(this.actions).calendarController.openTaskFromIdea(this.item.id, this.item.content))
      }
      MenuItem({ content: tr('删除') }).onClick(() => requireActions(this.actions).logsController.deleteWithUndo(this.item))
    }
  }

  build() {
    Stack() {
      if (this.sticky) {
        StickyUnderSheet({ theme: this.theme, seed: this.item.id })
      }
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          StampBadge(this.theme, this.item.colorTag)
          if (this.unread) {
            Text(tr('未读')).fontSize(TYPE_CAPTION).fontWeight(FontWeight.Bold).fontColor(statusTextIdea(this.theme))
          }
          if (this.item.importance > 0) {
            Text('!'.repeat(this.item.importance)).fontSize(TYPE_CAPTION).fontWeight(FontWeight.Bold)
              .fontColor(importanceText(this.theme))
          }
          Blank()
          if (this.item.isFavorite === true) {
            SymbolGlyph($r('sys.symbol.star_fill')).fontSize(13).fontColor([statusTextIdea(this.theme)])
              .accessibilityText(tr('已收藏'))
          }
          Text(`${this.item.recordDate} ${localTimeHM(this.item.createdAt)}`)
            .fontSize(TYPE_CAPTION).fontColor(tertiaryText(this.theme))
        }.width('100%')
        Text(this.item.content)
          .fontSize(TYPE_BODY).fontColor(this.theme.themeText).lineHeight(BODY_LINE_HEIGHT).width('100%')
          .maxLines(this.sticky ? 3 : 6).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(this.theme.themeSurface)
      .borderRadius(RADIUS_ROW)
      .border({ width: this.selected ? 1.5 : 0.75, color: this.selected ? brandText(this.theme) : hairlineColor(this.theme) })
      .shadow(paperShadow(this.theme))
    }
    .width('100%')
    .stateStyles({
      normal: { .opacity(1) },
      pressed: { .opacity(0.85) }
    })
    .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
    .accessibilityGroup(true)
    .onClick(() => {
      const logs = requireActions(this.actions).logsController;
      if (this.selecting) logs.toggleSelected(this.item.id);
      else logs.openLog(this.item);
    })
    .bindContextMenu(this.contextMenu, ResponseType.LongPress)
  }
}

function statusTextIdea(theme: ThemeState): string {
  return statusText(theme, 'warn');
}

// 通用纸卡：全站卡片四件套（圆角 + 细边 + 弥散暖影 + 卡面色）的唯一实现。
// frayed：底边撕开；folded：折叠信纸的折痕与折角（压在内容之下）。
@Component
export struct FlashCard {
  @ObjectLink theme: ThemeState;
  radius: number = RADIUS_CARD;
  contentPadding: number = CARD_PADDING;
  space: number = 0;
  seed: string = 'card';
  frayed: boolean = false;
  folded: boolean = false;
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {}

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.folded) {
        FoldMarks({ theme: this.theme })
      }
      Column({ space: this.space }) {
        this.content()
      }
      .width('100%')
      .padding({
        left: this.contentPadding, right: this.contentPadding, top: this.contentPadding,
        bottom: this.frayed ? this.contentPadding + 6 : this.contentPadding
      })
      if (this.frayed) {
        TornCardEdge({ theme: this.theme, seed: this.seed })
      }
    }
    .width('100%')
    .backgroundColor(this.theme.themeSurface)
    .borderRadius(this.frayed ? { topLeft: this.radius, topRight: this.radius } : this.radius)
    .border({ width: 0.75, color: hairlineColor(this.theme) })
    .shadow(paperShadow(this.theme))
    .clip(this.folded)
  }
}
