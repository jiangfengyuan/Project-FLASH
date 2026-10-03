const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');

const load = createLoader();
const {
  AppSession, NavigationState, ThemeState, SystemEnvironment,
  normalizeThemeMode, resolveThemeDark, systemEnvironment
} = load('state/FeatureStates');

// --- 三态解析 ----------------------------------------------------------------

test('normalizeThemeMode keeps light, dark and system', () => {
  assert.equal(normalizeThemeMode('light'), 'light');
  assert.equal(normalizeThemeMode('dark'), 'dark');
  assert.equal(normalizeThemeMode('system'), 'system');
});

test('normalizeThemeMode reads legacy preference values unchanged', () => {
  // 旧版本只会写入 light/dark，升级后必须原样读取。
  assert.equal(normalizeThemeMode('light'), 'light');
  assert.equal(normalizeThemeMode('dark'), 'dark');
});

test('normalizeThemeMode falls back to light for unknown or missing values', () => {
  assert.equal(normalizeThemeMode(''), 'light');
  assert.equal(normalizeThemeMode('auto'), 'light');
  assert.equal(normalizeThemeMode('SYSTEM'), 'light');
  assert.equal(normalizeThemeMode(undefined), 'light');
});

// --- 三态生效 ----------------------------------------------------------------

test('resolveThemeDark ignores the system palette for explicit modes', () => {
  assert.equal(resolveThemeDark('light', true), false);
  assert.equal(resolveThemeDark('light', false), false);
  assert.equal(resolveThemeDark('dark', true), true);
  assert.equal(resolveThemeDark('dark', false), true);
});

test('resolveThemeDark follows the system palette in system mode', () => {
  assert.equal(resolveThemeDark('system', true), true);
  assert.equal(resolveThemeDark('system', false), false);
});

test('ThemeState.isDark matches resolveThemeDark across all modes', () => {
  const theme = new ThemeState();
  for (const mode of ['light', 'dark', 'system']) {
    theme.themeMode = mode;
    for (const systemDark of [true, false]) {
      theme.systemDark = systemDark;
      assert.equal(theme.isDark(), resolveThemeDark(mode, systemDark), `${mode}/${systemDark}`);
    }
  }
});

// --- 新增状态字段默认值 -------------------------------------------------------

test('NavigationState defaults keep the legacy non-immersive layout', () => {
  const navigation = new NavigationState();
  assert.equal(navigation.statusBarHeight, 0);
  assert.equal(navigation.navigationBarHeight, 0);
  assert.equal(navigation.foldable, false);
  assert.equal(navigation.foldStatus, 0);
});

test('AppSession still aggregates the nine feature states', () => {
  const session = new AppSession();
  for (const key of ['navigation', 'theme', 'home', 'logs', 'emotion', 'calendar', 'backup', 'settings', 'feedback']) {
    assert.ok(session[key], key);
  }
});

test('systemEnvironment is a SystemEnvironment singleton with neutral defaults', () => {
  assert.ok(systemEnvironment instanceof SystemEnvironment);
  assert.equal(systemEnvironment.systemDark, false);
  assert.equal(systemEnvironment.statusBarHeightPx, 0);
  assert.equal(systemEnvironment.navigationBarHeightPx, 0);
  assert.equal(systemEnvironment.foldable, false);
  assert.equal(systemEnvironment.foldStatus, 0);
});
