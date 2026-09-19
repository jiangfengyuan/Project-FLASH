// Security audit 2026-09-19 — HarmonyOS scope host tests.
// Covers lan-handshake-v1.1 details not in review-fixes.test.cjs, quarantine
// hardening, atomic overwrite, the strict scanner, BOM rejection and the
// stable reminder-id mapping. Platform kits are faked per ets-loader rules.
const test = require('node:test');
const assert = require('node:assert/strict');
const nodeCrypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createLoader } = require('./ets-loader.cjs');

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const flush = () => new Promise(resolve => setImmediate(resolve));
async function until(condition, tries = 1000) {
  for (let i = 0; i < tries && !condition(); i++) await flush();
}

// --- shared fakes ------------------------------------------------------------

function deterministicRandom() {
  let state = 0;
  return (length) => {
    const bytes = [];
    for (let index = 0; index < length; index++) {
      state = (state + 1) & 0xff;
      bytes.push(state === 0 ? 1 : state);
    }
    return bytes;
  };
}

function referenceProof(pin, nonceHex) {
  return nodeCrypto.createHmac('sha256', Buffer.from(pin, 'ascii'))
    .update(Buffer.from(`flash-aero-handshake:${nonceHex}`, 'ascii'))
    .digest().toString('hex').slice(0, 32);
}

function referenceMac(pin, payload) {
  return nodeCrypto.createHmac('sha256', Buffer.from(pin, 'ascii'))
    .update(Buffer.from(payload)).digest().toString('hex');
}

function cryptoKit(randomFn = deterministicRandom()) {
  return { cryptoFramework: {
    createRandom: () => ({ generateRandomSync: (length) => ({ data: randomFn(length) }) }),
    createSymKeyGenerator: () => ({
      convertKey: async (blob) => ({ blob: blob.data }),
      convertKeySync: (blob) => ({ blob: blob.data })
    }),
    createMac: () => {
      let hmac;
      return {
        init: async (key) => { hmac = nodeCrypto.createHmac('sha256', Buffer.from(key.blob)); },
        update: async (data) => { hmac.update(Buffer.from(data.data)); },
        doFinal: async () => ({ data: new Uint8Array(hmac.digest()) })
      };
    }
  } };
}

function networkKit() {
  const connections = [];
  return {
    kit: { '@kit.NetworkKit': {
      mdns: {
        addLocalService: async (context, info) => info,
        removeLocalService: async () => {},
        createDiscoveryService: () => ({
          on() {}, off() {}, startSearchingMDNS() {}, stopSearchingMDNS() {} })
      },
      socket: {
        constructTCPSocketServerInstance: () => ({
          on() {}, listen: async () => {}, getLocalAddress: async () => ({ port: 4321 }),
          close: async () => {}
        }),
        constructTCPSocketInstance: () => {
          const client = { handlers: {}, closed: false, sent: [],
            on(event, callback) { this.handlers[event] = callback; },
            emit(text) { this.handlers.message?.({ message: new TextEncoder().encode(text) }); },
            async connect() {},
            async send(payload) { this.sent.push(payload.data); },
            close() { this.closed = true; } };
          connections.push(client);
          return client;
        }
      }
    } },
    client: () => connections[connections.length - 1]
  };
}

function transferModule(randomFn) {
  const net = networkKit();
  const load = createLoader({
    'data/LocalBackupTransfer': null,
    '@kit.CryptoArchitectureKit': cryptoKit(randomFn),
    ...net.kit
  });
  return { ...load('data/LocalBackupTransfer'), client: net.client };
}

function lastChallenge(client) {
  const line = client.sent.filter(item => typeof item === 'string' && item.startsWith('CHALLENGE ')).pop();
  assert.ok(line, 'a CHALLENGE line must have been sent');
  return line.slice('CHALLENGE '.length, -1);
}

const DEVICE = { id: 'd', name: 'n', host: '127.0.0.1', port: 4321 };
const FAST_BACKOFF = [1, 2, 3, 4];

function startReceiver(pinSource, idleMillis = 60000, transferMillis = 60000) {
  const { LocalBackupReceiver, client } = transferModule();
  const receiver = LocalBackupReceiver.start(DEVICE, pinSource, idleMillis, transferMillis, FAST_BACKOFF);
  return { receiver, client: client() };
}

// --- handshake v1.1 details ---------------------------------------------------

test('sender PIN is an unbiased 6-digit decimal string', () => {
  const { LocalBackupSender } = transferModule();
  const sender = new LocalBackupSender({}, '{}', () => {});
  assert.match(sender.pin, /^\d{6}$/, 'PIN must be 6 decimal digits');
  // The rejection-sampling draw that produced it must be below the bias limit.
  const seen = new Set();
  for (let index = 0; index < 20; index++) {
    const another = new LocalBackupSender({}, '{}', () => {});
    seen.add(another.pin);
    assert.match(another.pin, /^\d{6}$/);
  }
  assert.ok(seen.size > 1, 'PINs must vary across senders');
});

test('receiver strictly parses the OK header and rejects OK 123abc', async () => {
  const { receiver, client } = startReceiver(() => '123456');
  const rejection = assert.rejects(receiver.result, /无效响应/);
  await flush();
  const nonce = lastChallenge(client);
  const payload = '{}';
  client.emit(`FLASH-AERO/1 ${referenceProof('123456', nonce)}\nOK 123abc ${referenceMac('123456', payload)}\n${payload}`);
  await rejection;
  assert.ok(client.closed);
});

test('receiver rejects an over-size OK payload before buffering it', async () => {
  const { receiver, client } = startReceiver(() => '123456');
  const rejection = assert.rejects(receiver.result, /大小异常/);
  await flush();
  const nonce = lastChallenge(client);
  client.emit(`FLASH-AERO/1 ${referenceProof('123456', nonce)}\nOK 52428801 ${'ab'.repeat(32)}\n`);
  await rejection;
  assert.ok(client.closed);
});

test('receiver discards a tampered payload whole when the MAC mismatches', async () => {
  const { receiver, client } = startReceiver(() => '123456');
  const rejection = assert.rejects(receiver.result, /整体丢弃/);
  await flush();
  const nonce = lastChallenge(client);
  const payload = '{"logs":[],"secret":1}';
  const tampered = '{"logs":[],"secret":2}';
  client.emit(`FLASH-AERO/1 ${referenceProof('123456', nonce)}\nOK ${payload.length} ${referenceMac('123456', payload)}\n${tampered}`);
  await rejection;
  assert.ok(client.closed);
});

test('receiver enforces the 120s-class transfer hard cap against slow drips', async () => {
  const { receiver, client } = startReceiver(() => '123456', 60000, 90);
  const rejection = assert.rejects(receiver.result, /传输超时/);
  await flush();
  const nonce = lastChallenge(client);
  client.emit(`FLASH-AERO/1 ${referenceProof('123456', nonce)}\nOK 4 ${'00'.repeat(32)}\n`);
  // Drip one byte every 30 ms: never idle for 60 s, but past the 90 ms cap.
  for (let index = 0; index < 10; index++) {
    await sleep(30);
    client.emit('x');
  }
  await rejection;
  assert.ok(client.closed);
});

test('receiver refuses a 5-digit PIN at construction', () => {
  const { LocalBackupReceiver } = transferModule();
  assert.throws(() => LocalBackupReceiver.start(DEVICE, () => '12345'), /六位数字/);
  assert.throws(() => LocalBackupReceiver.start(DEVICE, () => '1234567'), /六位数字/);
});

test('BOM-prefixed payload decodes to U+FEFF and the strict importer rejects it', async () => {
  const { receiver, client } = startReceiver(() => '123456');
  await flush();
  const nonce = lastChallenge(client);
  const body = '\uFEFF{"version":"flash-backup-v2"}';
  const bytes = new TextEncoder().encode(body);
  client.emit(`FLASH-AERO/1 ${referenceProof('123456', nonce)}\nOK ${bytes.length} ${referenceMac('123456', bytes)}\n${body}`);
  const json = await receiver.result;
  assert.ok(json.startsWith('\uFEFF'), 'BOM must survive decoding for the strict importer');
  const { BackupService } = createLoader()('data/BackupService');
  assert.throws(() => BackupService.parseStrict(json), /不允许 BOM/);
});

// --- quarantine hardening ------------------------------------------------------

function storeWithFiles() {
  const filesDir = fs.mkdtempSync(path.join(os.tmpdir(), 'flash-quarantine-'));
  const load = createLoader();
  const { FlashStore } = load('data/FlashStore');
  const store = new FlashStore();
  store.filesDir = filesDir;
  return { store, filesDir };
}

function quarantineDir(filesDir) {
  return path.join(filesDir, 'quarantine');
}

test('quarantine write refuses a file over the single-file cap', () => {
  const { store, filesDir } = storeWithFiles();
  const under = 'x'.repeat(1024 * 1024);
  assert.equal(store.writeQuarantineFile('legacy-logs.json', under), true, 'at the cap is allowed');
  assert.equal(store.readQuarantineFile('legacy-logs.json'), under);
  const over = 'x'.repeat(1024 * 1024 + 1);
  assert.equal(store.writeQuarantineFile('legacy-emotions.json', over), false, 'over the cap is refused');
  assert.equal(fs.existsSync(path.join(quarantineDir(filesDir), 'legacy-emotions.json')), false);
});

test('quarantine read refuses a pre-existing oversized file', () => {
  const { store, filesDir } = storeWithFiles();
  fs.mkdirSync(quarantineDir(filesDir));
  fs.writeFileSync(path.join(quarantineDir(filesDir), 'rdb-payloads.json'), 'x'.repeat(1024 * 1024 + 8));
  assert.equal(store.readQuarantineFile('rdb-payloads.json'), '', 'oversized leftovers are not loaded');
});

test('quarantine TTL cleanup removes files older than 30 days and keeps fresh ones', () => {
  const { store, filesDir } = storeWithFiles();
  fs.mkdirSync(quarantineDir(filesDir));
  const oldFile = path.join(quarantineDir(filesDir), 'legacy-logs.json');
  const freshFile = path.join(quarantineDir(filesDir), 'legacy-tasks.json');
  fs.writeFileSync(oldFile, 'old');
  fs.writeFileSync(freshFile, 'fresh');
  const old = new Date(Date.now() - 31 * 24 * 60 * 60 * 1000);
  fs.utimesSync(oldFile, old, old);
  store.cleanupQuarantine();
  assert.equal(fs.existsSync(oldFile), false, 'expired quarantine file is removed');
  assert.equal(fs.existsSync(freshFile), true, 'fresh quarantine file survives');
});

test('clearQuarantine removes every copy and resets recovery state', () => {
  const { store, filesDir } = storeWithFiles();
  assert.equal(store.writeQuarantineFile('legacy-logs.json', 'data'), true);
  assert.equal(store.writeQuarantineFile('rdb-payloads.json', '[]'), true);
  store.hasRecoveryData = true;
  store.recoveryWarning = 'warning';
  store.clearQuarantine();
  assert.equal(fs.readdirSync(quarantineDir(filesDir)).length, 0);
  assert.equal(store.hasRecoveryData, false);
  assert.equal(store.recoveryWarning, '');
});

test('successful recovery export clears the quarantine and hides the entry', async () => {
  const load = createLoader({
    'data/BackupFiles': { BackupFiles: { exportJSON: async () => {}, importJSON: async () => { throw new Error('unused'); } } }
  });
  const { BackupState } = load('state/FeatureStates');
  const { BackupController } = load('state/BackupController');
  const state = new BackupState();
  const messages = [];
  const store = {
    recoveryArchive: async () => '{"version":"flash-recovery-v1"}',
    clearQuarantine: () => { store.cleared = true; },
    snapshot: () => ({ logs: [], emotions: [], tasks: [] })
  };
  const controller = new BackupController(state, { context: () => ({}), notify: m => messages.push(m), errorMessage: e => e.message }, store);
  state.recoveryAvailable = true;
  await controller.exportRecoveryData();
  assert.equal(store.cleared, true, 'quarantine cleared only after a successful export');
  assert.equal(state.recoveryAvailable, false);
  assert.ok(messages.some(m => m.includes('导出')));
});

test('clearRecoveryData clears the quarantine without exporting', async () => {
  const load = createLoader();
  const { BackupState } = load('state/FeatureStates');
  const { BackupController } = load('state/BackupController');
  const state = new BackupState();
  const messages = [];
  const store = { clearQuarantine: () => { store.cleared = true; }, snapshot: () => ({ logs: [], emotions: [], tasks: [] }) };
  const controller = new BackupController(state, { context: () => ({}), notify: m => messages.push(m), errorMessage: e => e.message }, store);
  state.recoveryAvailable = true;
  await controller.clearRecoveryData();
  assert.equal(store.cleared, true);
  assert.equal(state.recoveryAvailable, false);
  assert.ok(messages.some(m => m.includes('隔离区已清除')));
});

// --- atomic overwrite ----------------------------------------------------------

function realStore() {
  const load = createLoader();
  const { FlashStore } = load('data/FlashStore');
  const store = new FlashStore();
  store.initialized = true;
  store.database = {
    beginTransaction() {}, commit() {}, rollBack() {},
    executeSql: async () => {}, batchInsert: async () => {}, insert: async () => {}
  };
  return store;
}

test('replaceAllIfCurrent applies only when the store still matches the preview snapshot', async () => {
  const store = realStore();
  const logItem = id => ({ id, content: '记录', colorTag: 'daily', category: 'log', importance: 0,
    recordDate: '2026-09-05', createdAt: '2026-09-05T00:00:00.000Z' });
  await store.replaceAll([logItem('11111111-1111-1111-1111-111111111111')], [], []);
  const preview = store.snapshot();
  const incoming = [logItem('22222222-2222-2222-2222-222222222222')];
  assert.equal(await store.replaceAllIfCurrent(incoming, [], [], preview), true, 'unchanged store accepts the overwrite');
  assert.equal(store.snapshot().logs.length, 1);
  assert.equal(store.snapshot().logs[0].id, '22222222-2222-2222-2222-222222222222');

  const stalePreview = store.snapshot();
  await store.addLog('新记录', 'log');
  assert.equal(await store.replaceAllIfCurrent([logItem('33333333-3333-3333-3333-333333333333')], [], [], stalePreview), false,
    'a write between preview and confirmation aborts the overwrite');
  assert.equal(store.snapshot().logs.length, 2, 'no records were deleted by the aborted overwrite');
  assert.equal(store.snapshot().logs.some(item => item.content === '新记录'), true);
});

// --- strict scanner -------------------------------------------------------------

test('strict scanner validates large value strings and still detects escaped duplicate keys', () => {
  const { BackupService } = createLoader()('data/BackupService');
  // ~20k records make a multi-MB document of value strings; validation must
  // stay linear (the old char-by-char accumulation was quadratic).
  const logs = [];
  for (let index = 0; index < 20000; index++) {
    logs.push({
      id: `11111111-1111-4111-8111-${String(index).padStart(12, '0')}`,
      content: `记录内容 ${index}：一段足够长的文本用于放大扫描成本。`,
      colorTag: 'daily', category: 'log', importance: 0,
      createdAt: '2026-09-05T00:00:00.000Z', recordDate: '2026-09-05'
    });
  }
  const document = JSON.stringify({
    version: 'flash-backup-v2', exportedAt: '2026-09-05T00:00:00.000Z', appVersion: '0.1.0',
    notes: '', schemas: { logs: 1, emotions: 1, tasks: 1 }, data: { logs, emotions: [], tasks: [] }
  });
  assert.ok(document.length > 1024 * 1024, 'fixture must be multi-MB');
  const start = Date.now();
  const parsed = BackupService.parseStrict(document);
  assert.equal(parsed.logs.length, 20000);
  assert.ok(Date.now() - start < 2000, 'multi-MB documents must scan in linear time');

  const escapedDuplicate = '{"a":1,"\\u0061":2}';
  assert.throws(() => BackupService.parseStrict(escapedDuplicate), /重复键/);
});

// --- BOM handling in the file import path ---------------------------------------

test('importJSON keeps a BOM for parseStrict to reject', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'flash-import-'));
  const target = path.join(dir, 'backup.json');
  const body = JSON.stringify({
    version: 'flash-backup-v2', exportedAt: '2026-09-05T00:00:00.000Z', appVersion: '0.1.0',
    notes: '', schemas: { logs: 1, emotions: 1, tasks: 1 }, data: { logs: [], emotions: [], tasks: [] }
  });
  fs.writeFileSync(target, '﻿' + body, 'utf8');
  const C = fs.constants;
  const fileIo = {
    OpenMode: { READ_ONLY: C.O_RDONLY },
    openSync: (p, mode) => ({ fd: fs.openSync(p, mode) }),
    statSync: fd => ({ size: fs.fstatSync(fd).size, mtime: fs.fstatSync(fd).mtime }),
    readSync: (fd, buffer, options) => fs.readSync(fd, Buffer.from(buffer), 0, options.length, 0),
    closeSync: file => fs.closeSync(typeof file === 'object' ? file.fd : file)
  };
  const picker = { picker: {
    DocumentSelectOptions: class {},
    DocumentViewPicker: class { async select() { return [target]; } }
  } };
  const load = createLoader({ 'data/BackupFiles': null, '@kit.CoreFileKit': { fileIo, ...picker } });
  const { BackupFiles } = load('data/BackupFiles');
  const json = await BackupFiles.importJSON({});
  assert.ok(json.startsWith('﻿'), 'BOM must not be silently stripped');
  const { BackupService } = createLoader()('data/BackupService');
  assert.throws(() => BackupService.parseStrict(json), /不允许 BOM/);
});

// --- reminder notification ids ---------------------------------------------------

// These two task ids collided under the old FNV-1a notificationId hash.
const COLLIDING_A = '5b6143b0-f49e-382e-b65a-4aca194db820';
const COLLIDING_B = '6c47c0b5-e05e-5e0c-38fd-3fa5da0e5816';

function oldHashNotificationId(id) {
  let hash = 2166136261;
  for (let index = 0; index < id.length; index++) {
    hash ^= id.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return Math.abs(hash % 2147483646) + 1;
}

function reminderKits() {
  const published = [];
  let reminderCounter = 0;
  const memory = new Map();
  const prefs = {
    getPreferences: async (context, name) => ({
      getAll: async () => Object.fromEntries(memory),
      put: async (key, value) => { memory.set(key, value); },
      delete: async (key) => { memory.delete(key); },
      flush: async () => {}
    })
  };
  const tasks = {
    reminderAgentManager: {
      ReminderType: { REMINDER_TYPE_CALENDAR: 0 },
      getAllValidReminders: async () => [],
      publishReminder: async (request) => { published.push(request); return ++reminderCounter; },
      cancelReminder: async () => {}
    }
  };
  const notifications = { notificationManager: { requestEnableNotification: async () => {} } };
  return { published, memory, kits: {
    '@kit.ArkData': { preferences: prefs, relationalStore: { ConflictResolution: { ON_CONFLICT_REPLACE: 1 } } },
    '@kit.BackgroundTasksKit': tasks,
    '@kit.NotificationKit': notifications
  } };
}

function taskItem(id, title) {
  return { id, title, colorTag: 'daily', importance: 1,
    due: { kind: 'dateTime', at: '2026-09-20T01:00:00.000Z', timeZone: 'UTC' },
    createdAt: '2026-09-05T00:00:00.000Z', updatedAt: '2026-09-05T00:00:00.000Z',
    reminderAt: '2027-01-01T00:00:00.000Z' };
}

test('reminder notification ids are collision-free and stable across rebuilds', async () => {
  assert.equal(oldHashNotificationId(COLLIDING_A), oldHashNotificationId(COLLIDING_B),
    'fixture must actually collide under the old hash');

  const { published, memory, kits } = reminderKits();
  const load = createLoader({ 'data/TaskReminderScheduler': null, ...kits });
  const { TaskReminderScheduler } = load('data/TaskReminderScheduler');
  const tasks = [taskItem(COLLIDING_A, '任务 A'), taskItem(COLLIDING_B, '任务 B')];

  await TaskReminderScheduler.rebuild({}, tasks, false);
  assert.equal(published.length, 2);
  const firstIds = published.map(request => request.notificationId);
  assert.notEqual(firstIds[0], firstIds[1], 'colliding task ids must get distinct notification ids');
  assert.ok(firstIds.every(id => Number.isInteger(id) && id >= 1 && id <= 2147483646));

  published.length = 0;
  await TaskReminderScheduler.rebuild({}, tasks, false);
  assert.deepEqual(published.map(request => request.notificationId), firstIds,
    'ids are reused from the persisted mapping, not reallocated');

  published.length = 0;
  await TaskReminderScheduler.rebuild({}, [tasks[0]], false);
  assert.equal(published.length, 1);
  assert.equal(published[0].notificationId, firstIds[0]);
  assert.equal(memory.has(COLLIDING_B), false, 'dropped tasks release their mapping entry');
});
