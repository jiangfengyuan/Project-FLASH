const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');
const original = () => ({ id: 'a', content: 'original', category: 'log', colorTag: 'daily',
  importance: 3, createdAt: '2026-09-05T00:00:00.000Z', recordDate: '2026-09-05' });

test('date validation rejects rollover, malformed dates and year zero', () => {
  const { isValidRecordDay } = createLoader()('data/DateUtils');
  for (const value of ['2026-02-29', '2026-02-30', '0000-01-01', '2026-13-01', '2026-9-01'])
    assert.equal(isValidRecordDay(value), false, value);
  for (const value of ['2024-02-29', '0001-01-01', '9999-12-31'])
    assert.equal(isValidRecordDay(value), true, value);
});

test('editor persists all fields once, never publishes a partial edit on disk failure, and can retry', async () => {
  const load = createLoader();
  const { FlashStore } = load('data/FlashStore');
  const store = new FlashStore();
  store.initialized = true;
  store.logs = [original()];
  const events = [];
  store.changes.subscribe(p => events.push(p));
  let fail = true, writes = [];
  store.database = { insert: async (...args) => {
    if (fail) throw new Error('disk full');
    writes.push(args);
  }};
  const long = '新'.repeat(12000);
  await assert.rejects(store.updateLog('a', long, 'idea', 'memo', '2024-02-29'), /disk full/);
  assert.deepEqual(store.logs, [original()]);
  assert.deepEqual(events, []);
  fail = false;
  await store.updateLog('a', long, 'idea', 'memo', '2024-02-29');
  assert.equal(writes.length, 1);
  assert.equal(events.length, 1);
  assert.deepEqual(store.logs[0], { ...original(), content: long, category: 'idea', colorTag: 'memo', recordDate: '2024-02-29' });
  await assert.rejects(store.updateLog('a', 'bad', 'log', 'daily', '2026-02-30'), /有效日期/);
  await assert.rejects(store.updateLog('a', 'x'.repeat(100001)), /100000/);
  await assert.rejects(store.updateLog('missing', 'text'), /不存在/);
  assert.equal(writes.length, 1);
});

test('pending save rejects repeat taps and close; failure retains complete draft', async () => {
  const load = createLoader();
  const { LogsState } = load('state/FeatureStates');
  const { LogsController } = load('state/LogsController');
  const state = new LogsState();
  state.logs = [original()];
  let reject, calls = 0;
  const controller = new LogsController(state, { notify: () => {}, errorMessage: e => e.message }, {
    updateLog: () => { calls++; return new Promise((_, r) => reject = r); }
  });
  controller.startEditLog(original());
  state.editText = 'draft'; state.editDate = '2026-09-01';
  const pending = controller.saveEditedLog();
  await controller.saveEditedLog();
  controller.requestCloseEdit();
  assert.equal(calls, 1);
  assert.equal(state.editingLogId, 'a');
  assert.equal(state.editDiscard, false);
  reject(new Error('disk full'));
  await pending;
  assert.equal(state.editText, 'draft');
  assert.equal(state.editDate, '2026-09-01');
  assert.equal(state.editError, 'disk full');
  assert.equal(state.busy, false);
  controller.requestCloseEdit();
  assert.equal(state.editDiscard, true);
  controller.closeEdit();
  assert.equal(state.editingLogId, '');
});

test('review ranges align to Monday and month start, including leap days and year boundaries', () => {
  const { reviewDays } = createLoader()('data/ReviewWindow');
  const today = new Date(2026, 8, 19, 12);
  assert.deepEqual(reviewDays('week', today), ['2026-09-14','2026-09-15','2026-09-16','2026-09-17','2026-09-18','2026-09-19']);
  assert.equal(reviewDays('month', today)[0], '2026-09-01');
  assert.equal(reviewDays('30', today).length, 30);
  assert.equal(reviewDays('90', today).length, 90);
  assert.equal(reviewDays('month', new Date(2024, 1, 29, 12)).length, 29);
  assert.equal(reviewDays('week', new Date(2027, 0, 1, 12))[0], '2026-12-28');
});
