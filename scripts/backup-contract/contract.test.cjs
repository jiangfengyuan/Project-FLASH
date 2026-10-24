const test = require('node:test');
const assert = require('node:assert/strict');
const { validateDocument, validateBytes, validDay, validInstant, MAX_BYTES } = require('./validate.cjs');
const minimal = require('../../docs/contracts/fixtures/valid-minimal.json');
const full = require('../../docs/contracts/fixtures/valid-full.json');
const schema2 = require('../../docs/contracts/fixtures/valid-schema2.json');
const legacy = require('../../docs/contracts/fixtures/legacy-v1.json');

for (const [name, value] of Object.entries({ minimal, full, schema2 })) {
  test(`${name} fixture passes structure and semantics`, () => {
    assert.deepEqual(validateBytes(Buffer.from(JSON.stringify(value))), { valid: true, errors: [] });
  });
}

const invalidCases = {
  'unknown envelope': d => { d.version = 'flash-backup-v3'; },
  'unknown section version': d => { d.schemas.tasks = 3; },
  'unknown section': d => { d.data.attachments = []; },
  'unknown record field': d => { d.data.tasks[0].notificationId = 123; },
  'missing required section': d => { delete d.data.tasks; },
  'missing export metadata': d => { delete d.exportedAt; },
  'invalid calendar date': d => { d.data.logs[0].recordDate = '2026-02-30'; },
  'invalid enum': d => { d.data.logs[0].colorTag = 'blue'; },
  'out-of-range log importance': d => { d.data.logs[0].importance = 9; },
  'fractional emotion level': d => { d.data.emotions[0].level = 1.5; },
  'blank title': d => { d.data.tasks[0].title = ' \t\n\uFEFF'; },
  'emoji title UTF-16 limit': d => { d.data.tasks[0].title = '😀'.repeat(101); },
  'text UTF-16 limit': d => { d.data.logs[0].content = '😀'.repeat(50001); },
  'mixed due variants': d => { d.data.tasks[0].due.date = '2026-09-06'; },
  'unknown time zone': d => { d.data.tasks[0].due.timeZone = 'Flash/Unknown'; },
  'updated before created': d => { d.data.tasks[0].updatedAt = '2026-09-03T23:59:59.999Z'; },
  'duplicate ID with different content': d => { d.data.logs.push({ ...d.data.logs[0], content: '另一条记录' }); },
  'array exceeds input cap': d => { d.data.logs = Array(100001).fill(d.data.logs[0]); }
};
for (const [name, mutate] of Object.entries(invalidCases)) {
  test(`reject ${name}`, () => {
    const document = structuredClone(full);
    mutate(document);
    assert.equal(validateDocument(document).valid, false);
  });
}

test('legacy v1 is deliberately outside the v2 schema', () => {
  assert.equal(validateDocument(legacy).valid, false);
});

test('schema 2: new fields are rejected under section version 1 (version declares structure)', () => {
  for (const mutate of [
    d => { d.data.logs[0].isFavorite = true; },
    d => { d.data.emotions[0].intensity = 3; },
    d => { d.data.tasks[0].sourceLogId = '55555555-5555-4555-8555-555555555555'; }
  ]) {
    const d = structuredClone(full); // valid-full 全部分区为 schema 1
    mutate(d);
    assert.equal(validateDocument(d).valid, false);
  }
});

test('schema 2: field value rules (intensity range, boolean, id shape)', () => {
  for (const mutate of [
    d => { d.data.emotions[0].intensity = 0; },
    d => { d.data.emotions[0].intensity = 6; },
    d => { d.data.emotions[0].intensity = 1.5; },
    d => { d.data.emotions[0].intensity = '4'; },
    d => { d.data.logs[0].isFavorite = 'yes'; },
    d => { d.data.tasks[0].sourceLogId = 'not-a-uuid'; }
  ]) {
    const d = structuredClone(schema2);
    mutate(d);
    assert.equal(validateDocument(d).valid, false);
  }
});

test('schema 2: versions mix per section; new fields follow their own section version', () => {
  const d = structuredClone(schema2);
  d.schemas.emotions = 1; // emotions 回到 1：intensity/isFavorite 即非法
  assert.equal(validateDocument(d).valid, false);
  const e = structuredClone(schema2);
  e.schemas.emotions = 1;
  for (const item of e.data.emotions) { delete item.intensity; delete item.isFavorite; }
  assert.equal(validateDocument(e).valid, true);
});

test('optional fields support omission and null without conflating empty text', () => {
  const d = structuredClone(full);
  d.data.tasks[1].notes = '';
  d.data.tasks[1].completedAt = null;
  delete d.data.emotions[0].subEmotion;
  assert.equal(validateDocument(d).valid, true);
});

test('real Gregorian dates, offset timestamps and rejected ambiguous instants', () => {
  for (const value of ['2024-02-29', '2000-02-29', '0001-01-01']) assert.equal(validDay(value), true, value);
  for (const value of ['1900-02-29', '2026-02-29', '0000-01-01', '2026-13-01']) assert.equal(validDay(value), false, value);
  for (const value of ['2026-09-05T08:00:00+08:00', '2026-09-05T00:00:00.123456789Z']) assert.equal(validInstant(value), true, value);
  for (const value of ['2026-02-30T00:00:00Z', '2026-09-05T24:00:00Z', '2026-09-05T00:00:60Z',
    '2026-09-05T00:00:00', '2026-09-05T00:00:00-00:00', '0001-01-01T00:00:00+01:00']) {
    assert.equal(validInstant(value), false, value);
  }
});

test('due.timeZone matches canonical-timezones.json exactly (no ICU aliases)', () => {
  const listed = new Set(require('./canonical-timezones.json'));
  const probe = ['Asia/Shanghai', 'America/New_York', 'Europe/Berlin', 'Asia/Tokyo', 'Australia/Sydney',
    'utc', 'Zulu', 'GMT0', 'GMT', 'US/Eastern', 'Etc/UTC', 'UTC', 'Etc/GMT+1', 'CET',
    'GMT+08:00', '+08:00', 'Flash/Unknown', 'asia/shanghai'];
  for (const zone of probe) {
    const d = structuredClone(full);
    d.data.tasks[0].due.timeZone = zone;
    const result = validateDocument(d);
    if (listed.has(zone)) {
      assert.equal(result.valid, true, `expected accepted: ${zone}`);
    } else {
      assert.equal(result.valid, false, `expected rejected: ${zone}`);
      assert.equal(result.errors.some(e => e.path === '/data/tasks/0/due/timeZone' && e.code === 'TIME_ZONE'), true, zone);
    }
  }
});

test('compare normalized milliseconds, not timestamp text or submillisecond precision', () => {
  const d = structuredClone(full);
  d.data.tasks[0].createdAt = '2026-09-05T08:00:00.000999999+08:00';
  d.data.tasks[0].updatedAt = '2026-09-05T00:00:00.000000001Z';
  assert.equal(validateDocument(d).valid, true);
});

test('UTF-8, BOM and file-size guards', () => {
  assert.equal(validateBytes(Buffer.from([0xc3, 0x28])).errors[0].code, 'ENCODING_OR_JSON');
  assert.equal(validateBytes(Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), Buffer.from(JSON.stringify(minimal))])).valid, false);
  assert.equal(validateBytes(Buffer.alloc(MAX_BYTES + 1)).errors[0].code, 'FILE_SIZE');
});

test('UUID identity is section-local and case-sensitive for existing storage compatibility', () => {
  const d = structuredClone(full);
  d.data.logs[0].id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  d.data.logs.push({ ...d.data.logs[0], id: d.data.logs[0].id.toUpperCase() });
  d.data.emotions[0].id = d.data.logs[0].id;
  assert.equal(validateDocument(d).valid, true);
});

for (const item of require('../../docs/contracts/fixtures/cases.json')) {
  test(`shared corpus: ${item.file}`, () => {
    const bytes = require('node:fs').readFileSync(require('node:path').join(__dirname, '../../docs/contracts/fixtures', item.file));
    assert.equal(validateBytes(bytes).valid, item.valid);
  });
}

for (const name of ['merge-local', 'merge-incoming', 'merge-expected', 'overwrite-expected']) {
  test(`merge golden document passes Schema: ${name}`, () => {
    const document = require(`../../docs/contracts/fixtures/${name}.json`);
    assert.deepEqual(validateDocument(document), { valid: true, errors: [] });
  });
}
