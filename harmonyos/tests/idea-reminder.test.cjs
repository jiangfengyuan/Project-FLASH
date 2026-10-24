// D1 Idea Reminder：未读判定、标记已读、重启持久化、备份导出不含已读数据。
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createLoader } = require('./ets-loader.cjs');

function memoryPreferences(seed = {}) {
  const data = { ...seed };
  return { data,
    get: async (key, fallback) => (key in data ? data[key] : fallback),
    put: async (key, value) => { data[key] = value; },
    delete: async key => { delete data[key]; },
    flush: async () => {} };
}

function memoryRdb(tables = {}) {
  for (const name of ['logs', 'emotions', 'tasks', 'idea_view_state']) {
    if (!tables[name]) tables[name] = [];
  }
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

async function freshStore(seed) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'flash-ideas-'));
  const prefs = memoryPreferences({ 'rdb-migrated-v1': true, ...seed?.prefs });
  const db = seed?.db ?? memoryRdb();
  const load = createLoader({ '@kit.ArkData': {
    preferences: { getPreferences: async () => prefs },
    relationalStore: { SecurityLevel: { S1: 1 }, ConflictResolution: { ON_CONFLICT_REPLACE: 1 },
      getRdbStore: async () => db } } });
  const { FlashStore } = load('data/FlashStore');
  const store = new FlashStore();
  await store.initialize({ filesDir: dir });
  return { store, prefs, db, dir, load };
}

test('reminder threshold matches Android: at least three unviewed ideas', () => {
  const { shouldShowIdeaReminder, IDEA_REMINDER_THRESHOLD } = createLoader()('data/IdeaReminder');
  assert.equal(IDEA_REMINDER_THRESHOLD, 3);
  assert.equal(shouldShowIdeaReminder(0), false);
  assert.equal(shouldShowIdeaReminder(2), false);
  assert.equal(shouldShowIdeaReminder(3), true);
  assert.equal(shouldShowIdeaReminder(9), true);
});

test('unviewed ideas are unread idea-category logs only', async () => {
  const { store } = await freshStore();
  await store.addLog('普通日志', 'log');
  await store.addLog('灵感一', 'idea');
  await store.addLog('灵感二', 'idea');
  const unviewed = store.unviewedIdeas();
  assert.equal(unviewed.length, 2);
  assert.ok(unviewed.every(item => item.category === 'idea'));
});

test('markIdeaViewed marks one idea once and publishes a single logs change', async () => {
  const { store } = await freshStore();
  await store.addLog('灵感一', 'idea');
  const id = store.logs[0].id;
  const events = [];
  store.changes.subscribe(p => events.push(p));
  await store.markIdeaViewed(id);
  assert.deepEqual(store.unviewedIdeas(), []);
  assert.deepEqual(events, ['logs']);
  await store.markIdeaViewed(id);
  assert.deepEqual(events, ['logs'], 're-marking must not write or publish again');
});

test('markAllIdeasViewed clears the queue; empty queue publishes nothing', async () => {
  const { store } = await freshStore();
  await store.addLog('灵感一', 'idea');
  await store.addLog('灵感二', 'idea');
  const events = [];
  store.changes.subscribe(p => events.push(p));
  await store.markAllIdeasViewed();
  assert.deepEqual(store.unviewedIdeas(), []);
  assert.deepEqual(events, ['logs']);
  await store.markAllIdeasViewed();
  assert.deepEqual(events, ['logs']);
});

test('view state persists across restarts and survives snapshot/export exclusion', async () => {
  const first = await freshStore();
  await first.store.addLog('灵感一', 'idea');
  await first.store.addLog('灵感二', 'idea');
  await first.store.markIdeaViewed(first.store.logs[1].id);

  // 重启：同一 prefs/db 上的新实例重新加载已读状态。
  const prefs = first.prefs;
  const db = first.db;
  const load = createLoader({ '@kit.ArkData': {
    preferences: { getPreferences: async () => prefs },
    relationalStore: { SecurityLevel: { S1: 1 }, ConflictResolution: { ON_CONFLICT_REPLACE: 1 },
      getRdbStore: async () => db } } });
  const { FlashStore } = load('data/FlashStore');
  const restarted = new FlashStore();
  await restarted.initialize({ filesDir: first.dir });
  assert.equal(restarted.logs.length, 2);
  assert.equal(restarted.unviewedIdeas().length, 1);

  // 备份快照与导出文本都不含已读数据（本地界面状态，不进 flash-backup-v2）。
  const snapshot = restarted.snapshot();
  assert.deepEqual(Object.keys(snapshot).sort(), ['emotions', 'logs', 'tasks']);
  const { BackupService } = load('data/BackupService');
  const json = BackupService.exportJSON(snapshot.logs, snapshot.emotions, snapshot.tasks);
  assert.ok(!json.includes('viewedAt'));
  assert.ok(!json.includes('idea_view_state'));
  // 已读表的物理行也不在备份文件里。
  assert.ok(db.tables.idea_view_state.length > 0, 'local view state stays in the local database');
});

test('deleteLog cascades view state; replaceAll prunes dangling rows; clearAll wipes', async () => {
  const { store, db } = await freshStore();
  await store.addLog('灵感一', 'idea');
  await store.addLog('灵感二', 'idea');
  await store.markAllIdeasViewed();
  assert.equal(db.tables.idea_view_state.length, 2);

  const doomed = store.logs[0].id;
  await store.deleteLog(doomed);
  assert.equal(db.tables.idea_view_state.length, 1);
  assert.ok(!db.tables.idea_view_state.some(row => row.id === doomed));

  // 覆盖导入移除本地记录后，已读状态不悬空。
  await store.replaceAll([], [], []);
  assert.equal(db.tables.idea_view_state.length, 0);

  await store.addLog('灵感三', 'idea');
  await store.markAllIdeasViewed();
  await store.clearAll();
  assert.equal(db.tables.idea_view_state.length, 0);
  assert.deepEqual(store.unviewedIdeas(), []);
});
