import { ColorTag } from '../models/Models';
import { usesBundledDisplayFont } from '../data/I18n';
import { isReduceMotionEnabled, ThemeState } from '../state/FeatureStates';

// 「纸上书写」令牌（品牌标准 §08）。唯一来源是 docs/design/paper-tokens.json，
// 由 tests/design-tokens.test.cjs 逐项核对并校验 WCAG AA。任何外观都不用纯黑。
export const BRAND = '#A84A24';
export const BRAND_DARK = '#E9926C';
export const ON_BRAND_LIGHT = '#FFFDF6';
export const ON_BRAND_DARK = '#26201B';
export const PAGE_BACKGROUND_LIGHT = '#FFF9ED';
export const PAGE_BACKGROUND_DARK = '#1F1A16';
export const CARD_SURFACE_LIGHT = '#FFFDF6';
export const CARD_SURFACE_DARK = '#2B2520';
export const TEXT_PRIMARY_LIGHT = '#2E2A26';
export const TEXT_PRIMARY_DARK = '#F4ECDF';
export const TEXT_MUTED_LIGHT = '#5E5044';
export const TEXT_MUTED_DARK = '#BFB2A3';
export const TEXT_TERTIARY_LIGHT = '#6B655E';
export const TEXT_TERTIARY_DARK = '#A89C8F';
export const WEAK_SURFACE_LIGHT = '#F3EADA';
export const CONTROL_SURFACE_DARK = '#362E28';
export const PARCHMENT_LIGHT = '#EADFCB';
export const PARCHMENT_DARK = '#40372F';
export const TINT_SURFACE_LIGHT = '#EADFCB';
export const TINT_SURFACE_DARK = '#40372F';
export const DANGER_SURFACE_LIGHT = '#F3EADA';
export const DANGER_SURFACE_DARK = '#362E28';
export const WEAK_BORDER_LIGHT = '#E4D8C2';
export const WEAK_BORDER_DARK = '#4A4039';
export const CHIP_SELECTED_LIGHT = '#2E2A26';
export const CHIP_SELECTED_DARK = '#F4ECDF';
export const CHIP_SELECTED_TEXT_LIGHT = '#FFFDF6';
export const CHIP_SELECTED_TEXT_DARK = '#26201B';
export const CHIP_SELECTED = CHIP_SELECTED_LIGHT;
export const RADIUS_FIELD = 12;
export const RADIUS_ROW = 16;
export const RADIUS_CARD_SMALL = 20;
export const RADIUS_CARD = 24;
export const RADIUS_FOCUS = 32;
export const RADIUS_STAMP = 6;
// 页面边距 20、卡片内边距 20（较通行的 16 宽 25%）；字号放大到 1.5 倍及以上时退回 16。
export const PAGE_GUTTER = 20;
export const PAGE_GUTTER_COMPACT = 16;
export const CARD_PADDING = 20;
export const BODY_LINE_HEIGHT = 24;
export const CAPTURE_BAR_HEIGHT = 52;
export const TOUCH_MIN = 44;
export const FAB_SIZE = 56;
export const DOCK_HEIGHT = 64;
// 悬浮 Dock 高度 + 底部外边距 + 一档间距，页面内容底部留白统一使用，避免被 Dock/手势区遮挡。
export const DOCK_CLEARANCE = 168;

// 动效时长令牌（品牌标准：常规过渡 160–240ms，主题切换 320ms，按压 100–160ms）。
export const MOTION_PRESS = 120;
export const MOTION_FADE = 200;
export const MOTION_PAGE = 320;

// 字号阶梯：展示级 56 留给欢迎页，56/64 的 SymbolGlyph 属图标度量不入令牌。
export const TYPE_DISPLAY = 34;
export const TYPE_TITLE = 28;
export const TYPE_SECTION = 20;
export const TYPE_GROUP = 17;
export const TYPE_BODY = 15;
export const TYPE_SECONDARY = 13;
export const TYPE_CAPTION = 11;
export const TYPE_HERO = 56;

// 随包展示字体：只用于中文的页面标题、问候语、区块短标题与单行关键摘录。
export const DISPLAY_FONT_NAME = 'LXGWWenKai';

// 弹窗与内容宽度：中屏以上弹窗限宽，半折叠态内容居中限宽。
export const DIALOG_WIDTH = 460;
export const DIALOG_WIDTH_FORM = 540;
export const DIALOG_WIDTH_PERCENT = '88%';
export const CONTENT_MAX_WIDE = 980;
export const CONTENT_MAX_MEDIUM = 760;
export const CONTENT_MAX_CENTERED = 560;

// 减少动态效果：API 12 无系统公开查询接口，由设置页开关写入（应用内设置），
// 开启后 motionDuration 归零，全站 .animation/animateTo 即时完成。
// 生效标记保存在 state/FeatureStates，避免 state 层反向依赖本文件。
let fontScale: number = 1;

export function setFontScale(scale: number): void {
  fontScale = scale;
}

export function pageGutter(): number {
  return fontScale >= 1.5 ? PAGE_GUTTER_COMPACT : PAGE_GUTTER;
}

export function displayFontFamily(): string {
  return usesBundledDisplayFont() ? DISPLAY_FONT_NAME : 'HarmonyOS Sans';
}

// HarmonyOS 没有可依赖的系统衬线：中文环境统计数字也用霞鹜文楷，其他语言用系统粗体。
export function statFontFamily(): string {
  return displayFontFamily();
}

export function motionDuration(ms: number): number {
  return isReduceMotionEnabled() ? 0 : ms;
}

// 浮层材质：背景模糊能力存在时浮层用半透明面 + ArkUI 材质模糊，
// 低能力设备回落为现有不透明卡片色，对比度不受影响。
let blurCapableCache: boolean | undefined = undefined;

export function supportsBlurMaterial(): boolean {
  if (blurCapableCache === undefined) {
    blurCapableCache = canIUse('SystemCapability.ArkUI.ArkUI.Full');
  }
  return blurCapableCache;
}

// 硫酸纸：浮动表面 92% 不透明，文字仍达 AA。
export function floatingSurface(theme: ThemeState): string {
  if (supportsBlurMaterial()) {
    return theme.isDark() ? '#EB2B2520' : '#EBFFFDF6';
  }
  return theme.themeSurface;
}

export function hairlineColor(theme: ThemeState): string {
  return theme.isDark() ? WEAK_BORDER_DARK : WEAK_BORDER_LIGHT;
}

export function parchmentColor(theme: ThemeState): string {
  return theme.isDark() ? PARCHMENT_DARK : PARCHMENT_LIGHT;
}

// 长而弥散的暖影（浅色 8%，深色 34%）；任何外观都不用纯黑。
export const CARD_SHADOW_RADIUS = 28;
export const CARD_SHADOW_Y = 12;
export const ELEVATED_SHADOW_RADIUS = 36;
export const ELEVATED_SHADOW_Y = 16;

export function cardShadowColor(theme: ThemeState): string {
  return theme.isDark() ? '#57120D0A' : '#143B2A1E';
}

// 悬浮 Dock 与悬浮层投影。
export function dockShadowColor(theme: ThemeState): string {
  return theme.isDark() ? '#6B120D0A' : '#1F3B2A1E';
}

export const FAB_SHADOW = '#333B2A1E';

// 主操作实心底（柿橙）与其上的文字；深色下是浅柿橙配深墨字。
export function brandFill(theme: ThemeState): string {
  return theme.isDark() ? BRAND_DARK : BRAND;
}

export function onBrandFill(theme: ThemeState): string {
  return theme.isDark() ? ON_BRAND_DARK : ON_BRAND_LIGHT;
}

export function brandText(theme: ThemeState): string {
  return theme.isDark() ? BRAND_DARK : BRAND;
}

export function tertiaryText(theme: ThemeState): string {
  return theme.isDark() ? TEXT_TERTIARY_DARK : TEXT_TERTIARY_LIGHT;
}

// 选中 Chip：炭墨实心 + 纸白字（深色反转）。
export function chipSelected(theme: ThemeState): string {
  return theme.isDark() ? CHIP_SELECTED_DARK : CHIP_SELECTED_LIGHT;
}

export function chipSelectedText(theme: ThemeState): string {
  return theme.isDark() ? CHIP_SELECTED_TEXT_DARK : CHIP_SELECTED_TEXT_LIGHT;
}

export function dangerText(theme: ThemeState): string {
  return theme.isDark() ? '#E89A8E' : '#A63A2E';
}

export function importanceText(theme: ThemeState): string {
  return theme.isDark() ? '#E89A8E' : '#A63A2E';
}

// 危险操作实心按钮：与 ON_BRAND 文字搭配。
export function dangerButtonColor(): string {
  return '#A63A2E';
}

export function successText(theme: ThemeState): string {
  return theme.isDark() ? '#A6C09C' : '#55714F';
}

export function successFill(): string {
  return '#55714F';
}

// 弹窗/面板遮罩：暖褐半透明（不用纯黑）。
export function scrimColor(theme: ThemeState): string {
  return theme.isDark() ? '#8C120D0A' : '#523B2A1E';
}

// Toast：硫酸纸面，文字用主文字色（≥4.5:1）。
export function toastSurface(theme: ThemeState): string {
  return floatingSurface(theme);
}

export function toastLevelColor(level: string): string {
  switch (level) {
    case 'success': return '#55714F';
    case 'error': return '#A63A2E';
    default: return '#A84A24';
  }
}

// 语义图标色（设置行/统计图标）：在纸面上 ≥3:1。
export function iconSemantic(theme: ThemeState, kind: string): string {
  const dark = theme.isDark();
  switch (kind) {
    case 'calendar': return dark ? '#B79BC9' : '#8A6A9E';
    case 'emotion': return dark ? '#D9A5A8' : '#B47A80';
    case 'logs': return dark ? '#DDB565' : '#A9812A';
    case 'safe': return dark ? '#A6C09C' : '#74906B';
    case 'task': return dark ? '#A6C09C' : '#74906B';
    case 'lan': return dark ? '#B79BC9' : '#8A6A9E';
    default: return dark ? '#E9926C' : '#D0683C';
  }
}

export function fabOptionColor(kind: string): string {
  switch (kind) {
    case 'idea': return '#A9812A';
    case 'emotion': return '#B47A80';
    case 'task': return '#74906B';
    default: return '#8A6A9E';
  }
}

// 统计构成色点：图形在卡片面上 ≥3:1。
export function statLineColor(theme: ThemeState, kind: string): string {
  const dark = theme.isDark();
  switch (kind) {
    case 'idea': return dark ? '#DDB565' : '#A9812A';
    case 'emotion': return dark ? '#D9A5A8' : '#B47A80';
    default: return dark ? '#B79BC9' : '#8A6A9E';
  }
}

// 情绪语义色（图标）：负面干玫瑰，正面鼠尾草，中性烟灰。
export function emotionColor(theme: ThemeState, level: number): string {
  const dark = theme.isDark();
  if (level < 0) return dark ? '#D9A5A8' : '#B47A80';
  if (level > 0) return dark ? '#A6C09C' : '#74906B';
  return dark ? '#A89C8F' : '#6B655E';
}

// 能力状态文字（鸿蒙体验页）：文字用途 ≥4.5:1。
export function statusText(theme: ThemeState, kind: string): string {
  const dark = theme.isDark();
  if (kind === 'warn') return dark ? '#DDB565' : '#7A5A12';
  return dark ? '#A6C09C' : '#55714F';
}

// 标签显示色（低饱和；备份只存键名，不受影响）：文字变体 ≥4.5:1，填充只作图形。
export function colorTagLabelColor(theme: ThemeState, tag: string): string {
  const dark = theme.isDark();
  switch (tag) {
    case ColorTag.URGENT: return dark ? '#E89A8E' : '#A63A2E';
    case ColorTag.INSPIRATION: return dark ? '#DDB565' : '#7A5A12';
    case ColorTag.MEMO: return dark ? '#A6C09C' : '#55714F';
    case ColorTag.EMOTION: return dark ? '#C4ACD3' : '#7A5A86';
    case ColorTag.IDEA: return dark ? '#E5B288' : '#94531C';
    default: return dark ? '#A5BBD3' : '#476A8F';
  }
}

export function colorTagFill(theme: ThemeState, tag: string): string {
  const dark = theme.isDark();
  switch (tag) {
    case ColorTag.URGENT: return dark ? '#DB8C80' : '#C96A5E';
    case ColorTag.INSPIRATION: return dark ? '#C9A54F' : '#D6B04E';
    case ColorTag.MEMO: return dark ? '#9DB894' : '#7FA276';
    case ColorTag.EMOTION: return dark ? '#B79BC9' : '#94739F';
    case ColorTag.IDEA: return dark ? '#DDA26E' : '#D08A4E';
    default: return dark ? '#8FA9C6' : '#6E8FB3';
  }
}

// 七级情绪显示色。
export function moodColor(theme: ThemeState, level: number): string {
  const dark = theme.isDark();
  switch (Math.round(level)) {
    case -3: return dark ? '#A98BB5' : '#7A5A86';
    case -2: return dark ? '#C3A8CB' : '#B08FB8';
    case -1: return dark ? '#A5B5C7' : '#9FB0C3';
    case 1: return dark ? '#9DBB92' : '#A5C49A';
    case 2: return dark ? '#DCC47C' : '#DDC57A';
    case 3: return dark ? '#E3A768' : '#E0A25E';
    default: return dark ? '#A3C2C3' : '#A9C7C8';
  }
}
