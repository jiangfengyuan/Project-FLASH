const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');
const seed = require('../../docs/contracts/fixtures/valid-schema2.json');

// Faithful commit/rollback of rows; no claim about native RDB power-loss behavior.
function database() {
  const rows = { logs: [], emotions: [], tasks: [], idea_view_state: [] };
  let saved;
  const db = { rows, fail: '',
    beginTransaction() { assert.equal(saved, undefined); saved = structuredClone(rows); },
    commit() { saved = undefined; },
    rollBack() { assert.ok(saved); for (const key of Object.keys(rows)) rows[key] = saved[key]; saved = undefined; },
    async executeSql(sql, args) {
      const table = sql.match(/FROM\s+(\w+)/)[1];
      if (table === 'idea_view_state' && db.fail === 'delete') throw new Error('fictional read-state delete failure');
      rows[table] = args ? rows[table].filter(row => row.id !== args[0]) : [];
    },
    async insert(table, row) {
      rows[table] = rows[table].filter(item => item.id !== row.id);
      rows[table].push({ ...row });
    },
    async batchInsert(table, values) {
      if (table === 'idea_view_state' && db.fail === 'insert') throw new Error('fictional read-state insert failure');
      for (const row of values) await db.insert(table, row);
    }
  };
  return db;
}

for (const [operation, failure] of [['overwrite', 'delete'], ['conditional', 'insert'], ['clear', 'delete'], ['deleteLog', 'delete']]) {
  test(`${operation}: read-state IO failure leaves business rows, memory and viewed state unchanged`, async () => {
    const load = createLoader();
    const input = load('data/BackupService').BackupService.parseStrict(JSON.stringify(seed));
    input.logs.forEach(item => { item.category = 'idea'; });
    const store = new (load('data/FlashStore').FlashStore)(), db = database();
    store.initialized = true; store.database = db;
    await store.replaceAll(input.logs, input.emotions, input.tasks);
    for (const log of input.logs) await store.markIdeaViewed(log.id);
    const beforeRows = structuredClone(db.rows), before = store.snapshot();
    const viewed = [...store.viewedIdeaIds];
    const surviving = [input.logs[0]], removedID = input.logs[1].id;
    const perform = () => operation === 'overwrite' ? store.replaceAll(surviving, [], []) :
      operation === 'conditional' ? store.replaceAllIfCurrent(surviving, [], [], before) :
      operation === 'clear' ? store.clearAll() : store.deleteLog(removedID);
    let published = 0; store.changes.subscribe(() => { published++; });
    db.fail = failure;
    await assert.rejects(perform(), /fictional read-state/);
    assert.deepEqual(db.rows, beforeRows, 'failed operation must roll back business and read-state rows');
    assert.deepEqual(store.snapshot(), before, 'published business state is unchanged');
    assert.deepEqual([...store.viewedIdeaIds], viewed, 'published read-state is unchanged');
    assert.equal(published, 0, 'failed transaction publishes no invalidation');
    db.fail = '';
    await perform();
    assert.equal(published, 1, 'successful retry publishes exactly once');
    const ids = new Set(store.logs.map(item => item.id));
    assert.deepEqual(new Set(store.viewedIdeaIds.keys()), ids, 'successful retry prunes only removed records');
    assert.deepEqual(new Set(db.rows.idea_view_state.map(row => row.id)), ids);
    if (operation !== 'clear') assert.equal(store.logs[0].isFavorite, true, 'schema2 metadata retained');
  });
}
