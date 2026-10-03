const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createLoader } = require('./ets-loader.cjs');
const { validateBytes } = require('../../scripts/backup-contract/validate.cjs');
const minimal = require('../../docs/contracts/fixtures/valid-minimal.json');

function nodeFileIo(overrides = {}) {
  const C = fs.constants;
  return {
    OpenMode: { READ_ONLY: C.O_RDONLY, READ_WRITE: C.O_RDWR, CREATE: C.O_CREAT, TRUNC: C.O_TRUNC },
    accessSync: p => fs.existsSync(p),
    mkdirSync: p => fs.mkdirSync(p, { recursive: true }),
    renameSync: (from, to) => fs.renameSync(from, to),
    unlinkSync: p => fs.unlinkSync(p),
    openSync: (p, mode = C.O_RDONLY) => ({ fd: fs.openSync(p, mode) }),
    writeSync: (fd, data, options) => fs.writeSync(fd, data, null, options?.encoding ?? 'utf-8'),
    closeSync: file => fs.closeSync(file.fd),
    ...overrides
  };
}

function loadBackupFiles(environment, fileIo = nodeFileIo()) {
  const load = createLoader({
    'data/BackupFiles': null,
    '@kit.CoreFileKit': { fileIo, Environment: environment }
  });
  return load('data/BackupFiles');
}

function withCanIUse(value, callback) {
  const previous = globalThis.canIUse;
  if (value === undefined) delete globalThis.canIUse;
  else globalThis.canIUse = value;
  try {
    return callback();
  } finally {
    if (previous === undefined) delete globalThis.canIUse;
    else globalThis.canIUse = previous;
  }
}

test('shared export file name keeps the picker naming scheme', () => {
  const { BackupFiles } = loadBackupFiles({ getUserDownloadDir: () => '' });
  assert.equal(BackupFiles.sharedExportName('flash-aero-backup', '2026-10-03'),
    'flash-aero-backup-2026-10-03.json');
  assert.equal(BackupFiles.sharedExportName('flash-aero-recovery', '2026-01-01'),
    'flash-aero-recovery-2026-01-01.json');
});

test('missing or negative canIUse degrades to unsupported', () => {
  const { BackupFiles, SharedExportStatus } = loadBackupFiles({ getUserDownloadDir: () => '' });
  withCanIUse(undefined, () => {
    assert.equal(BackupFiles.sharedExportStatus(), SharedExportStatus.UNSUPPORTED);
  });
  withCanIUse(() => false, () => {
    assert.equal(BackupFiles.sharedExportStatus(), SharedExportStatus.UNSUPPORTED);
  });
});

test('unsupported capability short-circuits export without touching storage', async () => {
  const { BackupFiles, SharedExportStatus } = loadBackupFiles({ getUserDownloadDir: () => '' });
  await withCanIUse(() => false, async () => {
    const result = await BackupFiles.exportToSharedDir('{"ok":true}');
    assert.deepEqual(result, { status: SharedExportStatus.UNSUPPORTED });
  });
});

test('a rejected pre-authorized directory reports denied', async () => {
  const environment = { getUserDownloadDir: () => { const e = new Error('denied'); e.code = 201; throw e; } };
  const { BackupFiles, SharedExportStatus } = loadBackupFiles(environment);
  await withCanIUse(() => true, async () => {
    assert.equal(BackupFiles.sharedExportStatus(), SharedExportStatus.DENIED);
    const result = await BackupFiles.exportToSharedDir('{"ok":true}');
    assert.deepEqual(result, { status: SharedExportStatus.DENIED });
  });
});

test('shared export writes contract bytes atomically into the visible directory', async () => {
  const base = fs.mkdtempSync(path.join(os.tmpdir(), 'flash-shared-export-'));
  const environment = { getUserDownloadDir: () => base };
  const { BackupFiles, SharedExportStatus } = loadBackupFiles(environment);
  await withCanIUse(() => true, async () => {
    assert.equal(BackupFiles.sharedExportStatus(), SharedExportStatus.READY);
    const load = createLoader();
    const { BackupService } = load('data/BackupService');
    const json = BackupService.exportJSON(
      minimal.data.logs, minimal.data.emotions, minimal.data.tasks);
    const result = await BackupFiles.exportToSharedDir(json);
    assert.equal(result.status, SharedExportStatus.EXPORTED);
    const day = new Date().toISOString().slice(0, 10);
    const expected = path.join(base, 'Flash', `flash-aero-backup-${day}.json`);
    assert.equal(result.path, expected.split(path.sep).join('/'));
    assert.deepEqual(validateBytes(fs.readFileSync(expected)), { valid: true, errors: [] });
    assert.equal(fs.readFileSync(expected, 'utf8'), json);
    assert.deepEqual(fs.readdirSync(path.join(base, 'Flash')).filter(name => name.endsWith('.tmp')), [],
      'atomic rename must not leave temporary files behind');
  });
});

test('a short write removes the temporary file and fails the export', async () => {
  const base = fs.mkdtempSync(path.join(os.tmpdir(), 'flash-shared-export-'));
  const environment = { getUserDownloadDir: () => base };
  const fileIo = nodeFileIo({ writeSync: () => 0 });
  const { BackupFiles } = loadBackupFiles(environment, fileIo);
  await withCanIUse(() => true, async () => {
    await assert.rejects(BackupFiles.exportToSharedDir('{"ok":true}'), /写入不完整/);
    const written = fs.existsSync(path.join(base, 'Flash'))
      ? fs.readdirSync(path.join(base, 'Flash')) : [];
    assert.deepEqual(written, [], 'neither the temp nor the final file may survive');
  });
});

test('controller notifies through the shared export result', async () => {
  const load = createLoader({ 'data/BackupFiles': {
    BackupFiles: {
      exportToSharedDir: async () => ({ status: 'exported', path: '/shared/Flash/backup.json' }),
      sharedExportStatus: () => 'ready'
    },
    SharedExportStatus: { READY: 'ready', EXPORTED: 'exported', UNSUPPORTED: 'unsupported', DENIED: 'denied' }
  } });
  const { BackupState } = load('state/FeatureStates');
  const { BackupController } = load('state/BackupController');
  const messages = [];
  const runtime = { context: () => ({}), notify: m => messages.push(m), errorMessage: e => e.message };
  const store = { ready: true, snapshot: () => ({ logs: [], emotions: [], tasks: [] }) };
  const controller = new BackupController(new BackupState(), runtime, store);
  assert.equal(controller.sharedExportAvailable(), true);
  await controller.exportBackupToSharedDir();
  assert.ok(messages.some(m => m.includes('文件管理')), JSON.stringify(messages));
});

test('controller refuses the shared export while the store is not ready', async () => {
  let exports = 0;
  const load = createLoader({ 'data/BackupFiles': {
    BackupFiles: { exportToSharedDir: async () => { exports++; return { status: 'exported' }; },
      sharedExportStatus: () => 'ready' },
    SharedExportStatus: { READY: 'ready', EXPORTED: 'exported', UNSUPPORTED: 'unsupported', DENIED: 'denied' }
  } });
  const { BackupState } = load('state/FeatureStates');
  const { BackupController } = load('state/BackupController');
  const messages = [];
  const runtime = { context: () => ({}), notify: m => messages.push(m), errorMessage: e => e.message };
  const controller = new BackupController(new BackupState(), runtime,
    { ready: false, snapshot: () => ({ logs: [], emotions: [], tasks: [] }) });
  await controller.exportBackupToSharedDir();
  assert.equal(exports, 0);
  assert.ok(messages.some(m => m.includes('尚未加载完成')));
});
