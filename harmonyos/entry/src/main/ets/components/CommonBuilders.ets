import { shortDay } from '../data/DateUtils';
import { Category, colorTagColor, colorTagName, LogItem } from '../models/Models';
import { NavigationState, ThemeState, FeedbackState, DeleteKind } from '../state/FeatureStates';
import { PageActions, requireActions } from '../state/PageActions';

// 设计令牌与 docs/Design/Flash_品牌标准_v1.0.md 及三端重构简报保持一致。
export const BRAND = '#6C5CE7';
export const PAGE_BACKGROUND_LIGHT = '#F7F9FA';
export const PAGE_BACKGROUND_DARK = '#191A38';
export const CARD_SURFACE_LIGHT = '#FFFFFF';
export const CARD_SURFACE_DARK = '#3A3D5C';
export const TEXT_PRIMARY_LIGHT = '#2D3436';
export const TEXT_PRIMARY_DARK = '#F5F6FA';
export const TEXT_MUTED_LIGHT = '#636E72';
export const TEXT_MUTED_DARK = '#B2BEC3';
export const WEAK_SURFACE_LIGHT = '#EDF0F5';
// 深色卡片面与弱表面已统一（D1 裁决），只保留 CARD_SURFACE_DARK 一个令牌。
export const CONTROL_SURFACE_DARK = '#484C72';
export const TINT_SURFACE_LIGHT = '#EAF2FF';
export const TINT_SURFACE_DARK = '#4A4478';
export const CHIP_SELECTED = '#2D3436';
export const RADIUS_CARD = 24;
export const RADIUS_FOCUS = 32;
export const TOUCH_MIN = 44;
export const FAB_SIZE = 56;
export const DOCK_HEIGHT = 64;
// 按压反馈时长（令牌区间 100–160ms），DockItem/FabButton/FabOption 共用。
export const MOTION_PRESS = 120;
// 悬浮 Dock 高度 + 底部外边距 + 一档间距，页面内容底部留白统一使用，避免被 Dock/手势区遮挡。
export const DOCK_CLEARANCE = 104;

@Builder
export function PageHeader(theme: ThemeState, title: string, subtitle: string) {
    Column({ space: 4 }) {
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
    }.width('100%').height(130).justifyContent(FlexAlign.Center).backgroundColor(theme.themeSurface).borderRadius(RADIUS_CARD)
  }

@Component
export struct FlashCard {
  @ObjectLink theme: ThemeState;
  radius: number = RADIUS_CARD;
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {}

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.theme.themeSurface)
    .borderRadius(this.radius)
  }
}

@Builder
export function FormGroup(theme: ThemeState, title: string) {
  Text(title).fontSize(17).fontWeight(FontWeight.Medium).fontColor(theme.themeText).width('100%')
}

@Builder
export function FormRow(theme: ThemeState, label: string, value: string) {
  Row({ space: 12 }) {
    Text(label).fontSize(14).fontColor(theme.themeMuted)
    Blank()
    Text(value).fontSize(14).fontColor(theme.themeText).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
  }.width('100%').height(TOUCH_MIN)
}

@Builder
export function FilterChip(theme: ThemeState, label: string, selected: boolean, onSelect: () => void) {
  Text(label)
    .fontSize(13)
    .fontColor(selected ? Color.White : theme.themeText)
    .fontWeight(selected ? FontWeight.Medium : FontWeight.Regular)
    .textAlign(TextAlign.Center)
    .padding({ left: 16, right: 16 })
    .height(TOUCH_MIN)
    .backgroundColor(selected ? CHIP_SELECTED : theme.themeControl)
    .borderRadius(TOUCH_MIN / 2)
    .onClick(onSelect)
    .animation({ duration: 200, curve: Curve.EaseOut })
}

@Builder
export function SegmentedControl(theme: ThemeState, options: string[], selectedIndex: number, onSelect: (index: number) => void) {
  Row({ space: 4 }) {
    ForEach(options, (option: string, index: number) => {
      Row() {
        Text(option)
          .fontSize(13)
          .fontColor(index === selectedIndex ? theme.themeText : theme.themeMuted)
          .fontWeight(index === selectedIndex ? FontWeight.Medium : FontWeight.Regular)
          .textAlign(TextAlign.Center)
      }
      .layoutWeight(1)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(index === selectedIndex ? theme.themeSurface : Color.Transparent)
      .borderRadius(18)
      .onClick(() => onSelect(index))
    }, (option: string) => option)
  }
  .width('100%')
  .padding(4)
  .backgroundColor(theme.themeControl)
  .borderRadius(22)
  .animation({ duration: 200, curve: Curve.EaseOut })
}

@Builder
export function DockItem(theme: ThemeState, icon: Resource, activeIcon: Resource, label: string, selected: boolean, onSelect: () => void) {
  Column() {
    Column({ space: 4 }) {
      SymbolGlyph(selected ? activeIcon : icon)
        .fontSize(22)
        .fontColor([selected ? BRAND : theme.themeMuted])
      Text(label)
        .fontSize(11)
        .fontColor(selected ? BRAND : theme.themeMuted)
        .fontWeight(selected ? FontWeight.Medium : FontWeight.Regular)
    }
    .stateStyles({
      normal: { .scale({ x: 1, y: 1 }) },
      pressed: { .scale({ x: 0.92, y: 0.92 }) }
    })
    .animation({ duration: MOTION_PRESS, curve: Curve.EaseOut })
  }
  .layoutWeight(1)
  .height(52)
  .justifyContent(FlexAlign.Center)
  .backgroundColor(selected ? theme.themeTint : Color.Transparent)
  .borderRadius(26)
  .onClick(onSelect)
  .animation({ duration: 200, curve: Curve.EaseOut })
}

@Builder
export function FlashDockBar(theme: ThemeState, navigation: NavigationState, onSelect: (index: number) => void) {
  Row({ space: 8 }) {
    DockItem(theme, $r('sys.symbol.house'), $r('sys.symbol.house_fill'), '此刻', navigation.activeTab === 0, () => onSelect(0))
    DockItem(theme, $r('sys.symbol.doc_text'), $r('sys.symbol.doc_text_fill'), '记录', navigation.activeTab === 1, () => onSelect(1))
    DockItem(theme, $r('sys.symbol.clock_arrow_2_circlepath'), $r('sys.symbol.clock_arrow_2_circlepath_fill'), '回顾', navigation.activeTab === 2, () => onSelect(2))
    DockItem(theme, $r('sys.symbol.gearshape'), $r('sys.symbol.gearshape_fill'), '设置', navigation.activeTab === 3, () => onSelect(3))
  }
  .layoutWeight(1)
  .height(DOCK_HEIGHT)
  .padding({ left: 8, right: 8 })
  .backgroundColor(theme.themeNavigation)
  .borderRadius(RADIUS_FOCUS)
  .shadow({ radius: 24, color: '#1F2D3436', offsetY: 8 })
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
  .shadow({ radius: 16, color: '#336C5CE7', offsetY: 6 })
  .stateStyles({
    normal: { .scale({ x: 1, y: 1 }) },
    pressed: { .scale({ x: 0.92, y: 0.92 }) }
  })
  .animation({ duration: MOTION_PRESS, curve: Curve.EaseOut })
  .onClick(onToggle)
}

@Builder
export function FabOption(theme: ThemeState, label: string, icon: Resource, color: string, action: () => void) {
  Row({ space: 8 }) {
    Text(label).fontSize(13).fontColor(theme.themeText).padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor(theme.themeSurface).borderRadius(18)
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
    .animation({ duration: MOTION_PRESS, curve: Curve.EaseOut })
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
            .fontSize(11).fontColor(colorTagColor(item.colorTag))
          if (item.importance > 0) {
            Text(`重要度 ${item.importance}`).fontSize(10).fontColor('#D97706')
          }
        }.width('100%')
        Text(item.content).fontSize(15).fontColor(theme.themeText).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${shortDay(item.recordDate)} · ${item.createdAt.slice(11, 16)}`).fontSize(11).fontColor(theme.themeMuted)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column({ space: 4 }) {
        Button('编辑', { type: ButtonType.Normal })
          .fontSize(11).fontColor(BRAND).backgroundColor(theme.themeTint).height(28)
          .onClick(() => actions.logsController.startEditLog(item))
        Button('删除', { type: ButtonType.Normal })
          .fontSize(11).fontColor('#B42318').backgroundColor(theme.themeDanger).height(28)
          .onClick(() => feedback.destructive = { kind: DeleteKind.LOG, id: item.id })
      }
    }.width('100%').padding({ top: 8, bottom: 8 })
  }

// 全宽记录卡：此刻页「最近闪念」与记录页列表共用。点击进入编辑详情，
// 右上角更多菜单提供编辑/删除。改为组件以持有菜单显隐状态：
// bindMenu(isShow) 由省略号点按显式控制，避免长按触发/冒泡进编辑。
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
            .fontColor([colorTagColor(this.item.colorTag)])
          Text(this.item.category === Category.IDEA ? '灵感' : colorTagName(this.item.colorTag))
            .fontSize(11).fontColor(colorTagColor(this.item.colorTag))
          if (this.item.importance > 0) {
            Text(`重要度 ${this.item.importance}`).fontSize(10).fontColor('#D97706')
          }
        }.width('100%')
        Text(this.item.content)
          .fontSize(15).fontColor(this.theme.themeText).width('100%')
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${shortDay(this.item.recordDate)} · ${this.item.createdAt.slice(11, 16)}`)
          .fontSize(11).fontColor(this.theme.themeMuted)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      SymbolGlyph($r('sys.symbol.ellipsis_circle'))
        .fontSize(18)
        .fontColor([this.theme.themeMuted])
        .width(TOUCH_MIN)
        .height(TOUCH_MIN)
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
    .onClick(() => requireActions(this.actions).logsController.startEditLog(this.item))
  }
}
