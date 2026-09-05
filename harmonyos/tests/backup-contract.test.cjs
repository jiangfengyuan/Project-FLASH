const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');
const { validateBytes } = require('../../scripts/backup-contract/validate.cjs');
const full = require('../../docs/contracts/fixtures/valid-full.json');
const minimal = require('../../docs/contracts/fixtures/valid-minimal.json');
const legacy = require('../../docs/contracts/fixtures/legacy-v1.json');

for (const [name, fixture] of Object.entries({ full, minimal })) {
  test(`actual HarmonyOS codec imports and re-exports ${name} contract fixture`, () => {
    const { BackupService } = createLoader()('data/BackupService');
    const imported = BackupService.parse(JSON.stringify(fixture));
    assert.equal(imported.skippedLogs + imported.skippedEmotions + imported.skippedTasks, 0);
    for (const section of ['logs', 'emotions', 'tasks']) {
      assert.deepEqual(imported[section].map(x => x.id), fixture.data[section].map(x => x.id));
    }
    const exported = BackupService.exportJSON(imported.logs, imported.emotions, imported.tasks);
    assert.deepEqual(validateBytes(Buffer.from(exported)), { valid: true, errors: [] });
    const roundTrip = BackupService.parse(exported);
    for (const section of ['logs', 'emotions', 'tasks']) assert.deepEqual(roundTrip[section], imported[section]);
  });
}

test('actual HarmonyOS legacy import produces an empty tasks section', () => {
  const { BackupService } = createLoader()('data/BackupService');
  const imported = BackupService.parse(JSON.stringify(legacy));
  assert.equal(imported.sourceVersion, 'flash-backup-v1');
  assert.equal(imported.logs.length, 1);
  assert.deepEqual(imported.tasks, []);
});

test('standard importer rejects unknown fields', () => {
  const { BackupService } = createLoader()('data/BackupService');
  const input = JSON.stringify({ ...minimal, futureField: 'must not silently disappear' });
  assert.equal(validateBytes(Buffer.from(input)).valid, false);
  assert.throws(() => BackupService.parseStrict(input));
});

for (const item of require('../../docs/contracts/fixtures/cases.json')) {
  test(`strict native corpus: ${item.file}`, () => {
    const { BackupService } = createLoader()('data/BackupService');
    const json = require('node:fs').readFileSync(require('node:path').join(__dirname, '../../docs/contracts/fixtures', item.file), 'utf8');
    if (item.valid) {
      const result = BackupService.parseStrict(json);
      assert.equal(result.skippedLogs + result.skippedEmotions + result.skippedTasks, 0);
      assert.equal(validateBytes(Buffer.from(BackupService.exportJSON(result.logs, result.emotions, result.tasks))).valid, true);
    } else assert.throws(() => BackupService.parseStrict(json));
  });
}

test('shared merge/overwrite results and failed commit preserve state', async () => {
  const load = createLoader();
  const { BackupService } = load('data/BackupService');
  const { FlashStore } = load('data/FlashStore');
  const fixture = name => BackupService.parseStrict(JSON.stringify(require(`../../docs/contracts/fixtures/${name}.json`)));
  const local = fixture('merge-local'), incoming = fixture('merge-incoming');
  const store = new FlashStore();
  store.initialized = true;
  store.database = { beginTransaction() {}, executeSql: async () => {}, batchInsert: async () => {}, commit() {}, rollBack() {} };
  const check = expected => {
    for (const section of ['logs', 'emotions', 'tasks']) {
      const sort = a => a.slice().sort((x, y) => x.id.localeCompare(y.id));
      assert.deepEqual(sort(store.snapshot()[section]), sort(expected[section]), section);
    }
  };
  await store.replaceAll(local.logs, local.emotions, local.tasks);
  await store.mergeAll(incoming.logs, incoming.emotions, incoming.tasks);
  check(fixture('merge-expected'));
  await store.replaceAll(incoming.logs, incoming.emotions, incoming.tasks);
  check(fixture('overwrite-expected'));
  const before = store.snapshot();
  store.database.commit = () => { throw new Error('commit failure'); };
  await assert.rejects(store.mergeAll(local.logs, local.emotions, local.tasks), /commit failure/);
  check(before);
});

test('recovery is explicit and refuses unknown data', () => {
  const { BackupService } = createLoader()('data/BackupService');
  const bad = require('../../docs/contracts/fixtures/invalid-importance-range.json');
  assert.throws(() => BackupService.parseStrict(JSON.stringify(bad)));
  assert.equal(BackupService.parseRecovery(JSON.stringify(bad)).skippedLogs, 1);
  assert.throws(() => BackupService.parseRecovery(JSON.stringify({...minimal, extra: []})));
});


test('export rejects invalid source data and normalizes log timestamps', () => {
  const { BackupService } = createLoader()('data/BackupService');
  const log = { ...full.data.logs[0], importance: 9 };
  assert.throws(() => BackupService.exportJSON([log], [], []));
  log.importance = 2;
  log.createdAt = '2026-09-05T08:00:00.123456789+08:00';
  const output = JSON.parse(BackupService.exportJSON([log], [], []));
  assert.equal(output.data.logs[0].createdAt, '2026-09-05T00:00:00.123Z');
});
