import { shortDay } from '../data/DateUtils';
import { Category, colorTagColor, colorTagName, LogItem } from '../models/Models';
import { NavigationState, ThemeState, FeedbackState, DeleteKind } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';
import {
  BRAND, RADIUS_CARD, RADIUS_FOCUS, TOUCH_MIN, FAB_SIZE, DOCK_HEIGHT,
  MOTION_PRESS, MOTION_FADE, CHIP_SELECTED,
  TYPE_DISPLAY, TYPE_TITLE, TYPE_SECTION, TYPE_GROUP, TYPE_BODY, TYPE_SECONDARY, TYPE_CAPTION,
  motionDuration, supportsBlurMaterial, floatingSurface, hairlineColor, cardShadowColor, dockShadowColor, FAB_SHADOW,
  brandText, dangerText, importanceText, colorTagLabelColor
} from './DesignTokens';

// 设计令牌统一在 ./DesignTokens 维护，此处 re-export 保持既有 import 路径不变。
export {
  BRAND, PAGE_BACKGROUND_LIGHT, PAGE_BACKGROUND_DARK, CARD_SURFACE_LIGHT, CARD_SURFACE_DARK,
  TEXT_PRIMARY_LIGHT, TEXT_PRIMARY_DARK, TEXT_MUTED_LIGHT, TEXT_MUTED_DARK,
  WEAK_SURFACE_LIGHT, CONTROL_SURFACE_DARK, TINT_SURFACE_LIGHT, TINT_SURFACE_DARK,
  DANGER_SURFACE_LIGHT, DANGER_SURFACE_DARK,
  CHIP_SELECTED, RADIUS_CARD, RADIUS_FOCUS, TOUCH_MIN, FAB_SIZE, DOCK_HEIGHT, DOCK_CLEARANCE,
  MOTION_PRESS, MOTION_FADE, MOTION_PAGE,
  TYPE_DISPLAY, TYPE_TITLE, TYPE_SECTION, TYPE_GROUP, TYPE_BODY, TYPE_SECONDARY, TYPE_CAPTION, TYPE_HERO,
  DIALOG_WIDTH, DIALOG_WIDTH_FORM, DIALOG_WIDTH_PERCENT,
  CONTENT_MAX_WIDE, CONTENT_MAX_MEDIUM, CONTENT_MAX_CENTERED,
  HOME_HALO_TOP, HOME_HALO_MID, HOME_HALO_OUTER,
  motionDuration,
  supportsBlurMaterial, floatingSurface, hairlineColor, cardShadowColor, dockShadowColor, FAB_SHADOW,
  brandText, dangerText, importanceText, dangerButtonColor, successText, successFill,
  scrimColor, toastSurface, toastLevelColor, iconSemantic, fabOptionColor, statLineColor,
  emotionColor, statusText, colorTagLabelColor
} from './DesignTokens';
export { setReduceMotionEnabled, isReduceMotionEnabled } from '../state/FeatureStates';

@Builder
export function PageHeader(theme: ThemeState, title: string, subtitle: string) {
    Column({ space: 4 }) {
      Text(title).fontSize(TYPE_TITLE).fontWeight(FontWeight.Bold).fontColor(theme.themeText).width('100%')
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
      Button('‹ 返回', { type: ButtonType.Normal }).height(TOUCH_MIN).fontColor(brandText(theme)).backgroundColor(Color.Transparent)
        .onClick(onBack)
      Text(title).fontSize(TYPE_SECTION).fontWeight(FontWeight.Bold).fontColor(theme.themeText)
    }.width('100%').height(60).padding({ left: 8, right: 16 })
  }

// 三态套件：空态/加载/错误共用同一卡片容器语言。actionLabel 为空时不渲染操作按钮。
@Builder
export function EmptyState(theme: ThemeState, emoji: string, text: string, actionLabel: string = '', onAction: () => void = () => {}) {
    Column({ space: 8 }) {
      Text(emoji).fontSize(TYPE_DISPLAY)
      Text(text).fontSize(TYPE_BODY).fontColor(theme.themeMuted)
      if (actionLabel !== '') {
        Button(actionLabel).height(TOUCH_MIN).backgroundColor(BRAND).margin({ top: 4 })
          .onClick(onAction)
      }
    }.width('100%').padding(24).justifyContent(FlexAlign.Center).backgroundColor(theme.themeSurface).borderRadius(RADIUS_CARD)
      .border({ width: 0.5, color: hairlineColor(theme) })
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
      Button('重试').height(TOUCH_MIN).backgroundColor(BRAND).margin({ top: 4 })
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
    .fontColor(selected ? Color.White : theme.themeText)
    .fontWeight(selected ? FontWeight.Medium : FontWeight.Regular)
    .textAlign(TextAlign.Center)
    .padding({ left: 16, right: 16 })
    .height(TOUCH_MIN)
    .backgroundColor(selected ? CHIP_SELECTED : theme.themeControl)
    .borderRadius(TOUCH_MIN / 2)
    .stateStyles({
      normal: { .opacity(1) },
      pressed: { .opacity(0.7) }
    })
    .onClick(onSelect)
    .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
}

@Builder
export function SegmentedControl(theme: ThemeState, options: string[], selectedIndex: number, onSelect: (index: number) => void) {
  Row({ space: 4 }) {
    ForEach(options, (option: string, index: number) => {
      Row() {
        Text(option)
          .fontSize(TYPE_SECONDARY)
          .fontColor(index === selectedIndex ? theme.themeText : theme.themeMuted)
          .fontWeight(index === selectedIndex ? FontWeight.Medium : FontWeight.Regular)
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(1)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(index === selectedIndex ? theme.themeSurface : Color.Transparent)
      .borderRadius(18)
      .stateStyles({
        normal: { .opacity(1) },
        pressed: { .opacity(0.7) }
      })
      .onClick(() => onSelect(index))
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
      }
      // 未读角标（Idea Reminder）：BRAND 底白字深浅模式均 ≥4.5:1。
      if (badge > 0) {
        Text(badge > 99 ? '99+' : `${badge}`)
          .fontSize(TYPE_CAPTION)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .constraintSize({ minWidth: 18 })
          .height(18)
          .padding({ left: 4, right: 4 })
          .backgroundColor(BRAND)
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
  .backgroundColor(selected ? theme.themeTint : Color.Transparent)
  .borderRadius(26)
  .accessibilityGroup(true)
  .accessibilityText(label + (selected ? '，已选中' : '') + (badge > 0 ? `，${badge} 条未读灵感` : ''))
  .onClick(onSelect)
  .animation({ duration: motionDuration(MOTION_FADE), curve: Curve.EaseOut })
}

@Builder
export function FlashDockBar(theme: ThemeState, navigation: NavigationState, onSelect: (index: number) => void, recordsBadge: number = 0) {
  Row({ space: 8 }) {
    DockItem(theme, $r('sys.symbol.house'), $r('sys.symbol.house_fill'), '此刻', navigation.activeTab === 0, () => onSelect(0))
    DockItem(theme, $r('sys.symbol.doc_text'), $r('sys.symbol.doc_text_fill'), '记录', navigation.activeTab === 1, () => onSelect(1), recordsBadge)
    DockItem(theme, $r('sys.symbol.clock_arrow_2_circlepath'), $r('sys.symbol.clock_arrow_2_circlepath_fill'), '回顾', navigation.activeTab === 2, () => onSelect(2))
    DockItem(theme, $r('sys.symbol.gearshape'), $r('sys.symbol.gearshape_fill'), '设置', navigation.activeTab === 3, () => onSelect(3))
  }
  .layoutWeight(1)
  .height(DOCK_HEIGHT)
  .padding({ left: 8, right: 8 })
  .backgroundColor(floatingSurface(theme))
  .backgroundBlurStyle(supportsBlurMaterial() ? BlurStyle.COMPONENT_ULTRA_THICK : BlurStyle.NONE)
  .borderRadius(RADIUS_FOCUS)
  .border({ width: 0.5, color: hairlineColor(theme) })
  .shadow({ radius: 24, color: dockShadowColor(theme), offsetY: 8 })
}

@Builder
export function FabButton(navigation: NavigationState, onToggle: () => void) {
  Stack() {
    Row().width(22).height(2.5).borderRadius(2).backgroundColor(Color.White)
    Row().width(2.5).height(22).borderRadius(2).backgroundColor(Color.White)
  }
  .width(FAB_SIZE)
  .height(FAB_SIZE)
  .borderRadius(FAB_SIZE / 2)
  .backgroundColor(BRAND)
  .rotate({ angle: 45 * navigation.fabProgress })
  .accessibilityText('快速记录')
  .shadow({ radius: 16, color: FAB_SHADOW, offsetY: 6 })
  .stateStyles({
    normal: { .scale({ x: 1, y: 1 }) },
    pressed: { .scale({ x: 0.92, y: 0.92 }) }
  })
  .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
  .onClick(onToggle)
}

@Builder
export function FabOption(theme: ThemeState, label: string, icon: Resource, color: string, action: () => void) {
  Row({ space: 8 }) {
    Text(label).fontSize(TYPE_SECONDARY).fontColor(theme.themeText).padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor(floatingSurface(theme)).borderRadius(18)
      .backgroundBlurStyle(supportsBlurMaterial() ? BlurStyle.COMPONENT_THIN : BlurStyle.NONE)
      .border({ width: 0.5, color: hairlineColor(theme) })
    Stack() {
      SymbolGlyph(icon).fontSize(20).fontColor([Color.White])
    }
    .width(TOUCH_MIN)
    .height(TOUCH_MIN)
    .borderRadius(TOUCH_MIN / 2)
    .backgroundColor(color)
    .stateStyles({
      normal: { .scale({ x: 1, y: 1 }) },
      pressed: { .scale({ x: 0.92, y: 0.92 }) }
    })
    .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
    .onClick(action)
  }
}

@Builder
export function RecordRow(theme: ThemeState, feedback: FeedbackState, actions: PageActions, item: LogItem) {
    Row({ space: 12 }) {
      Column().width(5).height(44).borderRadius(3).backgroundColor(colorTagColor(item.colorTag))
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(item.category === Category.IDEA ? '灵感' : colorTagName(item.colorTag))
            .fontSize(TYPE_CAPTION).fontColor(colorTagLabelColor(theme, item.colorTag))
          if (item.importance > 0) {
            Text(`重要度 ${item.importance}`).fontSize(TYPE_CAPTION).fontColor(importanceText(theme))
          }
        }.width('100%')
        Text(item.content).fontSize(TYPE_BODY).fontColor(theme.themeText).lineHeight(22).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${shortDay(item.recordDate)} · ${item.createdAt.slice(11, 16)}`).fontSize(TYPE_CAPTION).fontColor(theme.themeMuted)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column({ space: 4 }) {
        Button('编辑', { type: ButtonType.Normal })
          .fontSize(TYPE_CAPTION).fontColor(brandText(theme)).backgroundColor(theme.themeTint).height(44)
          .onClick(() => actions.logsController.startEditLog(item))
        Button('删除', { type: ButtonType.Normal })
          .fontSize(TYPE_CAPTION).fontColor(dangerText(theme)).backgroundColor(theme.themeDanger).height(44)
          .onClick(() => feedback.destructive = { kind: DeleteKind.LOG, id: item.id })
      }
    }.width('100%').padding({ top: 8, bottom: 8 })
      .hoverEffect(HoverEffect.Highlight)
      .stateStyles({
        normal: { .opacity(1) },
        pressed: { .opacity(0.85) }
      })
      .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
      .onClick(() => actions.logsController.openLogDetail(item))
  }

// 全宽记录卡：此刻页「最近闪念」与记录页列表共用。点击进入详情页（详情内再编辑），
// 右上角更多菜单提供编辑/删除。改为组件以持有菜单显隐状态：
// bindMenu(isShow) 由省略号点按显式控制，避免长按触发/冒泡进详情。
@Component
export struct RecordCard {
  @ObjectLink theme: ThemeState;
  @ObjectLink feedback: FeedbackState;
  actions?: PageActions;
  @Prop item: LogItem = { id: '', content: '', colorTag: '', category: '', importance: 0, createdAt: '', recordDate: '' };
  @State private menuOpen: boolean = false;

  build() {
    Row({ space: 12 }) {
      Column().width(4).height(48).borderRadius(2).backgroundColor(colorTagColor(this.item.colorTag))
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          SymbolGlyph(this.item.category === Category.IDEA ? $r('sys.symbol.lightbulb') : $r('sys.symbol.doc_text'))
            .fontSize(12)
            .fontColor([colorTagLabelColor(this.theme, this.item.colorTag)])
          Text(this.item.category === Category.IDEA ? '灵感' : colorTagName(this.item.colorTag))
            .fontSize(TYPE_CAPTION).fontColor(colorTagLabelColor(this.theme, this.item.colorTag))
          if (this.item.importance > 0) {
            Text(`重要度 ${this.item.importance}`).fontSize(TYPE_CAPTION).fontColor(importanceText(this.theme))
          }
        }.width('100%')
        Text(this.item.content)
          .fontSize(TYPE_BODY).fontColor(this.theme.themeText).lineHeight(22).width('100%')
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${shortDay(this.item.recordDate)} · ${this.item.createdAt.slice(11, 16)}`)
          .fontSize(TYPE_CAPTION).fontColor(this.theme.themeMuted)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.ellipsis_circle'))
        .fontSize(18)
        .fontColor([this.theme.themeMuted])
        .width(TOUCH_MIN)
        .height(TOUCH_MIN)
        .accessibilityText('更多操作：编辑或删除此记录')
        .onClick(() => this.menuOpen = true)
        .bindMenu(this.menuOpen, [
          { value: '编辑', action: () => requireActions(this.actions).logsController.startEditLog(this.item) },
          { value: '删除', action: () => this.feedback.destructive = { kind: DeleteKind.LOG, id: this.item.id } }
        ])
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.theme.themeSurface)
    .borderRadius(RADIUS_CARD)
    .border({ width: 0.5, color: hairlineColor(this.theme) })
    .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })
    .hoverEffect(HoverEffect.Highlight)
    .stateStyles({
      normal: { .opacity(1) },
      pressed: { .opacity(0.85) }
    })
    .animation({ duration: motionDuration(MOTION_PRESS), curve: Curve.EaseOut })
    .onClick(() => requireActions(this.actions).logsController.openLogDetail(this.item))
  }
}

// 通用卡片容器：全站卡片四件套（圆角+发丝描边+投影+表面色）的唯一实现。
@Component
export struct FlashCard {
  @ObjectLink theme: ThemeState;
  radius: number = RADIUS_CARD;
  contentPadding: number = 16;
  space: number = 0;
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {}

  build() {
    Column({ space: this.space }) {
      this.content()
    }
    .width('100%')
    .padding(this.contentPadding)
    .backgroundColor(this.theme.themeSurface)
    .borderRadius(this.radius)
    .border({ width: 0.5, color: hairlineColor(this.theme) })
    .shadow({ radius: 16, color: cardShadowColor(this.theme), offsetX: 0, offsetY: 6 })
  }
}
