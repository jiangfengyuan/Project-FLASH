// D3：情绪 status 保存/回显、备份往返保留 status、趋势聚合。
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createLoader } = require('./ets-loader.cjs');

function runtime() {
  const messages = [];
  return { messages, context: () => ({}), notify: m => messages.push(m), errorMessage: e => e.message };
}

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

async function freshStore() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'flash-emotion-'));
  const prefs = memoryPreferences({ 'rdb-migrated-v1': true });
  const db = memoryRdb();
  const load = createLoader({ '@kit.ArkData': {
    preferences: { getPreferences: async () => prefs },
    relationalStore: { SecurityLevel: { S1: 1 }, ConflictResolution: { ON_CONFLICT_REPLACE: 1 },
      getRdbStore: async () => db } } });
  const { FlashStore } = load('data/FlashStore');
  const store = new FlashStore();
  await store.initialize({ filesDir: dir });
  return { store, db, load };
}

test('addEmotion persists status; blank drops it; long status is capped at 50', async () => {
  const { store, db } = await freshStore();
  await store.addEmotion(2, undefined, 'note', '  专注  ');
  await store.addEmotion(1, undefined, '', '   ');
  await store.addEmotion(0, undefined, '', 'x'.repeat(60));
  assert.equal(store.emotions.length, 3);
  const byLevel = new Map(store.emotions.map(item => [item.level, item]));
  assert.equal(byLevel.get(2).status, '专注');
  assert.equal(byLevel.get(1).status, undefined, 'blank status stays undefined');
  assert.equal(byLevel.get(0).status.length, 50);
  const stored = db.tables.emotions.map(row => JSON.parse(row.payload));
  assert.equal(stored.find(item => item.level === 2).status, '专注');
});

test('status survives the flash-backup-v2 export/strict-import round trip', async () => {
  const { store, load } = await freshStore();
  await store.addEmotion(-2, 'sad', '糟透了', '疲惫');
  const { BackupService } = load('data/BackupService');
  const snapshot = store.snapshot();
  const json = BackupService.exportJSON(snapshot.logs, snapshot.emotions, snapshot.tasks);
  const imported = BackupService.parseStrict(json);
  assert.equal(imported.emotions.length, 1);
  assert.equal(imported.emotions[0].status, '疲惫');
  assert.equal(imported.emotions[0].subEmotion, 'sad');
  assert.equal(imported.skippedEmotions, 0);
});

test('saveEmotion wires status through, clears the drafts and raises the saved flash', async () => {
  const load = createLoader();
  const { EmotionState } = load('state/FeatureStates');
  const { EmotionController } = load('state/EmotionController');
  const state = new EmotionState(), r = runtime();
  const saved = [];
  const controller = new EmotionController(state, r, { addEmotion: async (...args) => saved.push(args) });
  state.emotionLevel = -2;
  state.selectedSubEmotion = 'uncomfortable';
  state.emotionNote = '记录一下';
  state.emotionStatus = '疲惫';
  await controller.saveEmotion();
  assert.deepEqual(saved, [[-2, 'uncomfortable', '记录一下', '疲惫']]);
  assert.equal(state.emotionNote, '');
  assert.equal(state.emotionStatus, '');
  assert.equal(state.savedFlash, 1);
  assert.equal(state.savedLevel, -2);
  assert.ok(r.messages.includes('情绪已记录'));

  // 正面情绪不带子情绪，status 照常保存。
  state.emotionLevel = 3;
  state.emotionStatus = '放松';
  await controller.saveEmotion();
  assert.deepEqual(saved[1], [3, undefined, '', '放松']);
  assert.equal(state.savedFlash, 2);
  assert.equal(state.savedLevel, 3);
});

test('seven-day trend aggregates per-day averages and memoizes per data version', () => {
  const load = createLoader();
  const { EmotionState } = load('state/FeatureStates');
  const { EmotionController } = load('state/EmotionController');
  const { dayOffset, dayString } = load('data/DateUtils');
  const state = new EmotionState();
  const controller = new EmotionController(state, runtime(), { addEmotion: async () => {} });

  const days = controller.lastSevenDays();
  assert.equal(days.length, 7);
  assert.equal(days[6], dayString());
  assert.equal(days[0], dayOffset(-6));

  const today = dayString();
  state.emotions = [
    { id: 'e1', level: 3, recordDate: today, createdAt: `${today}T01:00:00.000Z` },
    { id: 'e2', level: 1, recordDate: today, createdAt: `${today}T02:00:00.000Z` },
    { id: 'e3', level: -3, recordDate: dayOffset(-6), createdAt: `${dayOffset(-6)}T01:00:00.000Z` }
  ];
  state.emotionsVersion = 1;
  assert.equal(controller.dayAverage(today), 2);
  assert.equal(controller.dayEmotionLabel(today), '2.0');
  assert.equal(controller.dayEmotionLabel(dayOffset(-3)), '—');
  assert.equal(controller.dayBar(today), Math.round(5 / 6 * 100));
  assert.equal(controller.dayBar(dayOffset(-6)), 8, 'minimum visible bar');
  assert.equal(controller.dayBar(dayOffset(-3)), 0, 'no record means no bar');

  // memo：版本不变不重建，版本递增后按新数据聚合。
  state.emotions = state.emotions.filter(item => item.id !== 'e2');
  assert.equal(controller.dayAverage(today), 2, 'same version serves the cached aggregate');
  state.emotionsVersion = 2;
  assert.equal(controller.dayAverage(today), 3);
});
