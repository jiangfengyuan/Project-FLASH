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
