const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createLoader } = require('./ets-loader.cjs');

async function databaseStore(t, raw) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'flash-merge-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const tables = { logs: raw ? [{ id: 'broken', sort_key: '', payload: raw }] : [], emotions: [], tasks: [], idea_view_state: [] };
  const settings = { get: async (k, fallback) => k === 'rdb-migrated-v1' ? true : fallback };
  const db = {
    beginTransaction() {}, commit() {}, rollBack() {},
    executeSql: async sql => { const match = /^DELETE FROM (\w+)/.exec(sql); if (match) tables[match[1]] = []; },
    insert: async (table, row) => { tables[table] = [...tables[table].filter(x => x.id !== row.id), row]; },
    batchInsert: async (table, rows) => { tables[table].push(...rows); },
    querySql: async sql => {
      const rows = tables[/FROM (\w+)/.exec(sql)[1]]; let i = -1;
      return { goToNextRow: () => ++i < rows.length, getString: col => rows[i][col ? 'payload' : 'id'], close() {} };
    }
  };
  const load = createLoader({ '@kit.ArkData': {
    preferences: { getPreferences: async () => settings },
    relationalStore: { SecurityLevel: { S1: 1 }, ConflictResolution: { ON_CONFLICT_REPLACE: 1 }, getRdbStore: async () => db }
  } });
  const store = new (load('data/FlashStore').FlashStore)();
  await store.initialize({ filesDir: dir });
  return { store, tables };
}

test('merge preserves rejected RDB originals when quarantine exceeds its cap', async t => {
  const raw = '{"unrecoverable":' + 'x'.repeat(1024 * 1024);
  const { store, tables } = await databaseStore(t, raw);
  assert.equal(store.ready, true);
  assert.deepEqual(store.logs, []);
  await assert.rejects(store.mergeAll([], [], []), /异常原始记录.*未.*保全/);
  assert.equal(tables.logs[0].payload, raw);
});

test('valid merge and merge after successful quarantine remain available', async t => {
  for (const raw of [undefined, '{broken']) {
    const { store, tables } = await databaseStore(t, raw);
    await store.addLog('retained valid record');
    await store.mergeAll([], [], []);
    assert.equal(store.logs.length, 1);
    assert.equal(JSON.parse(tables.logs.find(row => row.id === store.logs[0].id).payload).content, 'retained valid record');
    if (raw) assert.equal(JSON.parse(JSON.parse(await store.recoveryArchive()).databaseRaw)[0].raw, raw);
  }
});

function reminders() {
  const active = new Map(); const published = []; let id = 0; let onGet, onPublish;
  const manager = {
    ReminderType: { REMINDER_TYPE_CALENDAR: 1 },
    getAllValidReminders: async () => { const snapshot = [...active.values()]; if (onGet) await onGet(); return snapshot; },
    cancelReminder: async key => { active.delete(key); },
    publishReminder: async request => { if (onPublish) await onPublish(); published.push(request); const reminderId = ++id; active.set(reminderId, { reminderId, reminderReq: request }); return reminderId; }
  };
  const load = createLoader({
    'data/IdeaReminderScheduler': null,
    '@kit.BackgroundTasksKit': { reminderAgentManager: manager },
    'data/NotificationChannels': { NotificationChannels: { ensureReminderSlot: async () => {}, reminderSlotType: () => undefined } }
  });
  return { scheduler: load('data/IdeaReminderScheduler').IdeaReminderScheduler, active, published,
    setGet: fn => { onGet = fn; }, setPublish: fn => { onPublish = fn; } };
}

test('changing frequency replaces an existing pending idea reminder', async () => {
  const { scheduler, active, published } = reminders();
  const day = new Date();
  const today = `${day.getFullYear()}-${String(day.getMonth() + 1).padStart(2, '0')}-${String(day.getDate()).padStart(2, '0')}`;
  await scheduler.sync({}, true, 3, 'daily', today, false);
  const first = published[0].dateTime;
  await scheduler.sync({}, true, 3, 'weekly', today, false, true);
  assert.equal(published.length, 2);
  assert.equal(active.size, 1);
  const date = value => new Date(value.year, value.month - 1, value.day, value.hour, value.minute);
  assert.ok(date(published[1].dateTime) > date(first));
});

test('disable supersedes an enabled sync paused at the OS read', async () => {
  const { scheduler, active, published, setGet } = reminders();
  let release, entered;
  const waiting = new Promise(resolve => { entered = resolve; });
  const barrier = new Promise(resolve => { release = resolve; });
  setGet(async () => { entered(); await barrier; });
  const enabling = scheduler.sync({}, true, 3, 'daily', '', false);
  await waiting;
  setGet(undefined);
  const disabling = scheduler.sync({}, false, 3, 'daily', '', false);
  release();
  await Promise.all([enabling, disabling]);
  assert.equal(active.size, 0);
  assert.equal(published.length, 0, 'superseded enabled work must not publish');
});

test('ordinary sync preserves a pending schedule but cannot swallow a frequency change', async () => {
  const { scheduler, published, active } = reminders();
  await scheduler.sync({}, true, 3, 'daily', '', false);
  await scheduler.sync({}, true, 4, 'daily', '', false);
  assert.equal(published.length, 1, 'ordinary log updates must not postpone a pending reminder');
  const changed = scheduler.sync({}, true, 4, 'weekly', '', false, true);
  const logChanged = scheduler.sync({}, true, 5, 'weekly', '', false);
  await Promise.all([changed, logChanged]);
  assert.equal(published.length, 2);
  assert.equal(active.size, 1);
  assert.match(published[1].content, /5/);
});

test('disable cleans a publication already in flight and later enable still works', async () => {
  const { scheduler, active, setPublish } = reminders();
  let release, entered;
  const waiting = new Promise(resolve => { entered = resolve; });
  const barrier = new Promise(resolve => { release = resolve; });
  setPublish(async () => { entered(); await barrier; });
  const enabling = scheduler.sync({}, true, 3, 'daily', '', false);
  await waiting;
  const disabling = scheduler.sync({}, false, 3, 'daily', '', false);
  release();
  await Promise.all([enabling, disabling]);
  assert.equal(active.size, 0);
  setPublish(undefined);
  await scheduler.sync({}, true, 3, 'daily', '', false);
  assert.equal(active.size, 1);
});

test('settings frequency changes request replacement while ordinary controller sync does not', async () => {
  const calls = [];
  const load = createLoader({
    '@kit.ArkData': { preferences: { getPreferences: async () => ({ put: async () => {}, flush: async () => {} }) } },
    'data/FlashStore': { FlashStore: { instance: { unviewedIdeas: () => [{}, {}, {}] } } },
    'data/IdeaReminderScheduler': { IdeaReminderScheduler: { sync: async (...args) => { calls.push(args); return false; } } }
  });
  const app = new (load('state/AppController').AppController)();
  app.runtime.bind({});
  try {
    app.setIdeaReminder(true, 'weekly');
    app.syncIdeaReminder();
    assert.equal(calls[0][3], 'weekly');
    assert.equal(calls[0][6], true);
    assert.equal(calls[1][3], 'weekly');
    assert.equal(calls[1][6], false);
  } finally { app.dispose(); }
});
