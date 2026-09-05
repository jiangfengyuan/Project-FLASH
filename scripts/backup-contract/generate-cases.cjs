// Deterministic shared input corpus; --check fails if committed cases are stale.
const fs = require('node:fs');
const path = require('node:path');
const full = require('../../docs/contracts/fixtures/valid-full.json');
const root = path.resolve(__dirname, '../../docs/contracts/fixtures');
const mutations = {
  'importance-range': d => d.data.logs[0].importance = 9,
  'emoji-title': d => d.data.tasks[0].title = '😀'.repeat(101),
  'emoji-content': d => d.data.logs[0].content = '😀'.repeat(50001),
  'unknown-root': d => d.extra = true,
  'unknown-record': d => d.data.logs[0].extra = true,
  'unknown-section': d => d.data.extra = [],
  'missing-metadata': d => delete d.exportedAt,
  'invalid-export-time': d => d.exportedAt = '2026-02-30T00:00:00Z',
  'boolean-integer': d => d.data.logs[0].importance = true,
  'boolean-schema': d => d.schemas.logs = true,
  'fractional-level': d => d.data.emotions[0].level = 1.5,
  'invalid-day': d => d.data.logs[0].recordDate = '2026-02-30',
  'year-zero': d => d.data.logs[0].recordDate = '0000-01-01',
  'unknown-offset': d => d.data.logs[0].createdAt = '2026-09-05T00:00:00-00:00',
  'leap-second': d => d.data.logs[0].createdAt = '2026-09-05T00:00:60Z',
  'utc-year-underflow': d => d.data.logs[0].createdAt = '0001-01-01T00:00:00+01:00',
  'invalid-instant-day': d => d.data.logs[0].createdAt = '2026-02-30T00:00:00Z',
  'blank-title': d => d.data.tasks[0].title = ' \t\n\uFEFF',
  'unknown-zone': d => d.data.tasks[0].due.timeZone = 'Flash/Unknown',
  'offset-not-named-zone': d => d.data.tasks[0].due.timeZone = '+08:00',
  'mixed-due': d => d.data.tasks[0].due.date = '2026-09-06',
  'time-order': d => d.data.tasks[0].updatedAt = '2026-09-03T23:59:59Z',
  'duplicate-id': d => d.data.logs.push({...d.data.logs[0], content: 'duplicate'}),
  // Null inputs keep the cap fixture small and catch counting accepted records instead of inputs.
  'array-cap': d => d.data.logs = Array(100001).fill(null),
};
const cases = [];
function write(name, d, valid) {
  const file = `${name}.json`;
  const contents = JSON.stringify(d) + '\n';
  if (process.argv.includes('--check')) {
    if (fs.readFileSync(path.join(root, file), 'utf8') !== contents) throw new Error(`Stale fixture: ${file}`);
  } else fs.writeFileSync(path.join(root, file), contents);
  cases.push({file, valid});
}
for (const [name, mutate] of Object.entries(mutations)) {
  const d = structuredClone(full); mutate(d); write('invalid-' + name, d, false);
}
// Deliberately raw: JSON.parse would erase the first key. The escaped spelling
// proves native scanners compare decoded member names, not source substrings.
const duplicateKey = JSON.stringify(full).replace('"notes":', '"notes":"duplicate","\\u006eotes":') + '\n';
const duplicateKeyFile = 'invalid-duplicate-key.json';
if (process.argv.includes('--check')) {
  if (fs.readFileSync(path.join(root, duplicateKeyFile), 'utf8') !== duplicateKey) throw new Error(`Stale fixture: ${duplicateKeyFile}`);
} else fs.writeFileSync(path.join(root, duplicateKeyFile), duplicateKey);
cases.push({file: duplicateKeyFile, valid: false});
const d = structuredClone(full);
d.data.tasks[0].title = '😀'.repeat(100);
d.data.tasks[0].createdAt = '2026-09-05T08:00:00.000999999+08:00';
d.data.tasks[0].updatedAt = '2026-09-05T00:00:00.000000001Z';
d.data.logs[0].createdAt = '2026-09-05T23:59:00+23:59';
write('valid-boundaries', d, true);
const zones = structuredClone(full);
zones.data.tasks = ['UTC', 'Asia/Shanghai', 'America/New_York', 'Europe/Berlin', 'Etc/GMT+1'].map((timeZone, i) => ({
  ...full.data.tasks[0], id: `55555555-5555-4555-8555-${String(i).padStart(12, '0')}`,
  due: {kind: 'dateTime', at: '2026-11-01T01:30:00-04:00', timeZone}
}));
write('valid-time-zones', zones, true);
const manifest = JSON.stringify(cases, null, 2) + '\n';
if (process.argv.includes('--check')) {
  if (fs.readFileSync(path.join(root, 'cases.json'), 'utf8') !== manifest) throw new Error('Stale manifest');
} else fs.writeFileSync(path.join(root, 'cases.json'), manifest);
