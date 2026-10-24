// Host tests for the performance round: memoized stats derivations (B1),
// single-publish batch meta updates (B2), pre-aggregated emotion day
// averages (B3) and the memoized calendar grid/day counts (B9).
const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');

function runtime() {
  const messages = [];
  return { messages, context: () => ({}), notify: m => messages.push(m), errorMessage: e => e.message };
}

function log(id, day = '2026-10-03', overrides = {}) {
  return { id: id ?? '11111111-1111-1111-1111-111111111111', content: '记录', category: 'log',
    colorTag: 'daily', importance: 0, recordDate: day, createdAt: `${day}T00:00:00.000Z`, ...overrides };
}

function emotion(id, day, level) {
  return { id, level, recordDate: day, createdAt: `${day}T00:00:00.000Z` };
}

// --- B1: StatsController memoization -------------------------------------------

test('stats controller matches direct computation and only recomputes on input change', () => {
  const load = createLoader();
  const { AppSession } = load('state/FeatureStates');
  const { FeatureProjection } = load('state/FeatureProjection');
  const { StatsController } = load('state/StatsController');
  const { StorePartition: P } = load('data/StoreChanges');
  const { reviewDays, reviewComparison, emotionDistribution, dailyActivity } = load('data/ReviewWindow');
  const { dayString } = load('data/DateUtils');

  const session = new AppSession();
  const projection = new FeatureProjection(session, t => t.due.date, () => {});
  const stats = new StatsController(session.logs, session.emotion);
  const today = dayString();
  const logs = [log('a', today), log('b', today, { category: 'idea', colorTag: 'idea' })];
  const emotions = [emotion('e1', today, 2), emotion('e2', today, -1)];
  projection.update(P.ALL, { logs, emotions, tasks: [] });

  for (const window of ['week', 'month', '30', '90']) {
    const days = reviewDays(window);
    const daySet = new Set(days);
    assert.deepEqual(stats.days(window), days, window);
    assert.deepEqual(stats.periodLogs(window), logs.filter(item => daySet.has(item.recordDate)), window);
    assert.deepEqual(stats.periodEmotions(window), emotions.filter(item => daySet.has(item.recordDate)), window);
    assert.deepEqual(stats.comparison(window), reviewComparison(logs, emotions, window), window);
    assert.deepEqual(stats.distribution(window), emotionDistribution(emotions, days), window);
    assert.deepEqual(stats.activity(window), dailyActivity(logs, emotions, days), window);
  }
  assert.equal(stats.activeDays('week'), 1);
  assert.equal(stats.periodAverage('week'), '0.5');

  const memoized = stats.periodLogs('week');
  assert.equal(stats.periodLogs('week'), memoized, 'unchanged inputs hit the memo');
  assert.notEqual(stats.periodLogs('month'), memoized, 'window switch recomputes');

  const added = log('c', today);
  projection.update(P.LOGS, { logs: [...logs, added], emotions, tasks: [] });
  const recomputed = stats.periodLogs('week');
  assert.notEqual(recomputed, memoized, 'a data version bump invalidates the memo');
  assert.deepEqual(recomputed, [...logs, added]);
  assert.equal(stats.periodLogs('week'), recomputed, 'the new result is memoized again');
});

// --- B3: EmotionController day aggregates ----------------------------------------

test('dayAverage matches a direct filter-reduce and refreshes on version bump', () => {
  const load = createLoader();
  const { EmotionState } = load('state/FeatureStates');
  const { EmotionController } = load('state/EmotionController');
  const state = new EmotionState();
  const controller = new EmotionController(state, runtime(), { addEmotion: async () => {} });
  state.emotions = [emotion('e1', '2026-10-03', 2), emotion('e2', '2026-10-03', -1), emotion('e3', '2026-10-04', 3)];

  const direct = day => {
    const matches = state.emotions.filter(item => item.recordDate === day);
    return matches.length === 0 ? undefined : matches.reduce((sum, item) => sum + item.level, 0) / matches.length;
  };
  for (const day of ['2026-10-03', '2026-10-04', '2026-10-05']) {
    assert.equal(controller.dayAverage(day), direct(day), day);
    assert.equal(controller.dayEmotionLabel(day),
      direct(day) === undefined ? '—' : direct(day).toFixed(1), day);
  }
  assert.equal(controller.dayBar('2026-10-05'), 0, 'no record means an empty bar');
  assert.equal(controller.dayBar('2026-10-03'), Math.max(8, Math.round((0.5 + 3) / 6 * 100)));

  state.emotions = [emotion('e4', '2026-10-03', -3)];
  state.emotionsVersion++;
  assert.equal(controller.dayAverage('2026-10-03'), -3, 'stale aggregates are not served');
  assert.equal(controller.dayAverage('2026-10-04'), undefined);
});

// --- B2: FlashStore.updateLogsMetaBatch --------------------------------------------

test('updateLogsMetaBatch persists every edit and publishes exactly once', async () => {
  const load = createLoader();
  const { FlashStore } = load('data/FlashStore');
  const store = new FlashStore();
  store.initialized = true;
  const written = [];
  store.database = { insert: async (table, bucket) => written.push(bucket) };
  const events = [];
  store.changes.subscribe(p => events.push(p));
  store.logs = [log('a'), log('b'), log('c')];
  await store.updateLogsMetaBatch([
    { id: 'a', category: 'idea', colorTag: 'idea' },
    { id: 'c', category: 'log', colorTag: 'memo' }
  ]);
  assert.equal(written.length, 2, 'one row write per targeted record');
  assert.deepEqual(events, ['logs'], 'a single publish for the whole batch');
  assert.equal(store.logs[0].category, 'idea');
  assert.equal(store.logs[0].colorTag, 'idea');
  assert.equal(store.logs[0].content, '记录', 'body and dates stay untouched');
  assert.equal(store.logs[1].colorTag, 'daily', 'untargeted rows keep their meta');
  assert.equal(store.logs[2].colorTag, 'memo');

  const reference = new FlashStore();
  reference.initialized = true;
  reference.database = { insert: async () => {} };
  reference.logs = [log('a'), log('b'), log('c')];
  await reference.updateLogMeta('a', 'idea', 'idea');
  await reference.updateLogMeta('c', 'log', 'memo');
  assert.deepEqual(store.logs, reference.logs, 'batch result equals the per-row loop');

  await store.updateLogsMetaBatch([]);
  assert.deepEqual(events, ['logs'], 'an empty batch publishes nothing');
});

test('a failed row stops the batch but keeps applied rows visible', async () => {
  const load = createLoader();
  const { FlashStore } = load('data/FlashStore');
  const store = new FlashStore();
  store.initialized = true;
  store.database = { insert: async (table, bucket) => {
    if (bucket.id === 'b') throw new Error('disk full');
  } };
  const events = [];
  store.changes.subscribe(p => events.push(p));
  store.logs = [log('a'), log('b'), log('c')];
  await assert.rejects(store.updateLogsMetaBatch([
    { id: 'a', category: 'idea', colorTag: 'idea' },
    { id: 'b', category: 'idea', colorTag: 'idea' },
    { id: 'c', category: 'idea', colorTag: 'idea' }
  ]), /disk full/);
  assert.equal(store.logs[0].colorTag, 'idea', 'the persisted row stays visible');
  assert.equal(store.logs[1].colorTag, 'daily', 'the failed row keeps its meta');
  assert.equal(store.logs[2].colorTag, 'daily', 'later rows were not attempted');
  assert.deepEqual(events, ['logs'], 'partial progress publishes once');
});

// --- B9: CalendarController grid and day counts --------------------------------------

test('calendar memoization matches direct grid and count computation', () => {
  const load = createLoader();
  const { CalendarState } = load('state/FeatureStates');
  const { CalendarController } = load('state/CalendarController');
  const { calendarWeeks } = load('data/DateUtils');
  const state = new CalendarState();
  const controller = new CalendarController(state, runtime(), {});
  state.displayedMonth = '2026-10-01';

  assert.deepEqual(controller.monthWeeks(), calendarWeeks('2026-10-01'));
  assert.equal(controller.monthWeeks(), controller.monthWeeks(), 'unchanged month hits the memo');

  state.logsByDay = new Map([['2026-10-03', [log('a'), log('b')]]]);
  state.emotionsByDay = new Map([['2026-10-03', [emotion('e1', '2026-10-03', 1)]]]);
  state.tasksByDay = new Map([['2026-10-04', [{ id: 't' }]]]);
  state.dataVersion++;
  assert.equal(controller.dayCount('2026-10-03'), 3);
  assert.equal(controller.dayCount('2026-10-04'), 1);
  assert.equal(controller.dayCount('2026-10-05'), 0);
  assert.equal(controller.dayCount('2026-10-03'), 3, 'repeat lookups share the aggregate');

  state.logsByDay = new Map([['2026-10-03', [log('a')]]]);
  state.dataVersion++;
  assert.equal(controller.dayCount('2026-10-03'), 2, 'a data version bump re-aggregates');

  state.displayedMonth = '2026-11-01';
  assert.deepEqual(controller.monthWeeks(), calendarWeeks('2026-11-01'), 'month switch recomputes');
});
