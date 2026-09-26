const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');

test('activity counts logs, ideas and emotions by recordDate, includes zero days and ignores outside days', () => {
  const { dailyActivity } = createLoader()('data/ReviewWindow');
  const days = ['2024-02-28', '2024-02-29', '2024-03-01'];
  const log = { id: 'a', category: 'log', recordDate: '2024-02-29', createdAt: '2026-09-19T00:00:00Z' };
  const result = dailyActivity([log, { ...log, id: 'b', category: 'idea' },
    { ...log, id: 'c', recordDate: '2024-03-02' }], [{ id: 'e', recordDate: '2024-03-01' }], days);
  assert.deepEqual(result.map(d => d.total), [0, 2, 1]);
  assert.deepEqual(result.map(d => d.records), [0, 2, 0]);
  assert.deepEqual(result.map(d => d.emotions), [0, 0, 1]);
  assert.deepEqual(dailyActivity([{ ...log, recordDate: '2024-02-28' }], [], days).map(d => d.total), [1, 0, 0]);
});

test('calendar has 42 unique Monday-first cells across leap months and year boundaries', () => {
  const { calendarWeeks, shiftCalendarMonth } = createLoader()('data/DateUtils');
  const feb = calendarWeeks('2024-02-01').flat();
  assert.equal(feb.length, 42);
  assert.equal(new Set(feb).size, 42);
  assert.equal(feb[0], '2024-01-29');
  assert.equal(feb[41], '2024-03-10');
  assert.ok(feb.includes('2024-02-29'));
  assert.equal(calendarWeeks('2026-02-01').flat().includes('2026-02-29'), false);
  assert.equal(shiftCalendarMonth('2026-12-31', 1), '2027-01-01');
  assert.equal(shiftCalendarMonth('2027-01-01', -1), '2026-12-01');
});

test('month selection lives in session state and adjacent-day selection follows its month', () => {
  const load = createLoader();
  const { CalendarState } = load('state/FeatureStates');
  const { CalendarController } = load('state/CalendarController');
  const state = new CalendarState();
  const runtime = { notify: () => {}, errorMessage: e => e.message };
  const controller = new CalendarController(state, runtime, {});
  controller.selectCalendarDay('2024-02-29');
  controller.shiftMonth(1);
  assert.equal(state.displayedMonth, '2024-03-01');
  assert.equal(state.selectedDay, '2024-02-29');
  const remounted = new CalendarController(state, runtime, {});
  assert.equal(state.displayedMonth, '2024-03-01');
  remounted.selectCalendarDay('2024-04-01');
  assert.equal(state.displayedMonth, '2024-04-01');
  assert.equal(state.selectedDay, '2024-04-01');
});
