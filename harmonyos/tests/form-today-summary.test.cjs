const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');

function loadModule(formKit) {
  const fake = formKit ?? {
    formBindingData: { createFormBindingData: (obj) => ({ data: obj }) },
    formProvider: { updateForm: async () => {} }
  };
  return createLoader({ '@kit.FormKit': fake })('data/FormUpdateHelper');
}

const NOON_OCT_3 = new Date(2026, 9, 3, 12, 0, 0);
const NOON_OCT_2 = new Date(2026, 9, 2, 12, 0, 0);

function log(id, recordDate, category = 'log') {
  return { id, content: id, colorTag: 'daily', category, importance: 0,
    createdAt: `${recordDate}T09:00:00.000Z`, recordDate };
}

function emotion(id, recordDate) {
  return { id, level: 1, recordDate, createdAt: `${recordDate}T09:00:00.000Z` };
}

function task(id, due, completedAt = null) {
  return { id, title: id, colorTag: 'daily', importance: 0, due, completedAt,
    createdAt: '2026-10-01T09:00:00.000Z', updatedAt: '2026-10-01T09:00:00.000Z' };
}

test('empty inputs produce zero counts', () => {
  const { summarizeToday } = loadModule();
  assert.deepEqual(summarizeToday([], [], [], NOON_OCT_3), { records: 0, ideas: 0, tasks: 0 });
});

test('records combine today logs of all categories with today emotions only', () => {
  const { summarizeToday } = loadModule();
  const logs = [log('a', '2026-10-03'), log('b', '2026-10-03', 'idea'), log('c', '2026-10-02')];
  const emotions = [emotion('e1', '2026-10-03'), emotion('e2', '2026-10-02')];
  assert.deepEqual(summarizeToday(logs, emotions, [], NOON_OCT_3), { records: 3, ideas: 1, tasks: 0 });
});

test('pending tasks count all-day tasks due today and exclude completed or other days', () => {
  const { summarizeToday } = loadModule();
  const tasks = [
    task('today', { kind: 'allDay', date: '2026-10-03' }),
    task('done', { kind: 'allDay', date: '2026-10-03' }, '2026-10-03T10:00:00.000Z'),
    task('yesterday', { kind: 'allDay', date: '2026-10-02' }),
    task('noDate', { kind: 'allDay' })
  ];
  assert.deepEqual(summarizeToday([], [], tasks, NOON_OCT_3), { records: 0, ideas: 0, tasks: 1 });
});

test('date-time tasks resolve their due day in the task time zone', () => {
  const { summarizeToday } = loadModule();
  const shanghai = { kind: 'dateTime', at: '2026-10-02T20:30:00.000Z', timeZone: 'Asia/Shanghai' };
  const east8 = () => 8 * 60 * 60 * 1000;
  const west8 = () => -8 * 60 * 60 * 1000;
  assert.equal(summarizeToday([], [], [task('tz', shanghai)], NOON_OCT_3, east8).tasks, 1);
  assert.equal(summarizeToday([], [], [task('tz', shanghai)], NOON_OCT_3, west8).tasks, 0);
  assert.equal(summarizeToday([], [], [task('tz', shanghai)], NOON_OCT_2, west8).tasks, 1);
});

test('date-time tasks with missing or unresolvable time zone are excluded', () => {
  const { summarizeToday } = loadModule();
  const tasks = [
    task('noZone', { kind: 'dateTime', at: '2026-10-03T01:00:00.000Z' }),
    task('noAt', { kind: 'dateTime', timeZone: 'Asia/Shanghai' }),
    task('badAt', { kind: 'dateTime', at: 'not-a-date', timeZone: 'Asia/Shanghai' }),
    task('badZone', { kind: 'dateTime', at: '2026-10-03T01:00:00.000Z', timeZone: 'Nowhere/Land' })
  ];
  const unknown = () => null;
  assert.equal(summarizeToday([], [], tasks, NOON_OCT_3, unknown).tasks, 0);
});

test('default zone resolver uses the system timezone table', () => {
  const { summarizeToday } = loadModule();
  const due = { kind: 'dateTime', at: '2026-10-03T01:00:00.000Z', timeZone: 'UTC' };
  assert.equal(summarizeToday([], [], [task('utc', due)], NOON_OCT_3).tasks, 1);
});

test('todaySummaryFormData carries the three counters', () => {
  const { summarizeToday, todaySummaryFormData } = loadModule();
  const logs = [log('a', '2026-10-03'), log('b', '2026-10-03', 'idea')];
  const tasks = [task('today', { kind: 'allDay', date: '2026-10-03' })];
  const summary = summarizeToday(logs, [], tasks, NOON_OCT_3);
  assert.deepEqual(todaySummaryFormData(summary).data, { records: 2, ideas: 1, tasks: 1 });
});

test('FormUpdateHelper exposes updateForms for the main app to wire in', () => {
  const { FormUpdateHelper } = loadModule();
  assert.equal(typeof FormUpdateHelper.updateForms, 'function');
});
