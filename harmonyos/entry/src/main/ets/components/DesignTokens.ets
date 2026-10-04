import { ColorTag } from '../models/Models';
import { isReduceMotionEnabled, ThemeState } from '../state/FeatureStates';

// 设计令牌唯一来源：与 docs/Design/Flash_品牌标准_v1.0.md 及三端重构简报保持一致。
// 语义色双模式适配目标：图标/图形在浅底（#FFFFFF）与深卡（#3A3D5C）上 ≥3:1，文字 ≥4.5:1；
// 对比度由 tests/design-tokens.test.cjs 锁定，调整色值前先跑测试。
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
export const DANGER_SURFACE_LIGHT = '#FFF1F0';
export const DANGER_SURFACE_DARK = '#4A292D';
export const CHIP_SELECTED = '#2D3436';
export const RADIUS_CARD = 24;
export const RADIUS_FOCUS = 32;
export const TOUCH_MIN = 44;
export const FAB_SIZE = 56;
export const DOCK_HEIGHT = 64;
// 悬浮 Dock 高度 + 底部外边距 + 一档间距，页面内容底部留白统一使用，避免被 Dock/手势区遮挡。
export const DOCK_CLEARANCE = 104;

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

export function floatingSurface(theme: ThemeState): string {
  if (supportsBlurMaterial()) {
    return theme.isDark() ? '#D93A3D5C' : '#E8FFFFFF';
  }
  return theme.themeSurface;
}

export function hairlineColor(theme: ThemeState): string {
  return theme.isDark() ? '#26FFFFFF' : '#0F2D3436';
}

export function cardShadowColor(theme: ThemeState): string {
  return theme.isDark() ? '#59000000' : '#142D3436';
}

// 悬浮 Dock 投影与 FAB 品牌光晕：仅 FlashDockBar/FabButton 使用。
export function dockShadowColor(theme: ThemeState): string {
  return theme.isDark() ? '#73000000' : '#1F2D3436';
}

export const FAB_SHADOW = '#336C5CE7';

// 按钮底色（白字）仍用 BRAND，文字/图标用途用 brandText。
export function brandText(theme: ThemeState): string {
  return theme.isDark() ? '#C3BBFF' : BRAND;
}

export function dangerText(theme: ThemeState): string {
  return theme.isDark() ? '#FF8A80' : '#B42318';
}

export function importanceText(theme: ThemeState): string {
  return theme.isDark() ? '#FFB020' : '#B45309';
}

// 危险操作实心按钮（白字）：白字对比度 4.8:1，深浅模式通用。
export function dangerButtonColor(): string {
  return '#D92D20';
}

// 任务完成语义：文字 ≥4.5:1；实心勾按钮白图标 3.4:1，深浅模式通用。
export function successText(theme: ThemeState): string {
  return theme.isDark() ? '#6BCB77' : '#1E7B34';
}

export function successFill(): string {
  return '#1E9E62';
}

// 弹窗/面板遮罩：深色模式加深，避免深底上遮罩层次不足。
export function scrimColor(theme: ThemeState): string {
  return theme.isDark() ? '#8C000000' : '#66000000';
}

// Toast 浮层：浅色用深海军蓝、深色用亮一档的控制面色，白字均 ≥4.5:1。
export function toastSurface(theme: ThemeState): string {
  return theme.isDark() ? '#E8484C72' : '#DD172033';
}

// Toast 级别图标色：在两种 Toast 面上均 ≥3:1。
export function toastLevelColor(level: string): string {
  switch (level) {
    case 'success': return '#6BCB77';
    case 'error': return '#FF8A80';
    default: return '#C3BBFF';
  }
}

// 语义图标色（设置行/统计图标）：浅色值在两种表面上均 ≥3:1，深色用更亮变体加大余量。
export function iconSemantic(theme: ThemeState, kind: string): string {
  const dark = theme.isDark();
  switch (kind) {
    case 'appearance': return dark ? '#8FB2F0' : '#5A88E8';
    case 'calendar': return dark ? '#CDA4DC' : '#9A74EA';
    case 'emotion': return dark ? '#F0A6C0' : '#E35A90';
    case 'logs': return dark ? '#F5B841' : '#B08400';
    case 'safe': return dark ? '#6BCB77' : '#1E9E62';
    case 'task': return dark ? '#6BCB77' : '#1E9E62';
    case 'lan': return dark ? '#CDA4DC' : '#9A74EA';
    default: return dark ? '#8FB2F0' : '#5A88E8';
  }
}

// FAB 快捷选项实心圆：白色图标在四种底色上均 ≥3.4:1，深浅模式通用。
export function fabOptionColor(kind: string): string {
  switch (kind) {
    case 'idea': return '#B08400';
    case 'emotion': return '#E35A90';
    case 'task': return '#1E9E62';
    default: return '#9A74EA';
  }
}

// 统计构成色点：10vp 图形在卡片面上 ≥3:1。
export function statLineColor(theme: ThemeState, kind: string): string {
  const dark = theme.isDark();
  switch (kind) {
    case 'idea': return dark ? '#F5B841' : '#C87D2A';
    case 'emotion': return dark ? '#CDA4DC' : '#9A74EA';
    default: return dark ? '#8FB2F0' : '#5A88E8';
  }
}

// 情绪语义色：图标/图形用途 ≥3:1。
export function emotionColor(theme: ThemeState, level: number): string {
  const dark = theme.isDark();
  if (level < 0) return dark ? '#FF8A80' : '#E36570';
  if (level > 0) return dark ? '#6BCB77' : '#1E9E62';
  return '#8A94A6';
}

// 能力状态文字（鸿蒙体验页）：文字用途 ≥4.5:1。
export function statusText(theme: ThemeState, kind: string): string {
  const dark = theme.isDark();
  if (kind === 'warn') return dark ? '#F5A623' : '#B54708';
  return dark ? '#4CC38A' : '#16845B';
}

// 此刻页顶部光晕：品牌蓝紫 alpha 叠加，深浅底上均只作极克制装饰。
export const HOME_HALO_TOP = '#2E6C5CE7';
export const HOME_HALO_MID = '#1F4D96FF';
export const HOME_HALO_OUTER = '#006C5CE7';

// 记录卡色条保留高饱和装饰色（colorTagColor），文字标签改用深浅模式均 ≥4.5:1 的变体。
export function colorTagLabelColor(theme: ThemeState, tag: string): string {
  const dark = theme.isDark();
  switch (tag) {
    case ColorTag.URGENT: return dark ? '#FF8A80' : '#D92D20';
    case ColorTag.INSPIRATION: return dark ? '#F5B841' : '#8A6600';
    case ColorTag.MEMO: return dark ? '#6BCB77' : '#1E7B34';
    case ColorTag.EMOTION: return dark ? '#CDA4DC' : '#8E44AD';
    case ColorTag.IDEA: return dark ? '#FFB020' : '#A85F00';
    default: return dark ? '#8FB2F0' : '#2F66C4';
  }
}
