const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createLoader } = require('./ets-loader.cjs');

function log(id = '11111111-1111-1111-1111-111111111111', content = '记录') {
  return { id, content, category: 'log', colorTag: 'daily', importance: 0,
    recordDate: '2026-09-05', createdAt: '2026-09-05T00:00:00.000Z' };
}
function taskItem() {
  return { id: '33333333-3333-3333-3333-333333333333', title: '任务', colorTag: 'memo',
    importance: 0, due: { kind: 'allDay', date: '2026-09-05' },
    createdAt: '2026-09-05T00:00:00.000Z', updatedAt: '2026-09-05T00:00:00.000Z' };
}
function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}
function runtime() {
  const messages = [];
  return { messages, context: () => ({}), notify: m => messages.push(m), errorMessage: e => e.message };
}

test('log publication preserves emotion/task identities and unsaved drafts', () => {
  const load = createLoader();
  const { AppSession } = load('state/FeatureStates');
  const { FeatureProjection } = load('state/FeatureProjection');
  const { StorePartition: P } = load('data/StoreChanges');
  const state = new AppSession();
  let searches = 0;
  const projection = new FeatureProjection(state, t => t.due.date, () => searches++);
  const data = { logs: [log()], emotions: [{ id: 'emotion', level: 2, recordDate: '2026-09-05' }], tasks: [taskItem()] };
  projection.update(P.ALL, data);
  const emotions = state.emotion.emotions;
  const tasks = state.calendar.tasks;
  const emotionIndex = state.calendar.emotionsByDay;
  const taskIndex = state.calendar.tasksByDay;
  state.logs.captureText = '未保存灵感';
  state.calendar.taskTitle = '未保存任务';
  state.logs.logDisplayLimit = 100;
  projection.update(P.LOGS, { ...data, logs: [log(undefined, '已更新')] });
  assert.equal(state.emotion.emotions, emotions);
  assert.equal(state.calendar.tasks, tasks);
  assert.equal(state.calendar.emotionsByDay, emotionIndex);
  assert.equal(state.calendar.tasksByDay, taskIndex);
  assert.equal(state.home.recentLogs[0].content, '已更新');
  assert.equal(state.logs.captureText, '未保存灵感');
  assert.equal(state.calendar.taskTitle, '未保存任务');
  assert.equal(state.logs.logDisplayLimit, 100);
  assert.equal(searches, 2);
  const logs = state.logs.logs;
  const logIndex = state.calendar.logsByDay;
  projection.update(P.TASKS, { ...data, tasks: [] });
  assert.equal(state.logs.logs, logs);
  assert.equal(state.calendar.logsByDay, logIndex);
  assert.equal(searches, 2, 'task writes must not re-run log search');
  projection.update(P.ALL, { logs: [], emotions: [], tasks: [] });
  assert.deepEqual(state.calendar.activityDays, []);
  assert.deepEqual(state.home.recentLogs, []);
});

test('day rollover updates counts without replacing partition arrays or indexes', () => {
  const load = createLoader();
  const { AppSession } = load('state/FeatureStates');
  const { FeatureProjection } = load('state/FeatureProjection');
  const { StorePartition: P } = load('data/StoreChanges');
  const { dayString } = load('data/DateUtils');
  const state = new AppSession();
  const projection = new FeatureProjection(state, t => t.due.date, () => {});
  projection.update(P.ALL, { logs: [{ ...log(), recordDate: dayString() }], emotions: [], tasks: [] });
  const logs = state.logs.logs, index = state.calendar.logsByDay;
  state.home.todayLogCount = 99;
  projection.updateDay();
  assert.equal(state.home.todayLogCount, 1);
  assert.equal(state.logs.logs, logs);
  assert.equal(state.calendar.logsByDay, index);
});

test('subscriptions detach and an observer failure does not mask a successful commit', () => {
  const { StoreChanges, StorePartition: P } = createLoader()('data/StoreChanges');
  const changes = new StoreChanges();
  const seen = [];
  const detach = changes.subscribe(p => seen.push(p));
  changes.publish(P.LOGS);
  detach();
  changes.publish(P.TASKS);
  assert.deepEqual(seen, [P.LOGS]);
  changes.subscribe(() => { throw new Error('broken observer'); });
  changes.subscribe(p => seen.push(p));
  assert.doesNotThrow(() => changes.publish(P.EMOTIONS));
  assert.deepEqual(seen, [P.LOGS, P.EMOTIONS]);
});

test('Store serializes concurrent writes and publishes only after success; failure does not poison queue', async () => {
  const load = createLoader();
  const { FlashStore } = load('data/FlashStore');
  const store = new FlashStore();
  const gate = deferred();
  let count = 0;
  const calls = [], events = [];
  // Native adapter fake; execute actual public Store operations and queue.
  store.database = { insert: async table => {
    calls.push(table);
    if (++count === 1) await gate.promise;
    if (count === 2) throw new Error('disk full');
  } };
  store.initialized = true;
  store.changes.subscribe(p => events.push(p));
  const first = store.addLog('one');
  const second = store.addEmotion(1);
  const failed = assert.rejects(second, /disk full/);
  const third = store.addLog('three');
  await Promise.resolve();
  assert.deepEqual(calls, ['logs']);
  assert.deepEqual(events, []);
  assert.deepEqual(store.logs, []);
  gate.resolve();
  await Promise.all([first, failed, third]);
  assert.deepEqual(calls, ['logs', 'emotions', 'logs']);
  assert.deepEqual(events, ['logs', 'logs']);
  assert.deepEqual(store.logs.map(l => l.content), ['three', 'one']);
  assert.deepEqual(store.emotions, []);
});

test('failed destructive transaction leaves memory unchanged and emits no ALL publication', async () => {
  const { FlashStore } = createLoader()('data/FlashStore');
  const store = new FlashStore();
  store.initialized = true;
  store.logs = [log()];
  const previous = store.logs;
  let rollback = 0, commits = 0;
  const events = [];
  store.changes.subscribe(p => events.push(p));
  store.database = {
    beginTransaction() {}, executeSql: async () => {},
    batchInsert: async () => { throw new Error('injected write failure'); },
    commit() { commits++; }, rollBack() { rollback++; }
  };
  await assert.rejects(store.replaceAll([log(undefined, 'import')], [], []), /injected/);
  assert.equal(store.logs, previous);
  assert.equal(rollback, 1);
  assert.equal(commits, 0);
  assert.deepEqual(events, []);
  await store.clearAll();
  assert.deepEqual(store.logs, []);
  assert.deepEqual(events, ['all']);
  assert.equal(commits, 1);
});

test('feature busy flags prevent duplicate saves, preserve failed drafts and do not block other features', async () => {
  const load = createLoader();
  const { AppSession } = load('state/FeatureStates');
  const { LogsController } = load('state/LogsController');
  const { EmotionController } = load('state/EmotionController');
  const state = new AppSession(), r = runtime(), gate = deferred();
  let logSaves = 0, emotionSaves = 0;
  const store = { addLog: async () => { logSaves++; await gate.promise; },
    addEmotion: async () => { emotionSaves++; } };
  const logs = new LogsController(state.logs, r, store);
  const emotions = new EmotionController(state.emotion, r, store);
  state.backup.fileBusy = true;
  state.logs.captureText = 'keep this draft';
  const first = logs.saveCapture();
  await logs.saveCapture();
  await emotions.saveEmotion();
  assert.equal(logSaves, 1);
  assert.equal(emotionSaves, 1);
  assert.equal(state.logs.busy, true);
  gate.reject(new Error('disk full'));
  await first;
  assert.equal(state.logs.captureText, 'keep this draft');
  assert.equal(state.logs.busy, false);
  assert.equal(state.emotion.busy, false);
  assert.ok(r.messages.includes('disk full'));
});

test('task save failure retains editor and suppresses double submit', async () => {
  const load = createLoader();
  const { CalendarState } = load('state/FeatureStates');
  const { CalendarController } = load('state/CalendarController');
  const state = new CalendarState(), r = runtime(), gate = deferred();
  let saves = 0;
  const controller = new CalendarController(state, r, { saveTask: async () => { saves++; await gate.promise; } });
  controller.openTaskEditor(undefined, '2026-09-05');
  state.taskTitle = '任务草稿';
  const first = controller.saveTaskEditor();
  await controller.saveTaskEditor();
  assert.equal(saves, 1);
  gate.reject(new Error('task disk failure'));
  await first;
  assert.equal(state.editingTaskId, 'new');
  assert.equal(state.taskTitle, '任务草稿');
  assert.equal(state.busy, false);
  assert.ok(r.messages.includes('task disk failure'));
});

test('cancelled discovery/receive and old sender failure cannot overwrite the new LAN session', async () => {
  const senders = [], discoveries = [], receivers = [];
  const load = createLoader({ 'data/LocalBackupTransfer': {
    LocalBackupSender: class {
      constructor(context, json, done) { this.done = done; this.pin = '1234'; this.gate = deferred(); senders.push(this); }
      start() { return this.gate.promise; }
      stop() { this.done(false); }
    },
    LocalBackupDiscovery: class {
      constructor(context, changed) { this.changed = changed; discoveries.push(this); }
      start() {} stop() {}
    },
    LocalBackupReceiver: { start() {
      const gate = deferred();
      const receiver = { gate, result: gate.promise, cancel() { gate.reject(new Error('cancelled')); } };
      receivers.push(receiver); return receiver;
    } }
  } });
  const { BackupState, TransferPhase: P } = load('state/FeatureStates');
  const { BackupController } = load('state/BackupController');
  const state = new BackupState(), r = runtime();
  const controller = new BackupController(state, r, { ready: true, snapshot: () => ({ logs: [], emotions: [], tasks: [] }) });
  const old = controller.startLanSend();
  controller.startLanReceive();
  senders[0].gate.reject(new Error('late failure'));
  await old;
  assert.equal(state.lanMode, P.RECEIVING);
  discoveries[0].changed([{ id: 'device', name: 'sender' }]);
  state.selectedLanDevice = 'device'; state.lanEnteredPin = '1234';
  const receiving = controller.receiveLan();
  controller.stopLan();
  controller.startLanReceive();
  discoveries[0].changed([{ id: 'stale', name: 'stale' }]);
  await receiving;
  assert.equal(state.lanMode, P.RECEIVING);
  assert.deepEqual(state.lanDevices, []);
  assert.equal(state.importSummary, '');
  assert.equal(r.messages.length, 0);
});

test('import failure retains preview for retry and disposal ignores pending picker result', async () => {
  const gate = deferred();
  const load = createLoader({ 'data/BackupFiles': { BackupFiles: { importJSON: () => gate.promise } } });
  const { BackupState, ImportPhase: P } = load('state/FeatureStates');
  const { BackupController } = load('state/BackupController');
  const { BackupService } = load('data/BackupService');
  const state = new BackupState(), r = runtime();
  let fail = true;
  const controller = new BackupController(state, r, {
    ready: true,
    snapshot: () => ({ logs: [], emotions: [], tasks: [] }),
    mergeAll: async () => { if (fail) throw new Error('import failure'); }
  });
  const json = BackupService.exportJSON([log()], [], []);
  controller.stageImport(BackupService.parse(json));
  assert.equal(state.importPhase, P.PREVIEW);
  await controller.applyBackup(true);
  assert.equal(state.importPhase, P.PREVIEW);
  assert.equal(state.busy, false);
  assert.ok(state.importSummary.length > 0);
  fail = false;
  await controller.applyBackup(true);
  assert.equal(state.importPhase, P.IDLE);
  const picking = controller.chooseBackup();
  controller.dispose();
  gate.resolve(json);
  await picking;
  assert.equal(state.importPhase, P.IDLE);
  assert.equal(state.fileBusy, false);
});

test('root lifecycle detaches subscriptions and ignores preparation completed after disposal', async () => {
  const base = createLoader();
  const { StoreChanges, StorePartition: P } = base('data/StoreChanges');
  const gate = deferred();
  const store = { logs: [log()], emotions: [], tasks: [], changes: new StoreChanges(),
    themeMode: 'dark', welcomed: true, hasRecoveryData: false, recoveryWarning: '',
    initialize: () => gate.promise };
  const load = createLoader({ 'data/FlashStore': { FlashStore: { instance: store } } });
  const { AppController } = load('state/AppController');
  const app = new AppController();
  const themes = [];
  const preparing = app.prepare({}, mode => themes.push(mode));
  app.dispose();
  gate.resolve();
  await preparing;
  assert.deepEqual(app.session.logs.logs, []);
  assert.deepEqual(themes, []);
  try {
    await app.prepare({}, mode => themes.push(mode));
    assert.deepEqual(themes, ['dark']);
    assert.equal(app.session.logs.logs.length, 1);
    store.logs = [log(undefined, 'mounted update')];
    store.changes.publish(P.LOGS);
    assert.equal(app.session.logs.logs[0].content, 'mounted update');
  } finally { app.dispose(); }
  store.logs = [];
  store.changes.publish(P.LOGS);
  assert.equal(app.session.logs.logs.length, 1, 'disposed root must not retain a Store observer');
  assert.throws(() => app.runtime.context(), /页面尚未准备完成/);
});

function memoryPreferences(seed = {}) {
  const data = { ...seed };
  return { data,
    get: async (key, fallback) => (key in data ? data[key] : fallback),
    put: async (key, value) => { data[key] = value; },
    delete: async key => { delete data[key]; },
    flush: async () => {} };
}

function memoryRdb(tables = { logs: [], emotions: [], tasks: [] }) {
  return { tables,
    beginTransaction() {}, commit() {}, rollBack() {},
    executeSql: async (sql, args) => {
      const match = sql.match(/FROM\s+(\w+)/);
      if (!match || !sql.startsWith('DELETE')) return;
      const table = match[1];
      tables[table] = args ? tables[table].filter(row => row.id !== args[0]) : [];
    },
    insert: async (table, bucket) => {
      tables[table] = tables[table].filter(row => row.id !== bucket.id);
      tables[table].push({ id: bucket.id, sort_key: bucket.sort_key, payload: bucket.payload });
    },
    batchInsert: async (table, buckets) => {
      for (const bucket of buckets) {
        tables[table] = tables[table].filter(row => row.id !== bucket.id);
        tables[table].push({ id: bucket.id, sort_key: bucket.sort_key, payload: bucket.payload });
      }
    },
    querySql: async sql => {
      const table = sql.match(/FROM\s+(\w+)/)[1];
      const rows = tables[table].slice().sort((a, b) => b.sort_key.localeCompare(a.sort_key));
      let index = -1;
      return { goToNextRow: () => ++index < rows.length,
        getString: column => (column === 0 ? rows[index].id : rows[index].payload), close() {} };
    } };
}

function arkDataOverride(prefs, db) {
  return { '@kit.ArkData': {
    preferences: { getPreferences: async () => prefs },
    relationalStore: { SecurityLevel: { S1: 1 }, ConflictResolution: { ON_CONFLICT_REPLACE: 1 },
      getRdbStore: async () => db } } };
}

function failingCoreFileKit() {
  return { '@kit.CoreFileKit': { fileIo: {
    OpenMode: { READ_ONLY: 0, READ_WRITE: 2, CREATE: 64, TRUNC: 512 },
    accessSync: () => true, mkdirSync: () => {},
    openSync: () => ({ fd: 1 }),
    writeSync: () => { throw new Error('read-only filesystem'); },
    readSync: () => 0, statSync: () => ({ size: 0 }), closeSync: () => {} } } };
}

test('oversized corrupt RDB payload is quarantined to a sandbox file and never blocks startup', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'flash-quarantine-'));
  // > 8 KB: the old Preferences quarantine would have thrown on settings.put.
  const big = '{"id":"broken","content":"' + 'a'.repeat(20000);
  const prefs = memoryPreferences({ 'rdb-migrated-v1': true });
  const db = memoryRdb({ logs: [{ id: 'broken', sort_key: '2026-09-05', payload: big }], emotions: [], tasks: [] });
  const load = createLoader(arkDataOverride(prefs, db));
  const { FlashStore } = load('data/FlashStore');
  const store = new FlashStore();
  await store.initialize({ filesDir: dir });
  assert.deepEqual(store.logs, []);
  assert.ok(store.hasRecoveryData);
  assert.ok(store.recoveryWarning.includes('隔离'));
  assert.ok(!Object.keys(prefs.data).some(key => key.startsWith('recovery-')),
    'quarantine data must not be written to Preferences');
  const entries = JSON.parse(fs.readFileSync(path.join(dir, 'quarantine', 'rdb-payloads.json'), 'utf8'));
  assert.equal(entries.length, 1);
  assert.equal(entries[0].raw, big);
  assert.equal(entries[0].reason, 'malformed-json');
  const archive = JSON.parse(await store.recoveryArchive());
  assert.equal(JSON.parse(archive.databaseRaw)[0].raw, big);
});

test('quarantine write failure degrades to a warning and never fails initialize', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'flash-quarantine-'));
  const big = '{"id":"broken","content":"' + 'a'.repeat(20000);
  const prefs = memoryPreferences({ 'rdb-migrated-v1': true });
  const db = memoryRdb({ logs: [{ id: 'broken', sort_key: '2026-09-05', payload: big }], emotions: [], tasks: [] });
  const load = createLoader({ ...arkDataOverride(prefs, db), ...failingCoreFileKit() });
  const { FlashStore } = load('data/FlashStore');
  const store = new FlashStore();
  await store.initialize({ filesDir: dir });
  assert.deepEqual(store.logs, []);
  assert.ok(store.hasRecoveryData);
  assert.ok(store.recoveryWarning.includes('写入失败'));
  assert.ok(store.recoveryWarning.includes('仍保留在数据库中'));
});

test('legacy Preferences quarantine is moved to sandbox files exactly once', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'flash-quarantine-'));
  const prefs = memoryPreferences({
    'rdb-migrated-v1': true,
    'recovery-legacy-logs-json': '[{"legacy":true}]',
    'recovery-rdb-payloads-json':
      '[{"table":"logs","id":"a","raw":"{}","reason":"malformed-json","capturedAt":"2026-01-01T00:00:00.000Z"}]'
  });
  const db = memoryRdb();
  const load = createLoader(arkDataOverride(prefs, db));
  const { FlashStore } = load('data/FlashStore');
  const store = new FlashStore();
  await store.initialize({ filesDir: dir });
  assert.equal(prefs.data['recovery-legacy-logs-json'], undefined, 'legacy key removed after move');
  assert.equal(prefs.data['recovery-rdb-payloads-json'], undefined, 'legacy key removed after move');
  assert.equal(fs.readFileSync(path.join(dir, 'quarantine', 'legacy-logs.json'), 'utf8'), '[{"legacy":true}]');
  assert.ok(store.hasRecoveryData);
  // A restart on the same sandbox must stay intact and keep the archive exportable.
  const restarted = new FlashStore();
  await restarted.initialize({ filesDir: dir });
  assert.ok(restarted.hasRecoveryData);
  const archive = JSON.parse(await restarted.recoveryArchive());
  assert.equal(archive.raw.logs, '[{"legacy":true}]');
  assert.equal(JSON.parse(archive.databaseRaw)[0].id, 'a');
});

test('invalid all-day dates are rejected before save while valid days pass', async () => {
  const load = createLoader();
  const { CalendarState } = load('state/FeatureStates');
  const { CalendarController } = load('state/CalendarController');
  const state = new CalendarState(), r = runtime();
  let saves = 0;
  const controller = new CalendarController(state, r, { saveTask: async () => { saves++; } });

  // Round-trip guard: impossible days and out-of-range years never parse.
  assert.equal(controller.localDateToInstant('2026-02-30', '09:00', 'UTC'), undefined);
  assert.equal(controller.localDateToInstant('2025-02-29', '09:00', 'UTC'), undefined);
  assert.equal(controller.localDateToInstant('0000-06-15', '09:00', 'UTC'), undefined);
  assert.equal(controller.localDateToInstant('2026-09-05', '25:00', 'UTC'), undefined);
  assert.equal(controller.localDateToInstant('2024-02-29', '09:00', 'UTC').toISOString(), '2024-02-29T09:00:00.000Z');
  // Years 0001-0099 must stay intact instead of Date.UTC mapping them to 1900+.
  assert.equal(controller.localDateToInstant('0099-01-01', '09:00', 'UTC').toISOString(), '0099-01-01T09:00:00.000Z');

  controller.openTaskEditor(undefined, '2026-09-05');
  state.taskTitle = '任务';
  state.taskDate = '2026-02-30';
  await controller.saveTaskEditor();
  assert.equal(saves, 0, 'impossible day must not reach the store');
  assert.equal(state.editingTaskId, 'new', 'editor stays open on invalid date');
  assert.ok(r.messages.includes('请输入有效的日期和时间'));

  state.taskDate = '2026-02-28';
  await controller.saveTaskEditor();
  assert.equal(saves, 1);
  assert.equal(state.editingTaskId, '', 'valid day saves and closes the editor');
});
