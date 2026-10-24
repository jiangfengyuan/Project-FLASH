// D2：重要度编辑纯函数与持久化、系统分享 payload 构造与能力守卫。
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createLoader } = require('./ets-loader.cjs');

function log(id = '11111111-1111-1111-1111-111111111111', content = '记录', overrides = {}) {
  return { id, content, category: 'log', colorTag: 'daily', importance: 3,
    recordDate: '2026-09-05', createdAt: '2026-09-05T00:00:00.000Z', ...overrides };
}
function runtime() {
  const messages = [];
  return { messages, context: () => ({}), notify: m => messages.push(m), errorMessage: e => e.message };
}
function storeWith(logs) {
  const written = [];
  return { written,
    initialized: true,
    logs,
    emotions: [],
    tasks: [],
    database: { insert: async (table, bucket) => written.push(JSON.parse(bucket.payload)) },
    changes: { publish: () => {} } };
}

test('isValidImportance enforces the contract 0-4 integer range', () => {
  const { isValidImportance } = createLoader()('models/Models');
  for (const ok of [0, 1, 2, 3, 4]) assert.ok(isValidImportance(ok));
  for (const bad of [-1, 5, 2.5, NaN, Number.POSITIVE_INFINITY]) assert.ok(!isValidImportance(bad));
});

test('updateLog persists an edited importance and rejects out-of-range values', async () => {
  const { FlashStore } = createLoader()('data/FlashStore');
  const store = new FlashStore();
  const fake = storeWith([log('a')]);
  store.logs = fake.logs;
  store.database = fake.database;
  store.initialized = true;

  await store.updateLog('a', '正文', 'log', 'daily', '2026-09-05', 4);
  assert.equal(store.logs[0].importance, 4);
  assert.equal(fake.written[0].importance, 4, 'persisted payload carries the new importance');

  await assert.rejects(store.updateLog('a', '正文', 'log', 'daily', '2026-09-05', 5), /重要度/);
  await assert.rejects(store.updateLog('a', '正文', 'log', 'daily', '2026-09-05', -1), /重要度/);

  // 不传重要度时保持原值（旧调用路径）。
  await store.updateLog('a', '正文', 'log', 'daily', '2026-09-05');
  assert.equal(store.logs[0].importance, 4);
});

test('editor seeds importance from the record and dirty-checks importance changes', async () => {
  const load = createLoader();
  const { LogsState } = load('state/FeatureStates');
  const { LogsController } = load('state/LogsController');
  const state = new LogsState(), r = runtime();
  const item = log('a', '正文', { importance: 2 });
  state.logs = [item];
  const controller = new LogsController(state, r, { updateLog: async () => {} });

  controller.startEditLog(item);
  assert.equal(state.editImportance, 2);
  controller.requestCloseEdit();
  assert.equal(state.editDiscard, false, 'unchanged importance closes without discard prompt');

  controller.startEditLog(item);
  state.editImportance = 4;
  controller.requestCloseEdit();
  assert.equal(state.editDiscard, true, 'importance change counts as unsaved edit');
  controller.closeEdit();
  assert.equal(state.editImportance, 0);
});

function shareKitSpy() {
  const calls = { records: [], shows: [] };
  return { calls, fake: { systemShare: {
    SharedData: class {
      constructor(record) { this.records = [record]; calls.records.push(record); }
      addRecord(record) { this.records.push(record); }
      getRecords() { return this.records; }
    },
    ShareController: class {
      constructor(data) { this.data = data; }
      async show(context, options) { calls.shows.push({ context, options, data: this.data }); }
      on() {}
      off() {}
    },
    SelectionMode: { SINGLE: 0, BATCH: 1 },
    SharePreviewMode: { DEFAULT: 0, DETAIL: 1 } } } };
}

test('log share text carries content and metadata; idea gets its own title', () => {
  const { logShareText } = createLoader()('data/ShareService');
  const text = logShareText(log('a', '一个想法', { category: 'idea', colorTag: 'idea', importance: 0 }));
  assert.ok(text.includes('一个想法'));
  assert.ok(text.includes('2026-09-05'));
  assert.ok(text.includes('想法'));
  assert.ok(!text.includes('重要度'), 'importance 0 stays out of the share text');
  const urgent = logShareText(log('a', '紧急事项', { colorTag: 'urgent', importance: 3 }));
  assert.ok(urgent.includes('重要度 3'));
  assert.ok(urgent.includes('紧急'));
});

test('shareLog builds a plain-text record and shows the panel when supported', async () => {
  const spy = shareKitSpy();
  const load = createLoader({ '@kit.ShareKit': spy.fake });
  const { shareLog } = load('data/ShareService');
  globalThis.canIUse = () => true;
  try {
    const context = { marker: 'ctx' };
    await shareLog(context, log('a', '正文', { category: 'idea' }));
    assert.equal(spy.calls.records.length, 1);
    assert.equal(spy.calls.records[0].utd, 'general.plain-text');
    assert.equal(spy.calls.records[0].title, 'Flash 灵感');
    assert.ok(spy.calls.records[0].content.includes('正文'));
    assert.equal(spy.calls.shows.length, 1);
    assert.equal(spy.calls.shows[0].context, context, 'the ability context is passed through');
  } finally {
    delete globalThis.canIUse;
  }
});

test('share entry refuses to run when the syscap is missing', async () => {
  const spy = shareKitSpy();
  const load = createLoader({ '@kit.ShareKit': spy.fake });
  const { shareLog, systemShareSupported } = load('data/ShareService');
  assert.equal(systemShareSupported(), false, 'no canIUse on the host means unsupported');
  await assert.rejects(shareLog({}, log('a')), /不支持系统分享/);
  assert.equal(spy.calls.shows.length, 0, 'panel never opens without the capability');
});

test('backup file share writes the JSON atomically and shares a file record', async () => {
  const spy = shareKitSpy();
  const load = createLoader({ '@kit.ShareKit': spy.fake });
  const { shareBackupFile } = load('data/ShareService');
  const { BackupService } = load('data/BackupService');
  const cacheDir = fs.mkdtempSync(path.join(os.tmpdir(), 'flash-share-'));
  globalThis.canIUse = () => true;
  try {
    const json = BackupService.exportJSON([log()], [], []);
    await shareBackupFile({ cacheDir }, json, 'flash-aero-backup-2026-10-05.json');
    const target = path.join(cacheDir, 'flash-aero-backup-2026-10-05.json');
    assert.equal(fs.readFileSync(target, 'utf8'), json, 'shared file holds the exact export');
    assert.ok(!fs.existsSync(`${target}.tmp`), 'temp file is renamed away');
    assert.equal(spy.calls.records[0].utd, 'general.file');
    assert.equal(spy.calls.records[0].title, 'flash-aero-backup-2026-10-05.json');
    assert.ok(spy.calls.records[0].uri.length > 0);
  } finally {
    delete globalThis.canIUse;
  }
});

test('BackupController.shareBackupExport end-to-end via the faked ShareKit', async () => {
  const spy = shareKitSpy();
  const load = createLoader({ '@kit.ShareKit': spy.fake });
  const { BackupState } = load('state/FeatureStates');
  const { BackupController } = load('state/BackupController');
  const cacheDir = fs.mkdtempSync(path.join(os.tmpdir(), 'flash-share-'));
  const r = runtime();
  r.context = () => ({ cacheDir });
  globalThis.canIUse = () => true;
  try {
    const controller = new BackupController(new BackupState(), r, {
      ready: true,
      snapshot: () => ({ logs: [log()], emotions: [], tasks: [] })
    });
    await controller.shareBackupExport();
    assert.ok(r.messages.includes('已调起系统分享'));
    assert.equal(spy.calls.shows.length, 1);
    const files = fs.readdirSync(cacheDir).filter(name => name.endsWith('.json'));
    assert.equal(files.length, 1);
    assert.equal(JSON.parse(fs.readFileSync(path.join(cacheDir, files[0]), 'utf8')).version, 'flash-backup-v2');
  } finally {
    delete globalThis.canIUse;
  }
});

test('BackupController.shareBackupExport refuses before the store is ready', async () => {
  const spy = shareKitSpy();
  const load = createLoader({ '@kit.ShareKit': spy.fake });
  const { BackupState } = load('state/FeatureStates');
  const { BackupController } = load('state/BackupController');
  const r = runtime();
  const controller = new BackupController(new BackupState(), r, { ready: false });
  await controller.shareBackupExport();
  assert.ok(r.messages.some(m => m.includes('尚未加载完成')));
  assert.equal(spy.calls.shows.length, 0);
});
