const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');

const load = createLoader();
const {
  normalizeToastLevel, contentLayout, setReduceMotionEnabled,
  FOLD_STATUS_EXPANDED, FOLD_STATUS_HALF_FOLDED, ThemeState
} = load('state/FeatureStates');
const {
  motionDuration, MOTION_PRESS, MOTION_FADE, MOTION_PAGE,
  iconSemantic, fabOptionColor, statLineColor, emotionColor, statusText,
  successText, successFill, dangerButtonColor, toastSurface, toastLevelColor,
  brandText, dangerText, importanceText, colorTagLabelColor
} = load('components/DesignTokens');
const { COLOR_TAGS } = load('models/Models');

// --- 减少动态效果 -------------------------------------------------------------

test('motionDuration passes through when reduce motion is off', () => {
  setReduceMotionEnabled(false);
  assert.equal(motionDuration(200), 200);
  assert.equal(motionDuration(0), 0);
});

test('motionDuration collapses to zero when reduce motion is on', () => {
  setReduceMotionEnabled(true);
  assert.equal(motionDuration(200), 0);
  assert.equal(motionDuration(MOTION_PAGE), 0);
  setReduceMotionEnabled(false);
  assert.equal(motionDuration(MOTION_PRESS), MOTION_PRESS);
});

test('motion tokens stay inside the brand ranges', () => {
  // 品牌标准：按压 100–160ms，常规过渡 160–240ms，主题切换 320ms。
  assert.ok(MOTION_PRESS >= 100 && MOTION_PRESS <= 160, `MOTION_PRESS=${MOTION_PRESS}`);
  assert.ok(MOTION_FADE >= 160 && MOTION_FADE <= 240, `MOTION_FADE=${MOTION_FADE}`);
  assert.equal(MOTION_PAGE, 320);
});

// --- Toast 级别 ---------------------------------------------------------------

test('normalizeToastLevel keeps success and error', () => {
  assert.equal(normalizeToastLevel('success'), 'success');
  assert.equal(normalizeToastLevel('error'), 'error');
});

test('normalizeToastLevel falls back to info for unknown values', () => {
  assert.equal(normalizeToastLevel('info'), 'info');
  assert.equal(normalizeToastLevel(''), 'info');
  assert.equal(normalizeToastLevel('warning'), 'info');
  assert.equal(normalizeToastLevel(undefined), 'info');
});

// --- 宽屏/折叠布局裁决 ---------------------------------------------------------

test('contentLayout stays single on phones', () => {
  assert.equal(contentLayout(false, false, 0), 'single');
  assert.equal(contentLayout(false, true, 2), 'single');
});

test('contentLayout goes dual on 840vp or expanded foldable', () => {
  assert.equal(contentLayout(true, false, 0), 'dual');
  assert.equal(contentLayout(false, true, FOLD_STATUS_EXPANDED), 'dual');
});

test('contentLayout centers content on half-folded screens regardless of width', () => {
  assert.equal(contentLayout(true, true, FOLD_STATUS_HALF_FOLDED), 'centered');
  assert.equal(contentLayout(false, true, FOLD_STATUS_HALF_FOLDED), 'centered');
});

// --- 语义色对比度锁定（WCAG 相对亮度） -----------------------------------------

function luminance(hex) {
  const h = hex.replace('#', '').slice(-6);
  const channel = (i) => {
    const c = parseInt(h.slice(i, i + 2), 16) / 255;
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  };
  return 0.2126 * channel(0) + 0.7152 * channel(2) + 0.0722 * channel(4);
}

function contrast(a, b) {
  const l1 = luminance(a);
  const l2 = luminance(b);
  return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
}

const SURFACE_LIGHT = '#FFFFFF';
const SURFACE_DARK = '#3A3D5C';

function themed(mode) {
  const theme = new ThemeState();
  theme.themeMode = mode;
  return theme;
}

const ICON_KINDS = ['appearance', 'calendar', 'emotion', 'logs', 'safe', 'task', 'lan'];
const STAT_KINDS = ['log', 'idea', 'emotion'];
const FAB_KINDS = ['log', 'idea', 'emotion', 'task'];

test('iconSemantic meets 3:1 on both card surfaces', () => {
  for (const kind of ICON_KINDS) {
    assert.ok(contrast(iconSemantic(themed('light'), kind), SURFACE_LIGHT) >= 3, `light ${kind}`);
    assert.ok(contrast(iconSemantic(themed('dark'), kind), SURFACE_DARK) >= 3, `dark ${kind}`);
  }
});

test('statLineColor meets 3:1 on both card surfaces', () => {
  for (const kind of STAT_KINDS) {
    assert.ok(contrast(statLineColor(themed('light'), kind), SURFACE_LIGHT) >= 3, `light ${kind}`);
    assert.ok(contrast(statLineColor(themed('dark'), kind), SURFACE_DARK) >= 3, `dark ${kind}`);
  }
});

test('emotionColor meets 3:1 on both card surfaces at all levels', () => {
  for (const level of [-2, 0, 2]) {
    assert.ok(contrast(emotionColor(themed('light'), level), SURFACE_LIGHT) >= 3, `light ${level}`);
    assert.ok(contrast(emotionColor(themed('dark'), level), SURFACE_DARK) >= 3, `dark ${level}`);
  }
});

test('fabOptionColor keeps the white glyph at 3:1 or better', () => {
  for (const kind of FAB_KINDS) {
    assert.ok(contrast(fabOptionColor(kind), '#FFFFFF') >= 3, kind);
  }
});

test('statusText and successText meet 4.5:1 for text use', () => {
  for (const kind of ['ok', 'warn']) {
    assert.ok(contrast(statusText(themed('light'), kind), SURFACE_LIGHT) >= 4.5, `light ${kind}`);
    assert.ok(contrast(statusText(themed('dark'), kind), SURFACE_DARK) >= 4.5, `dark ${kind}`);
  }
  assert.ok(contrast(successText(themed('light')), SURFACE_LIGHT) >= 4.5);
  assert.ok(contrast(successText(themed('dark')), SURFACE_DARK) >= 4.5);
});

test('text semantic colors meet 4.5:1 on both card surfaces', () => {
  for (const fn of [brandText, dangerText, importanceText]) {
    assert.ok(contrast(fn(themed('light')), SURFACE_LIGHT) >= 4.5, fn.name);
    assert.ok(contrast(fn(themed('dark')), SURFACE_DARK) >= 4.5, fn.name);
  }
  for (const tag of COLOR_TAGS) {
    assert.ok(contrast(colorTagLabelColor(themed('light'), tag), SURFACE_LIGHT) >= 4.5, `light ${tag}`);
    assert.ok(contrast(colorTagLabelColor(themed('dark'), tag), SURFACE_DARK) >= 4.5, `dark ${tag}`);
  }
});

test('toast surfaces keep white text at 4.5:1 and level icons at 3:1', () => {
  for (const mode of ['light', 'dark']) {
    const surface = toastSurface(themed(mode)).replace(/^..(?=[0-9A-Fa-f]{6}$)/, '');
    assert.ok(contrast('#FFFFFF', surface) >= 4.5, `${mode} text`);
    for (const level of ['success', 'error', 'info']) {
      assert.ok(contrast(toastLevelColor(level), surface) >= 3, `${mode} ${level}`);
    }
  }
});

test('filled action buttons keep white content legible', () => {
  assert.ok(contrast(dangerButtonColor(), '#FFFFFF') >= 4.5);
  assert.ok(contrast(successFill(), '#FFFFFF') >= 3);
});
