const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');

function log(id, content = '记录', overrides = {}) {
  return { id, content, category: 'log', colorTag: 'daily', importance: 0,
    recordDate: '2026-09-05', createdAt: '2026-09-05T00:00:00.000Z', ...overrides };
}
function runtime() {
  const messages = [];
  return { messages, context: () => ({}), notify: m => messages.push(m), errorMessage: e => e.message };
}

test('quick capture saves through addLog, clears the draft and notifies', async () => {
  const load = createLoader();
  const { AppSession } = load('state/FeatureStates');
  const { LogsController } = load('state/LogsController');
  const state = new AppSession(), r = runtime();
  const saved = [];
  const controller = new LogsController(state.logs, r, { addLog: async (...args) => saved.push(args) });
  state.logs.captureText = '  刚闪过的念头  ';
  await controller.saveCapture();
  assert.deepEqual(saved, [['  刚闪过的念头  ', 'log', 'daily']]);
  assert.equal(state.logs.captureText, '');
  assert.ok(r.messages.includes('日志已记录'));
  state.logs.captureCategory = 'idea';
  state.logs.captureText = '灵感';
  await controller.saveCapture();
  assert.deepEqual(saved[1], ['灵感', 'idea', 'idea']);
  assert.ok(r.messages.includes('灵感已保存'));
  await controller.saveCapture();
  assert.equal(saved.length, 2, 'empty draft must not save');
});

test('capture failure keeps the draft and surfaces the error', async () => {
  const load = createLoader();
  const { LogsState } = load('state/FeatureStates');
  const { LogsController } = load('state/LogsController');
  const state = new LogsState(), r = runtime();
  const controller = new LogsController(state, r, { addLog: async () => { throw new Error('disk full'); } });
  state.captureText = '别丢';
  await controller.saveCapture();
  assert.equal(state.captureText, '别丢');
  assert.equal(state.busy, false);
  assert.ok(r.messages.includes('disk full'));
});

test('log filters narrow by category, inbox tag, date range and importance', () => {
  const load = createLoader();
  const { LogsState } = load('state/FeatureStates');
  const { LogsController } = load('state/LogsController');
  const { dayString, dayOffset } = load('data/DateUtils');
  const state = new LogsState(), r = runtime();
  const controller = new LogsController(state, r, {});
  state.logs = [
    log('a', '今天日志', { recordDate: dayString(), importance: 2 }),
    log('b', '本周想法', { category: 'idea', colorTag: 'idea', recordDate: dayOffset(-3) }),
    log('c', '上月日常', { recordDate: dayOffset(-20) }),
    log('d', '旧备忘', { colorTag: 'memo', recordDate: dayOffset(-40) })
  ];
  controller.updateSearchResults();
  assert.deepEqual(state.searchResults.map(i => i.id), ['a', 'b', 'c', 'd']);
  state.filterCategory = 'idea';
  controller.updateSearchResults();
  assert.deepEqual(state.searchResults.map(i => i.id), ['b']);
  state.filterCategory = 'inbox';
  controller.updateSearchResults();
  assert.deepEqual(state.searchResults.map(i => i.id), ['a', 'c'], '待整理只看默认日常标签');
  state.filterCategory = 'all';
  state.filterTag = 'memo';
  controller.updateSearchResults();
  assert.deepEqual(state.searchResults.map(i => i.id), ['d']);
  state.filterTag = '';
  state.filterDate = 'week';
  controller.updateSearchResults();
  assert.deepEqual(state.searchResults.map(i => i.id), ['a', 'b']);
  state.filterDate = 'today';
  controller.updateSearchResults();
  assert.deepEqual(state.searchResults.map(i => i.id), ['a']);
  state.filterDate = 'all';
  state.filterImportance = 1;
  controller.updateSearchResults();
  assert.deepEqual(state.searchResults.map(i => i.id), ['a']);
  state.filterImportance = 0;
  controller.updateSearchResults();
  assert.deepEqual(state.searchResults.map(i => i.id), ['b', 'c', 'd']);
  assert.ok(controller.hasActiveFilters());
  controller.clearFilters();
  assert.ok(!controller.hasActiveFilters());
  assert.deepEqual(state.searchResults.map(i => i.id), ['a', 'b', 'c', 'd']);
});

test('search query composes with filters and sort toggle reverses display order', () => {
  const load = createLoader();
  const { LogsState } = load('state/FeatureStates');
  const { LogsController } = load('state/LogsController');
  const state = new LogsState(), r = runtime();
  const controller = new LogsController(state, r, {});
  state.logs = [log('a', '苹果'), log('b', '香蕉'), log('c', '苹果派', { colorTag: 'memo' })];
  state.searchText = '苹果';
  controller.updateSearchResults();
  assert.deepEqual(state.searchResults.map(i => i.id), ['a', 'c']);
  state.filterTag = 'memo';
  controller.updateSearchResults();
  assert.deepEqual(state.searchResults.map(i => i.id), ['c']);
  state.filterTag = '';
  state.searchText = '';
  controller.updateSearchResults();
  assert.deepEqual(controller.displayedLogs().map(i => i.id), ['a', 'b', 'c']);
  state.sortAscending = true;
  assert.deepEqual(controller.displayedLogs().map(i => i.id), ['c', 'b', 'a']);
});

test('batch inbox retag touches only default-tag logs and preserves content', async () => {
  const load = createLoader();
  const { LogsState } = load('state/FeatureStates');
  const { LogsController } = load('state/LogsController');
  const state = new LogsState(), r = runtime();
  const calls = [];
  const controller = new LogsController(state, r, {
    updateLogMeta: async (id, category, colorTag) => calls.push([id, category, colorTag])
  });
  state.logs = [log('a'), log('b', '想法', { category: 'idea', colorTag: 'idea' }), log('c')];
  await controller.batchUpdateInbox('idea', 'idea');
  assert.deepEqual(calls, [['a', 'idea', 'idea'], ['c', 'idea', 'idea']]);
  assert.ok(r.messages.some(m => m.includes('已整理 2 条记录')));
  calls.length = 0;
  state.logs = [log('b', '想法', { category: 'idea', colorTag: 'idea' })];
  await controller.batchUpdateInbox('log', 'memo');
  assert.deepEqual(calls, [], 'no inbox items means no writes');
});

test('updateLogMeta moves category/colorTag and preserves body, importance and dates', async () => {
  const load = createLoader();
  const { FlashStore } = load('data/FlashStore');
  const store = new FlashStore();
  store.initialized = true;
  store.database = { insert: async () => {} };
  const events = [];
  store.changes.subscribe(p => events.push(p));
  store.logs = [{ ...log(), importance: 3, content: '保留正文 !!!!' }];
  await store.updateLogMeta(store.logs[0].id, 'idea', 'idea');
  assert.equal(store.logs[0].category, 'idea');
  assert.equal(store.logs[0].colorTag, 'idea');
  assert.equal(store.logs[0].content, '保留正文 !!!!');
  assert.equal(store.logs[0].importance, 3, 'meta edits must not re-parse importance');
  assert.equal(store.logs[0].recordDate, '2026-09-05');
  assert.deepEqual(events, ['logs']);
  await store.updateLogMeta('missing', 'idea', 'idea');
  assert.deepEqual(events, ['logs'], 'unknown ids publish nothing');
});

test('saveEditedLog persists text and category/tag meta together, then clears the editor', async () => {
  const load = createLoader();
  const { LogsState } = load('state/FeatureStates');
  const { LogsController } = load('state/LogsController');
  const state = new LogsState(), r = runtime();
  const calls = [];
  const controller = new LogsController(state, r, {
    updateLog: async (id, content) => calls.push(['text', id, content]),
    updateLogMeta: async (id, category, colorTag) => calls.push(['meta', id, category, colorTag])
  });
  controller.startEditLog(log('a', '正文', { category: 'log', colorTag: 'daily' }));
  state.editText = '改写正文';
  state.editCategory = 'idea';
  state.editTag = 'idea';
  await controller.saveEditedLog();
  assert.deepEqual(calls, [['text', 'a', '改写正文'], ['meta', 'a', 'idea', 'idea']]);
  assert.equal(state.editingLogId, '');
  assert.equal(state.editCategory, '');
  assert.ok(r.messages.includes('记录已更新'));
});

test('projection fills today task counts for the home overview card', () => {
  const load = createLoader();
  const { AppSession } = load('state/FeatureStates');
  const { FeatureProjection } = load('state/FeatureProjection');
  const { StorePartition: P } = load('data/StoreChanges');
  const { dayString } = load('data/DateUtils');
  const state = new AppSession();
  const projection = new FeatureProjection(state, t => t.due.date, () => {});
  const task = (id, done) => ({ id, title: id, colorTag: 'memo', importance: 0,
    due: { kind: 'allDay', date: dayString() }, completedAt: done ? '2026-09-05T08:00:00.000Z' : undefined,
    createdAt: '2026-09-05T00:00:00.000Z', updatedAt: '2026-09-05T00:00:00.000Z' });
  const other = { ...task('old'), due: { kind: 'allDay', date: '2026-09-01' } };
  projection.update(P.ALL, { logs: [], emotions: [], tasks: [task('t1', true), task('t2', false), other] });
  assert.equal(state.home.todayTaskCount, 2);
  assert.equal(state.home.todayTaskDoneCount, 1);
  projection.update(P.TASKS, { logs: [], emotions: [], tasks: [task('t1', true)] });
  assert.equal(state.home.todayTaskCount, 1);
  assert.equal(state.home.todayTaskDoneCount, 1);
});
