const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createLoader } = require('./ets-loader.cjs');
const tsPath = process.env.FLASH_TYPESCRIPT_PATH || '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript';
const ts = require(tsPath);
const source = path.join(__dirname,'../entry/src/main/ets/data/FlashStore.ets');
function makeStore(fileIo = {}) {
  const load = createLoader({ '@kit.CoreFileKit': { fileIo } });
  const module = { exports: {} };
  const compiled = ts.transpileModule(fs.readFileSync(source, 'utf8'), {
    compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS }
  });
  new Function('require', 'module', 'exports', compiled.outputText)(
    name => load(name.startsWith('../models/') ? 'models/' + name.slice('../models/'.length) :
      name.startsWith('./') ? 'data/' + name.slice(2) : name), module, module.exports);
  return new module.exports.FlashStore();
}
function settings(values = {}) {
  const data = new Map(Object.entries(values));
  return { data, get: async (key, fallback) => data.has(key) ? data.get(key) : fallback,
    put: async (key, value) => data.set(key, value), delete: async key => data.delete(key),
    flush: async () => {} };
}

test('failed quarantine preserves rejected legacy data across successful migration and recovery export', async () => {
  const store = makeStore();
  const raw = '[{"id":"invalid-record-but-original-data","content":"keep this"}]';
  store.settings = settings({ 'logs-json': raw });
  store.writeQuarantineFile = async () => false;
  store.readQuarantineFile = async () => '';
  store.replaceDatabase = async () => {};
  await store.migratePreferencesData();
  assert.equal(store.settings.data.get('rdb-migrated-v1'), true, 'must not rerun destructive migration over later RDB edits');
  assert.equal(store.settings.data.get('logs-json'), raw, 'failed quarantine must retain original bytes');
  // Simulate process restart: no in-memory warning survives.
  store.hasRecoveryData = false; store.recoveryWarning = '';
  await store.loadRecoveryState();
  assert.equal(store.hasRecoveryData, true);
  const archive = JSON.parse(await store.recoveryArchive());
  assert.equal(archive.raw.logs, raw, 'recovery export must include retained original');
  await store.clearQuarantine();
  assert.equal(store.settings.data.has('logs-json'), false, 'explicit successful export/discard cleanup clears retained raw');
});

test('a rejected legacy section above quarantine cap remains recoverable', async () => {
  const store = makeStore();
  const raw = JSON.stringify([{ id: 'invalid', content: 'x'.repeat(1024 * 1024) }]);
  store.settings = settings({ 'logs-json': raw });
  store.filesDir = '/unused-size-cap-check';
  store.replaceDatabase = async () => {};
  store.readQuarantineFile = async () => '';
  const original = console.error; console.error = () => {};
  try {
    await store.migratePreferencesData();
    assert.equal(store.settings.data.has('logs-json'), true);
    assert.equal(JSON.parse(await store.recoveryArchive()).raw.logs.length, raw.length);
  } finally { console.error = original; }
});

test('short quarantine write does not replace an existing complete recovery file', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'flash-quarantine-'));
  fs.mkdirSync(path.join(dir, 'quarantine'));
  const target = path.join(dir, 'quarantine', 'legacy-logs.json');
  fs.writeFileSync(target, 'prior complete archive');
  const fileIo = {
    OpenMode: { READ_WRITE: fs.constants.O_RDWR, CREATE: fs.constants.O_CREAT, TRUNC: fs.constants.O_TRUNC },
    access: async p => fs.existsSync(p), mkdir: async p => fs.mkdirSync(p, { recursive: true }),
    open: async (p, flags) => ({ fd: fs.openSync(p, flags) }),
    write: async (fd, text) => fs.writeSync(fd, Buffer.from(text).subarray(0, 2)),
    close: async file => fs.closeSync(file.fd), rename: async (a, b) => fs.renameSync(a, b),
    unlink: async p => fs.unlinkSync(p)
  };
  try {
    const store = makeStore(fileIo); store.filesDir = dir;
    assert.equal(await store.writeQuarantineFile('legacy-logs.json', 'new完整档案'), false);
    assert.equal(fs.readFileSync(target, 'utf8'), 'prior complete archive');
    assert.equal(fs.existsSync(target + '.tmp'), false);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('complete quarantine write publishes full UTF-8 content', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'flash-quarantine-'));
  try {
    const io = {
      OpenMode: { READ_WRITE: fs.constants.O_RDWR, CREATE: fs.constants.O_CREAT, TRUNC: fs.constants.O_TRUNC },
      access: async p => fs.existsSync(p), mkdir: async p => fs.mkdirSync(p, { recursive: true }),
      open: async (p, flags) => ({ fd: fs.openSync(p, flags) }),
      write: async (fd, text) => fs.writeSync(fd, text), close: async f => fs.closeSync(f.fd),
      rename: async (a, b) => fs.renameSync(a, b), unlink: async p => fs.unlinkSync(p)
    };
    const writable = makeStore(io); writable.filesDir = dir;
    assert.equal(await writable.writeQuarantineFile('legacy-logs.json', '完整 archive'), true);
    assert.equal(fs.readFileSync(path.join(dir, 'quarantine', 'legacy-logs.json'), 'utf8'), '完整 archive');
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
