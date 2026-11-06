const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createLoader } = require('./ets-loader.cjs');
const schema2 = require('../../docs/contracts/fixtures/valid-schema2.json');
const codec = () => createLoader()('data/BackupService').BackupService;

test('schema2 optional metadata survives the actual codec round trip', () => {
  const service = codec();
  const imported = service.parseStrict(JSON.stringify(schema2));
  const exported = service.exportJSON(imported.logs, imported.emotions, imported.tasks);
  const decoded = service.parseStrict(exported);
  for (const section of ['logs', 'emotions', 'tasks']) assert.deepEqual(decoded[section], imported[section]);
  const data = JSON.parse(exported).data;
  assert.equal(data.logs[0].isFavorite, true);
  assert.equal(data.emotions[0].intensity, 4);
  assert.equal(data.emotions[0].isFavorite, false);
  assert.equal(data.tasks[0].sourceLogId, '55555555-5555-4555-8555-555555555555');
  assert.equal(data.tasks[0].isFavorite, true);
});

test('schema2 keeps field types, declared section versions and future-field rejection', () => {
  const service = codec();
  for (const [field, value] of [['isFavorite', 1], ['intensity', true], ['intensity', 4.5], ['intensity', 0], ['intensity', 6]]) {
    const input = structuredClone(schema2); input.data.emotions[0][field] = value;
    assert.throws(() => service.parseStrict(JSON.stringify(input)));
  }
  const schema1 = structuredClone(schema2); schema1.schemas.logs = 1;
  assert.throws(() => service.parseStrict(JSON.stringify(schema1)));
  assert.throws(() => service.parseRecovery(JSON.stringify(schema1)));
  const future = structuredClone(schema2); future.schemas.tasks = 3;
  assert.throws(() => service.parseStrict(JSON.stringify(future)));
  assert.throws(() => service.parseRecovery(JSON.stringify(future)));
  const extra = structuredClone(schema2); extra.data.logs[0].futureField = null;
  assert.throws(() => service.parseStrict(JSON.stringify(extra)));
  assert.throws(() => service.parseRecovery(JSON.stringify(extra)));
  const badLink = structuredClone(schema2); badLink.data.tasks[0].sourceLogId = '../file';
  assert.throws(() => service.parseStrict(JSON.stringify(badLink)));
});

test('schema2 recovery skips a bad record and preserves valid optional metadata', () => {
  const service = codec(), input = structuredClone(schema2);
  input.data.emotions[0].intensity = false;
  const recovered = service.parseRecovery(JSON.stringify(input));
  assert.equal(recovered.skippedEmotions, 1); assert.equal(recovered.emotions.length, 1);
  assert.equal(recovered.logs[0].isFavorite, true);
  assert.equal(recovered.tasks[0].sourceLogId, '55555555-5555-4555-8555-555555555555');
});

test('actual Apple exporter bytes are accepted without schema relabeling', () => {
  const bytes = fs.readFileSync(path.join(__dirname,
    '../../android/app/src/androidTest/assets/actual-exports/apple-schema2.json'));
  assert.equal(require('node:crypto').createHash('sha256').update(bytes).digest('hex'),
    'cc9718e96f86ce50df4c028a673cfcd2d37ce385e0235c3e1d1764889f6fffa2');
  const imported = codec().parseStrict(bytes.toString('utf8'));
  assert.equal(imported.logs.length, 2); assert.equal(imported.emotions.length, 2); assert.equal(imported.tasks.length, 2);
  assert.equal(imported.emotions[0].intensity, 4);
  assert.equal(imported.logs[0].isFavorite, true);
});

function payloadRdb() {
  const tables = { logs: [], emotions: [], tasks: [], idea_view_state: [] };
  let prior;
  const insert = async (table, row) => {
    tables[table] = tables[table].filter(item => item.id !== row.id);
    tables[table].push({ ...row });
  };
  return { tables,
    beginTransaction() { prior = structuredClone(tables); },
    commit() { prior = undefined; },
    rollBack() { if (prior) for (const key of Object.keys(tables)) tables[key] = prior[key]; },
    async executeSql(sql, args) {
      const table = sql.match(/FROM\s+(\w+)/)?.[1];
      if (table && sql.startsWith('DELETE')) tables[table] = args ? tables[table].filter(row => row.id !== args[0]) : [];
    },
    insert,
    async batchInsert(table, rows) { for (const row of rows) await insert(table, row); },
    async querySql(sql) {
      const rows = tables[sql.match(/FROM\s+(\w+)/)[1]].slice().sort((a, b) => b.sort_key.localeCompare(a.sort_key));
      let index = -1;
      return { goToNextRow: () => ++index < rows.length,
        getString: column => column === 0 ? rows[index].id : rows[index].payload, close() {} };
    }
  };
}

test('stored schema2 payloads survive reload, ordinary log edits and task editor/completion', async () => {
  const load = createLoader();
  const { BackupService } = load('data/BackupService');
  const { FlashStore } = load('data/FlashStore');
  const { CalendarState } = load('state/FeatureStates');
  const { CalendarController } = load('state/CalendarController');
  const input = BackupService.parseStrict(JSON.stringify(schema2)), db = payloadRdb();
  const store = new FlashStore(); store.initialized = true; store.database = db;
  await store.replaceAll(input.logs, input.emotions, input.tasks);
  const logID = input.logs[0].id, taskID = input.tasks[0].id;
  const ideaID = input.logs[1].id;
  await store.markIdeaViewed(ideaID);
  await store.updateLog(logID, 'fictional edited body');
  await store.updateLogMeta(logID, 'log', 'memo');
  await store.updateLogsMetaBatch([{ id: logID, category: 'log', colorTag: 'daily' }]);
  assert.equal(store.logs.find(item => item.id === logID).isFavorite, true);

  const state = new CalendarState(); state.tasks = store.tasks.slice();
  const controller = new CalendarController(state,
    { context: () => ({}), notify() {}, errorMessage: error => error.message }, store);
  controller.openTaskEditor(store.tasks.find(item => item.id === taskID));
  state.taskAllDay = true; state.taskDate = '2026-09-07';
  await controller.saveTaskEditor();
  await controller.toggleTask(store.tasks.find(item => item.id === taskID));
  const reloaded = new FlashStore(); reloaded.initialized = true; reloaded.database = db;
  await reloaded.loadIdeaViewState(); await reloaded.loadBusinessData();
  const task = reloaded.tasks.find(item => item.id === taskID);
  assert.equal(task.sourceLogId, input.tasks[0].sourceLogId); assert.equal(task.isFavorite, true);
  assert.equal(reloaded.logs.find(item => item.id === logID).isFavorite, true);
  const emotion = reloaded.emotions.find(item => item.id === input.emotions[0].id);
  assert.equal(emotion.intensity, 4); assert.equal(emotion.isFavorite, false);
  const output = BackupService.parseStrict(BackupService.exportJSON(reloaded.logs, reloaded.emotions, reloaded.tasks));
  assert.equal(output.tasks.find(item => item.id === taskID).sourceLogId, input.tasks[0].sourceLogId);
  assert.equal(reloaded.viewedIdeaIds.has(ideaID), true);
});
