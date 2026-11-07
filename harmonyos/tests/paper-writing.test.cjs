// 「纸上书写」与 iOS 同步：令牌一致、抖动同算法、i18n 键、全局搜索、Memory、入口解析、撤销与收藏。
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createLoader } = require('./ets-loader.cjs');

const tokens = JSON.parse(fs.readFileSync(path.join(__dirname, '../../docs/design/paper-tokens.json'), 'utf8'));
const load = createLoader();

test('design tokens match the shared paper token file', () => {
  const t = load('components/DesignTokens');
  const c = tokens.colors;
  const pairs = [
    ['pageBackground', t.PAGE_BACKGROUND_LIGHT, t.PAGE_BACKGROUND_DARK],
    ['cardSurface', t.CARD_SURFACE_LIGHT, t.CARD_SURFACE_DARK],
    ['weakSurface', t.WEAK_SURFACE_LIGHT, t.CONTROL_SURFACE_DARK],
    ['parchment', t.PARCHMENT_LIGHT, t.PARCHMENT_DARK],
    ['weakBorder', t.WEAK_BORDER_LIGHT, t.WEAK_BORDER_DARK],
    ['textPrimary', t.TEXT_PRIMARY_LIGHT, t.TEXT_PRIMARY_DARK],
    ['textSecondary', t.TEXT_MUTED_LIGHT, t.TEXT_MUTED_DARK],
    ['textTertiary', t.TEXT_TERTIARY_LIGHT, t.TEXT_TERTIARY_DARK],
    ['brandPrimary', t.BRAND, t.BRAND_DARK],
    ['onBrandPrimary', t.ON_BRAND_LIGHT, t.ON_BRAND_DARK],
    ['chipSelectedBackground', t.CHIP_SELECTED_LIGHT, t.CHIP_SELECTED_DARK],
    ['chipSelectedForeground', t.CHIP_SELECTED_TEXT_LIGHT, t.CHIP_SELECTED_TEXT_DARK]
  ];
  for (const [name, light, dark] of pairs) {
    assert.equal(light, c[name].light, `${name} light`);
    assert.equal(dark, c[name].dark, `${name} dark`);
  }
  const { ThemeState } = load('state/FeatureStates');
  const lightTheme = new ThemeState();
  const darkTheme = new ThemeState();
  darkTheme.themeMode = 'dark';
  for (const [tag, tone] of Object.entries(tokens.tags)) {
    assert.equal(t.colorTagLabelColor(lightTheme, tag), tone.text.light, `${tag} text`);
    assert.equal(t.colorTagLabelColor(darkTheme, tag), tone.text.dark, `${tag} text dark`);
    assert.equal(t.colorTagFill(lightTheme, tag), tone.fill.light, `${tag} fill`);
  }
  for (const [level, pair] of Object.entries(tokens.moods)) {
    assert.equal(t.moodColor(lightTheme, Number(level)), pair.light, `mood ${level}`);
    assert.equal(t.moodColor(darkTheme, Number(level)), pair.dark, `mood ${level} dark`);
  }
});

test('no pure black anywhere in the design tokens source', () => {
  const source = fs.readFileSync(path.join(__dirname, '../entry/src/main/ets/components/DesignTokens.ets'), 'utf8');
  assert.equal(/#(?:[0-9A-Fa-f]{2})?000000\b/.test(source), false);
});

test('jitter matches the cross-platform vectors', () => {
  const { SeededJitter } = load('components/PaperGeometry');
  for (const vector of tokens.jitterVectors) {
    const jitter = new SeededJitter(vector.seed);
    for (const expected of vector.values) {
      assert.ok(Math.abs(jitter.next() - expected) < 1e-9, vector.seed);
    }
  }
});

test('torn shapes are deterministic and stay inside their box', () => {
  const { tornLineCommands, tornEdgeMaskCommands, handCircleCommands } = load('components/PaperGeometry');
  assert.equal(tornLineCommands('a', 300, 12, 3, 20), tornLineCommands('a', 300, 12, 3, 20));
  assert.notEqual(tornLineCommands('a', 300, 12, 3, 20), tornLineCommands('b', 300, 12, 3, 20));
  assert.equal(tornLineCommands('a', 0, 12, 3, 20), '');
  assert.ok(tornEdgeMaskCommands('a', 300, 24, 7, 20).endsWith('Z'));
  assert.ok(handCircleCommands('a', 100, 0.04).startsWith('M'));
});

test('tr returns the source and fills placeholders without locale digits', () => {
  const { tr, i18nKey, installI18n } = createLoader()('data/I18n');
  assert.equal(tr('共 {0} 条', 12), '共 12 条');
  assert.equal(tr('{1} 和 {0}', 'a', 'b'), 'b 和 a');
  assert.match(i18nKey('早上好'), /^s_[0-9a-f]{8}$/);
  assert.equal(i18nKey('早上好'), i18nKey('早上好'));
  installI18n({ getStringByNameSync: name => name === i18nKey('早上好') ? 'Good morning' : (() => { throw new Error('x'); })() }, 'en');
  assert.equal(tr('早上好'), 'Good morning');
  assert.equal(tr('没有翻译的文案'), '没有翻译的文案');
});

test('display font only applies to Chinese', () => {
  const l = createLoader();
  const i18n = l('data/I18n');
  assert.equal(i18n.usesBundledDisplayFont(), true);
  i18n.installI18n({ getStringByNameSync: n => n }, 'ar');
  assert.equal(i18n.usesBundledDisplayFont(), false);
  i18n.installI18n({ getStringByNameSync: n => n }, 'zh-Hans');
  assert.equal(i18n.usesBundledDisplayFont(), true);
});

function log(id, day, overrides = {}) {
  return { id, content: id, colorTag: 'daily', category: 'log', importance: 0, createdAt: `${day}T08:00:00.000Z`, recordDate: day, ...overrides };
}
function emotion(id, day, level, note) {
  return { id, level, note, recordDate: day, createdAt: `${day}T08:00:00.000Z` };
}

// 与 FlashCoreTests/WeeklyMemoryTests、Android WeeklyMemoryTest 同一组夹具。
test('weekly memory matches the Apple fixtures', () => {
  const { weeklyReport } = load('data/WeeklyMemory');
  const base = new Date(2026, 7, 13);
  const empty = weeklyReport([], [], [], base, () => '');
  assert.equal(empty.weekStart, '2026-08-10');
  assert.equal(empty.weekEnd, '2026-08-16');
  assert.equal(empty.hasData, false);
  assert.equal(empty.mood, undefined);

  const bounds = weeklyReport(
    [log('a', '2026-08-10'), log('b', '2026-08-16'), log('c', '2026-08-09'), log('d', '2026-08-17')],
    [emotion('e', '2026-08-09', 2)],
    [{ id: 't1' }, { id: 't2' }],
    base,
    task => task.id === 't1' ? '2026-08-16' : '2026-08-17');
  assert.equal(bounds.moments, 2);
  assert.equal(bounds.tasks, 1);
  assert.equal(bounds.emotions, 0);

  const highlights = weeklyReport([
    log('普通4', '2026-08-12', { importance: 4 }),
    log('普通3', '2026-08-12', { importance: 3 }),
    log('普通2', '2026-08-12', { importance: 2 }),
    log('普通1', '2026-08-12', { importance: 1 }),
    log('收藏', '2026-08-12', { isFavorite: true, content: '收藏\n第二行' })
  ], [], [], base, () => '');
  assert.deepEqual(highlights.highlights, ['收藏', '普通4', '普通3', '普通2']);
  assert.equal(weeklyReport([], [emotion('e', '2026-08-12', 2)], [], base, () => '').mood.text, 'Mostly Positive');
  assert.equal(weeklyReport([], [emotion('e', '2026-08-12', -2)], [], base, () => '').mood.text, 'Mostly Low');
  assert.equal(weeklyReport([], [emotion('e', '2026-08-12', 0)], [], base, () => '').mood.text, 'Mostly Steady');
});

test('global search spans kinds, limits to 20 and sorts newest first', () => {
  const { globalSearch, highlightParts, SearchMatchKind } = load('data/GlobalSearch');
  const logs = Array.from({ length: 30 }, (_, i) => ({
    ...log(`l${i}`, '2026-08-12'), content: `晨跑 ${i}`, createdAt: `2026-08-12T08:${String(i).padStart(2, '0')}:00.000Z`
  }));
  const results = globalSearch(logs, [], [], '晨跑');
  assert.equal(results.length, 20);
  assert.equal(results[0].id, 'l29');
  assert.deepEqual(globalSearch(logs, [], [], '   '), []);
  const mixed = globalSearch([], [emotion('e', '2026-08-12', 2, '散步之后')],
    [{ id: 't', title: '买票', notes: '带上雨伞', createdAt: '2026-08-13T00:00:00.000Z' }], '雨伞');
  assert.deepEqual(mixed.map(m => m.kind), [SearchMatchKind.TASK]);
  assert.deepEqual(highlightParts('Flash flash', 'FLASH').map(p => [p.text, p.hit]),
    [['Flash', true], [' ', false], ['flash', true]]);
});

test('deep links only open screens and never carry content', () => {
  const { parseDeepLink, namedEntry, sharedEntry, isTypedTrailingReturn, greetingText, EntryKind } = load('data/AppEntry');
  assert.equal(parseDeepLink('flash://capture').kind, EntryKind.CAPTURE_IDEA);
  assert.equal(parseDeepLink('flash://capture?category=log').kind, EntryKind.CAPTURE_LOG);
  assert.equal(parseDeepLink('flash://capture?text=secret').payload, '');
  assert.equal(parseDeepLink('flash://ideas').kind, EntryKind.IDEAS);
  assert.equal(parseDeepLink('flash://delete'), undefined);
  assert.equal(parseDeepLink('https://example.com'), undefined);
  assert.equal(parseDeepLink(undefined), undefined);
  assert.equal(namedEntry('nope'), undefined);
  assert.equal(sharedEntry('   '), undefined);
  assert.equal(sharedEntry(' 想法 ').payload, '想法');
  assert.equal(isTypedTrailingReturn('想法', '想法\n'), true);
  assert.equal(isTypedTrailingReturn('想法', '想法\n第二行\n'), false);
  assert.equal(isTypedTrailingReturn('', '粘贴'), false);
  assert.equal(greetingText(5), '早上好 ☀️');
  assert.equal(greetingText(11), '下午好 🌤');
  assert.equal(greetingText(4), '晚上好 🌙');
});

test('next idea reminder respects 20:00 and the frequency interval', () => {
  const { nextIdeaReminderDate } = load('data/IdeaReminder');
  const morning = new Date(2026, 7, 13, 9, 0, 0);
  assert.equal(nextIdeaReminderDate(morning, 'daily', '').getDate(), 13);
  assert.equal(nextIdeaReminderDate(morning, 'daily', '').getHours(), 20);
  const night = new Date(2026, 7, 13, 21, 0, 0);
  assert.equal(nextIdeaReminderDate(night, 'daily', '').getDate(), 14);
  assert.equal(nextIdeaReminderDate(morning, 'weekly', '2026-08-12').getDate(), 19);
  assert.equal(nextIdeaReminderDate(morning, 'every3days', '2026-08-01').getDate(), 13);
});

function runtime() {
  const messages = [];
  let undo;
  return { messages, get undo() { return undo; }, notify: m => messages.push(m), errorMessage: e => e.message,
    notifyUndo: (m, label, action) => { messages.push(m); undo = action; } };
}

test('delete offers undo that restores the record and read state', async () => {
  const l = createLoader();
  const { LogsState } = l('state/FeatureStates');
  const { LogsController } = l('state/LogsController');
  const state = new LogsState(), r = runtime();
  const calls = [];
  const controller = new LogsController(state, r, {
    isIdeaViewed: () => true,
    deleteLog: async id => calls.push(['delete', id]),
    restoreLog: async (item, viewed) => calls.push(['restore', item.id, viewed])
  });
  await controller.deleteWithUndo(log('a', '2026-08-12', { category: 'idea' }));
  assert.deepEqual(calls, [['delete', 'a']]);
  r.undo();
  await Promise.resolve();
  assert.deepEqual(calls, [['delete', 'a'], ['restore', 'a', true]]);
});

test('opening a log edits it directly and marks only that idea read', () => {
  const l = createLoader();
  const { LogsState } = l('state/FeatureStates');
  const { LogsController } = l('state/LogsController');
  const state = new LogsState(), r = runtime();
  const viewed = [];
  const controller = new LogsController(state, r, { markIdeaViewed: async id => viewed.push(id) });
  controller.openLog(log('a', '2026-08-12', { category: 'idea', isFavorite: true }));
  assert.deepEqual(viewed, ['a']);
  assert.equal(state.editingLogId, 'a');
  assert.equal(state.editFavorite, true);
  controller.openLog(log('b', '2026-08-12'));
  assert.deepEqual(viewed, ['a'], 'logs have no read state');
});

test('favorites filter stacks with the type filter', () => {
  const l = createLoader();
  const { LogsState } = l('state/FeatureStates');
  const { LogsController } = l('state/LogsController');
  const state = new LogsState();
  const controller = new LogsController(state, runtime(), {});
  state.logs = [log('a', '2026-08-12', { isFavorite: true }), log('b', '2026-08-12'),
    log('c', '2026-08-12', { category: 'idea', isFavorite: true })];
  state.favoritesOnly = true;
  controller.updateSearchResults();
  assert.deepEqual(state.searchResults.map(i => i.id), ['a', 'c']);
  state.filterCategory = 'log';
  controller.updateSearchResults();
  assert.deepEqual(state.searchResults.map(i => i.id), ['a']);
  assert.equal(controller.hasActiveFilters(), true);
});

test('log flow filters by tags and dates and sorts three ways, logs only', () => {
  const l = createLoader();
  const { LogsState } = l('state/FeatureStates');
  const { LogsController } = l('state/LogsController');
  const state = new LogsState();
  const controller = new LogsController(state, runtime(), {});
  state.logs = [
    log('new', '2026-08-13', { colorTag: 'memo' }), log('mid', '2026-08-12', { colorTag: 'daily' }),
    log('old', '2026-08-11', { colorTag: 'urgent', isFavorite: true }),
    log('idea', '2026-08-12', { category: 'idea', colorTag: 'memo' })
  ];
  assert.deepEqual(controller.flowLogs().map(i => i.id), ['new', 'mid', 'old']);
  state.flowSort = 'oldest';
  assert.deepEqual(controller.flowLogs().map(i => i.id), ['old', 'mid', 'new']);
  state.flowSort = 'tag';
  assert.deepEqual(controller.flowLogs().map(i => i.id), ['mid', 'new', 'old']);
  state.flowSort = 'newest';
  controller.toggleFlowTag('memo');
  controller.toggleFlowTag('daily');
  assert.deepEqual(controller.flowLogs().map(i => i.id), ['new', 'mid']);
  controller.toggleFlowTag('memo');
  assert.deepEqual(controller.flowLogs().map(i => i.id), ['mid']);
  state.flowTags = [];
  state.flowStart = '2026-08-12';
  state.flowEnd = '2026-08-12';
  assert.deepEqual(controller.flowLogs().map(i => i.id), ['mid']);
  state.flowStart = state.flowEnd = '';
  state.flowFavorites = true;
  assert.deepEqual(controller.flowLogs().map(i => i.id), ['old']);
});

test('addLog rejects over-limit content instead of truncating', async () => {
  const l = createLoader();
  const { FlashStore } = l('data/FlashStore');
  const store = new FlashStore();
  store.initialized = true;
  store.database = { insert: async () => {} };
  await assert.rejects(store.addLog('字'.repeat(100001)));
  assert.equal(store.logs.length, 0);
  await store.addLog('字'.repeat(20000));
  assert.equal(store.logs[0].content.length, 20000, 'content over the old 10000 cap is kept whole');
});

test('local time helper converts instants and keeps ASCII digits', () => {
  const { localTimeHM } = load('data/DateUtils');
  const iso = new Date(2026, 7, 13, 9, 5).toISOString();
  assert.equal(localTimeHM(iso), '09:05');
  assert.equal(localTimeHM('nonsense'), '');
});

test('generated language resources are complete when present', () => {
  const res = path.join(__dirname, '../entry/src/main/resources');
  const base = path.join(res, 'base/element/string.json');
  const names = file => new Map(JSON.parse(fs.readFileSync(file, 'utf8')).string.map(e => [e.name, e.value]));
  const expected = names(base);
  for (const locale of ['zh_CN', 'fr', 'ko', 'de', 'ru', 'ar', 'ja']) {
    const file = path.join(res, locale, 'element/string.json');
    if (!fs.existsSync(file)) continue;
    const actual = names(file);
    for (const [name, value] of expected) {
      assert.ok(actual.has(name), `${locale} missing ${name}`);
      const placeholders = text => (text.match(/\{\d+\}/g) ?? []).sort().join();
      assert.equal(placeholders(actual.get(name)), placeholders(value), `${locale} ${name}`);
    }
  }
});
