// PR #3 F-08: a merge must only add or replace incoming rows. It used to rewrite
// every table from validated memory, deleting rows the UI said were preserved.
const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');
const seed = require('../../docs/contracts/fixtures/valid-schema2.json');

function database() {
  const rows = { logs: [], emotions: [], tasks: [], idea_view_state: [] };
  let saved;
  const db = { rows, failAfterInserts: Infinity, inserts: 0, deletes: 0,
    beginTransaction() { assert.equal(saved, undefined); saved = structuredClone(rows); },
    commit() { saved = undefined; },
    rollBack() { assert.ok(saved); for (const key of Object.keys(rows)) rows[key] = saved[key]; saved = undefined; },
    async executeSql(sql, args) {
      const table = sql.match(/FROM\s+(\w+)/)[1];
      db.deletes++;
      rows[table] = args ? rows[table].filter(row => row.id !== args[0]) : [];
    },
    async insert(table, row) {
      if (db.inserts++ >= db.failAfterInserts) throw new Error('fictional insert failure');
      rows[table] = rows[table].filter(item => item.id !== row.id);
      rows[table].push({ ...row });
    },
    async batchInsert(table, values) { for (const row of values) await db.insert(table, row); }
  };
  return db;
}

function setup() {
  const load = createLoader();
  const input = load('data/BackupService').BackupService.parseStrict(JSON.stringify(seed));
  const store = new (load('data/FlashStore').FlashStore)();
  const db = database();
  store.initialized = true; store.database = db;
  return { input, store, db };
}

test('merge keeps rows that failed validation and were hidden from memory', async () => {
  const { input, store, db } = setup();
  const quarantined = { id: '99999999-9999-4999-8999-999999999999', sort_key: 'x', payload: '{"not":"valid"}' };
  db.rows.logs.push({ ...quarantined });
  db.rows.tasks.push({ ...quarantined });
  await store.mergeAll(input.logs, input.emotions, input.tasks);
  assert.deepEqual(db.rows.logs.find(row => row.id === quarantined.id), quarantined);
  assert.deepEqual(db.rows.tasks.find(row => row.id === quarantined.id), quarantined);
  assert.equal(db.rows.logs.length, input.logs.length + 1);
  assert.equal(db.deletes, 0, 'a merge never issues a DELETE');
});

test('merge writes incoming rows, replaces same IDs and keeps local-only rows', async () => {
  const { input, store, db } = setup();
  const [first, ...rest] = input.logs;
  await store.replaceAll([first], [], []);
  const edited = { ...first, content: 'incoming version' };
  await store.mergeAll([edited, ...rest], input.emotions, input.tasks);
  assert.equal(store.logs.find(item => item.id === first.id).content, 'incoming version');
  assert.equal(JSON.parse(db.rows.logs.find(row => row.id === first.id).payload).content, 'incoming version');
  assert.equal(db.rows.logs.length, input.logs.length);
  assert.equal(db.rows.tasks.length, input.tasks.length);
});

test('merge keeps the newer local task instead of writing an older incoming one', async () => {
  const { input, store, db } = setup();
  const task = input.tasks[0];
  const newer = { ...task, title: 'newer local', updatedAt: '2099-01-01T00:00:00.000Z' };
  await store.replaceAll([], [], [newer]);
  await store.mergeAll([], [], [task]);
  assert.equal(store.tasks[0].title, 'newer local');
  assert.equal(JSON.parse(db.rows.tasks.find(row => row.id === task.id).payload).title, 'newer local');
});

test('a failed merge rolls back rows and leaves memory unchanged', async () => {
  const { input, store, db } = setup();
  await store.replaceAll([input.logs[0]], [], []);
  const beforeRows = structuredClone(db.rows), before = store.snapshot();
  db.inserts = 0; db.failAfterInserts = 1;
  await assert.rejects(store.mergeAll(input.logs, input.emotions, input.tasks), /fictional insert failure/);
  assert.deepEqual(db.rows, beforeRows);
  assert.deepEqual(store.snapshot(), before);
});
