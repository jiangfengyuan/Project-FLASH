// D4：日期格聚合纯函数（logsByDay/emotionsByDay → 色点列表 + 主导情绪）。
const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');

function log(id, colorTag = 'daily', recordDate = '2026-10-05') {
  return { id, content: id, category: colorTag === 'idea' ? 'idea' : 'log', colorTag, importance: 0,
    recordDate, createdAt: `${recordDate}T00:00:00.000Z` };
}
function emotion(id, level, recordDate = '2026-10-05') {
  return { id, level, recordDate, createdAt: `${recordDate}T00:00:00.000Z` };
}
function runtime() {
  return { messages: [], context: () => ({}), notify() {}, errorMessage: e => e.message };
}

test('calendarDayMarkers: empty day has no dots and no emotion', () => {
  const { calendarDayMarkers, EMPTY_DAY_MARKERS } = createLoader()('data/CalendarMarkers');
  assert.deepEqual(calendarDayMarkers([], []), { tagDots: [], extraLogs: 0, emotionLevel: undefined });
  assert.deepEqual(EMPTY_DAY_MARKERS.tagDots, []);
});

test('calendarDayMarkers: up to three tag dots, newest first, +N for the rest', () => {
  const { calendarDayMarkers } = createLoader()('data/CalendarMarkers');
  const two = calendarDayMarkers([log('a', 'idea'), log('b', 'urgent')], []);
  assert.deepEqual(two.tagDots, ['idea', 'urgent']);
  assert.equal(two.extraLogs, 0);
  const five = calendarDayMarkers(
    [log('a', 'idea'), log('b', 'urgent'), log('c', 'memo'), log('d', 'daily'), log('e', 'daily')], []);
  assert.deepEqual(five.tagDots, ['idea', 'urgent', 'memo']);
  assert.equal(five.extraLogs, 2);
});

test('calendarDayMarkers: dominant emotion by count, ties go to the newest record', () => {
  const { calendarDayMarkers } = createLoader()('data/CalendarMarkers');
  // store 顺序为最新优先。
  const majority = calendarDayMarkers([], [emotion('e1', 2), emotion('e2', -1), emotion('e3', 2)]);
  assert.equal(majority.emotionLevel, 2);
  const tie = calendarDayMarkers([], [emotion('e1', -2), emotion('e2', 3)]);
  assert.equal(tie.emotionLevel, -2, 'equal counts: the newest (first) record wins');
});

test('CalendarController.dayMarkers memoizes per data version and covers logs+emotions days', () => {
  const load = createLoader();
  const { CalendarState } = load('state/FeatureStates');
  const { CalendarController } = load('state/CalendarController');
  const state = new CalendarState();
  const controller = new CalendarController(state, runtime(), { saveTask: async () => {} });

  // 无数据日返回共享空标记。
  const empty = controller.dayMarkers('2026-10-05');
  assert.deepEqual(empty.tagDots, []);
  assert.equal(empty.emotionLevel, undefined);

  state.logsByDay = new Map([['2026-10-05', [log('a', 'idea'), log('b', 'daily'), log('c', 'memo'), log('d', 'urgent')]]]);
  state.emotionsByDay = new Map([['2026-10-05', [emotion('e1', 1)]], ['2026-10-01', [emotion('e2', -3)]]]);
  state.dataVersion = 1;
  const markers = controller.dayMarkers('2026-10-05');
  assert.deepEqual(markers.tagDots, ['idea', 'daily', 'memo']);
  assert.equal(markers.extraLogs, 1);
  assert.equal(markers.emotionLevel, 1);
  // 只有情绪没有记录的日也有情绪标记。
  assert.equal(controller.dayMarkers('2026-10-01').emotionLevel, -3);
  assert.equal(controller.dayMarkers('2026-10-05'), markers, 'same version serves the cached object');

  state.logsByDay.get('2026-10-05').push(log('e', 'daily'));
  state.dataVersion = 2;
  const rebuilt = controller.dayMarkers('2026-10-05');
  assert.equal(rebuilt.extraLogs, 2, 'version bump rebuilds the aggregate');
  assert.notEqual(rebuilt, markers);
});
