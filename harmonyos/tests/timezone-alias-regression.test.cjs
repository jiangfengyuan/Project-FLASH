const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');
const full = require('../../docs/contracts/fixtures/valid-full.json');
const pairs = [['Europe/Kyiv', 'Europe/Kiev'], ['Asia/Kolkata', 'Asia/Calcutta'],
  ['Asia/Kathmandu', 'Asia/Katmandu'], ['Africa/Asmara', 'Africa/Asmera'], ['Pacific/Chuuk', 'Pacific/Truk']];

test('native and renamed IANA identifiers round trip without changing the wire spelling', () => {
  const service = createLoader()('data/BackupService').BackupService;
  for (const identifier of pairs.flat()) {
    const input = structuredClone(full); input.data.tasks[0].due.timeZone = identifier;
    const first = service.parseStrict(JSON.stringify(input));
    assert.equal(first.tasks[0].due.timeZone, identifier);
    const second = service.parseStrict(service.exportJSON(first.logs, first.emotions, first.tasks));
    assert.deepEqual(second.tasks, first.tasks);
  }
});

test('old OS alias lookup uses native available IDs and never silent GMT fallback', () => {
  for (const [modern, legacy] of pairs) {
    const load = createLoader({ '@kit.LocalizationKit': { i18n: {
      TimeZone: { getAvailableIDs: () => [legacy] },
      getTimeZone: id => { assert.equal(id, legacy); return { getOffset: () => 3 * 3600000 }; }
    } } });
    assert.equal(load('data/CanonicalTimeZones').runtimeTimeZone(modern), legacy);
    const { taskLocalDay } = load('data/FormUpdateHelper');
    assert.equal(taskLocalDay({ due: { kind: 'dateTime', at: '2026-10-01T22:30:00Z', timeZone: modern } }), '2026-10-02');
  }
  const load = createLoader({ '@kit.LocalizationKit': { i18n: {
    TimeZone: { getAvailableIDs: () => ['Africa/Nairobi'] },
    getTimeZone: () => { throw new Error('must not ask fallback-prone factory'); }
  } } });
  const resolve = load('data/CanonicalTimeZones').runtimeTimeZone;
  for (const id of ['Africa/Asmara', 'Europe/Kyiv', 'utc', 'Zulu', 'US/Eastern', '+08:00', 'Europe/kyiv', 'Mars/Olympus']) {
    assert.equal(resolve(id), undefined, id);
  }
});


test('a known zone unsupported by this OS rejects strict and recovery before preview', () => {
  const load = createLoader({ '@kit.LocalizationKit': { i18n: {
    TimeZone: { getAvailableIDs: () => [] }
  } } });
  const input = structuredClone(full); input.data.tasks[0].due.timeZone = 'Europe/Kyiv';
  const service = load('data/BackupService').BackupService;
  for (const parse of [service.parseStrict, service.parseRecovery]) {
    assert.throws(() => parse(JSON.stringify(input)), /更新系统后重试/);
  }
});

test('device-reported zones outside the wire set never fail export (PR #3 F-02)', () => {
  const service = createLoader()('data/BackupService').BackupService;
  const base = service.parseStrict(JSON.stringify(full));
  const task = base.tasks.find(item => item.due.kind === 'dateTime');
  const cases = [['GMT', 'UTC'], ['Etc/GMT', 'UTC'], ['Zulu', 'UTC'], ['Asia/Chongqing', 'Asia/Shanghai'],
    ['US/Eastern', 'America/New_York'], ['Asia/Ho_Chi_Minh', 'Asia/Ho_Chi_Minh'], ['UTC', 'UTC'], ['Etc/UTC', 'Etc/UTC']];
  for (const [device, wire] of cases) {
    const stored = structuredClone(task); stored.due.timeZone = device;
    const parsed = service.parseStrict(service.exportJSON([], [], [stored]));
    assert.equal(parsed.tasks[0].due.timeZone, wire, device);
    assert.equal(parsed.tasks[0].due.at, task.due.at, device);
    assert.equal(stored.due.timeZone, device, 'export must not mutate the stored task');
  }
});

test('a fixed-offset device zone degrades to UTC with the instant kept and a note recorded', () => {
  const service = createLoader()('data/BackupService').BackupService;
  const task = service.parseStrict(JSON.stringify(full)).tasks.find(item => item.due.kind === 'dateTime');
  const stored = structuredClone(task); stored.due.timeZone = 'GMT+08:00';
  const json = service.exportJSON([], [], [stored], 'kept');
  const parsed = service.parseStrict(json);
  assert.equal(parsed.tasks.length, 1);
  assert.equal(parsed.tasks[0].due.timeZone, 'UTC');
  assert.equal(parsed.tasks[0].due.at, task.due.at);
  const notes = JSON.parse(json).notes;
  assert.match(notes, /^kept\n/); assert.match(notes, /GMT\+08:00/); assert.match(notes, /UTC/);
  const exact = service.exportJSON([], [], [task], 'kept');
  assert.equal(JSON.parse(exact).notes, 'kept');
});

test('strict import still rejects the same aliases and unknown IDs', () => {
  const service = createLoader()('data/BackupService').BackupService;
  for (const zone of ['GMT', 'US/Eastern', 'GMT+08:00', 'Mars/Olympus']) {
    const input = structuredClone(full); input.data.tasks[0].due.timeZone = zone;
    assert.throws(() => service.parseStrict(JSON.stringify(input)), undefined, zone);
  }
});

test('a stored row with a device zone stays visible instead of being quarantined', () => {
  const service = createLoader()('data/BackupService').BackupService;
  const task = service.parseStrict(JSON.stringify(full)).tasks.find(item => item.due.kind === 'dateTime');
  const stored = structuredClone(task); stored.due.timeZone = 'GMT';
  assert.equal(service.validatedTask(stored).due.timeZone, 'UTC');
});
