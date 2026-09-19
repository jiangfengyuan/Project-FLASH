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
function runtime() {
  const messages = [];
  return { messages, context: () => ({}), notify: m => messages.push(m), errorMessage: e => e.message };
}
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const flush = () => new Promise(resolve => setImmediate(resolve));
async function until(condition, tries = 1000) {
  for (let i = 0; i < tries && !condition(); i++) await flush();
}

// --- 1. export validates writeSync byte count --------------------------------

function pickerOverride(target) {
  return { picker: {
    DocumentSaveOptions: class {},
    DocumentSelectOptions: class {},
    DocumentViewPicker: class {
      constructor() {}
      async save() { return [target]; }
    }
  } };
}

test('export reports a short write and removes the truncated file', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'flash-export-'));
  const target = path.join(dir, 'backup.json');
  const fileIo = {
    OpenMode: { READ_WRITE: fs.constants.O_RDWR, TRUNC: fs.constants.O_TRUNC },
    openSync: (p, mode) => ({ fd: fs.openSync(p, mode | fs.constants.O_CREAT) }),
    writeSync: () => 0, // disk full: nothing written, no error raised
    unlinkSync: p => fs.unlinkSync(p),
    closeSync: file => fs.closeSync(file.fd)
  };
  const load = createLoader({
    'data/BackupFiles': null,
    '@kit.CoreFileKit': { fileIo, ...pickerOverride(target) }
  });
  const { BackupFiles } = load('data/BackupFiles');
  await assert.rejects(BackupFiles.exportJSON({}, '{"ok":true}'), /写入不完整/);
  assert.equal(fs.existsSync(target), false, 'truncated export must not survive');
});

test('export succeeds when writeSync reports the full byte count', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'flash-export-'));
  const target = path.join(dir, 'backup.json');
  const fileIo = {
    OpenMode: { READ_WRITE: fs.constants.O_RDWR, TRUNC: fs.constants.O_TRUNC },
    openSync: (p, mode) => ({ fd: fs.openSync(p, mode | fs.constants.O_CREAT) }),
    writeSync: (fd, data, options) => fs.writeSync(fd, data, null, options?.encoding ?? 'utf-8'),
    unlinkSync: p => fs.unlinkSync(p),
    closeSync: file => fs.closeSync(file.fd)
  };
  const load = createLoader({
    'data/BackupFiles': null,
    '@kit.CoreFileKit': { fileIo, ...pickerOverride(target) }
  });
  const { BackupFiles } = load('data/BackupFiles');
  const json = '{"ok":"中文"}';
  await BackupFiles.exportJSON({}, json);
  assert.equal(fs.readFileSync(target, 'utf8'), json);
});

// --- 2/3. backup controller: stale overwrite preview and readiness ----------

function backupStore(data) {
  const sameData = (expected, current) =>
    ['logs', 'emotions', 'tasks'].every(section =>
      expected[section].length === current[section].length &&
      expected[section].every((item, index) => item === current[section][index]));
  return {
    applied: undefined,
    merged: undefined,
    data,
    ready: true,
    snapshot() {
      return { logs: this.data.logs.slice(), emotions: this.data.emotions.slice(),
        tasks: this.data.tasks.slice() };
    },
    async replaceAll(logs, emotions, tasks) {
      this.applied = { logs, emotions, tasks };
      this.data = { logs: logs.slice(), emotions: emotions.slice(), tasks: tasks.slice() };
    },
    async replaceAllIfCurrent(logs, emotions, tasks, expected) {
      if (!sameData(expected, this.snapshot())) return false;
      this.applied = { logs, emotions, tasks };
      this.data = { logs: logs.slice(), emotions: emotions.slice(), tasks: tasks.slice() };
      return true;
    },
    async mergeAll(logs, emotions, tasks) { this.merged = { logs, emotions, tasks }; }
  };
}

function backupController(load, store) {
  const { BackupState, ImportPhase } = load('state/FeatureStates');
  const { BackupController } = load('state/BackupController');
  const state = new BackupState();
  const r = runtime();
  return { controller: new BackupController(state, r, store), state, r, ImportPhase };
}

function emptyImport(load) {
  const { BackupService } = load('data/BackupService');
  return BackupService.parseStrict(BackupService.exportJSON([], [], []));
}

test('overwrite with local changes after preview re-computes the diff and asks again', async () => {
  const load = createLoader();
  const store = backupStore({ logs: [log()], emotions: [], tasks: [] });
  const { controller, state, r, ImportPhase } = backupController(load, store);
  controller.stageImport(emptyImport(load));
  assert.equal(state.importPhase, ImportPhase.PREVIEW);
  assert.ok(state.importSummary.includes('本机独有 1'));

  store.data = { logs: [log('22222222-2222-2222-2222-222222222222', '新记录'), ...store.data.logs],
    emotions: [], tasks: [] };
  await controller.applyBackup(false);
  assert.equal(store.applied, undefined, 'stale overwrite must not run');
  assert.equal(state.importPhase, ImportPhase.PREVIEW);
  assert.ok(state.importSummary.includes('本机独有 2'), 'diff refreshed against current data');
  assert.ok(r.messages.some(m => m.includes('重新计算')));

  await controller.applyBackup(false);
  assert.ok(store.applied, 'second confirmation applies the overwrite');
  assert.equal(state.importPhase, ImportPhase.IDLE);

  // Merge never deletes local records, so it does not require a fresh preview.
  controller.stageImport(emptyImport(load));
  store.data = { logs: [log('33333333-3333-3333-3333-333333333333', '又一条')], emotions: [], tasks: [] };
  await controller.applyBackup(true);
  assert.ok(store.merged, 'merge is not blocked by a stale preview');
});

test('export and LAN send are refused while the store is not initialized', async () => {
  let exports = 0;
  const load = createLoader({ 'data/BackupFiles': { BackupFiles: {
    exportJSON: async () => { exports++; },
    importJSON: async () => { throw new Error('unused'); }
  } } });
  const store = { ready: false, snapshot: () => ({ logs: [], emotions: [], tasks: [] }) };
  const { controller, state, r } = backupController(load, store);
  const { TransferPhase } = load('state/FeatureStates');
  await controller.exportBackup();
  assert.equal(exports, 0);
  assert.ok(r.messages.some(m => m.includes('尚未加载完成')));
  await controller.startLanSend();
  assert.equal(state.lanMode, TransferPhase.IDLE);
  assert.ok(r.messages.some(m => m.includes('无法发送备份')));
});

// --- 4. editing a log preserves cross-device metadata ------------------------

test('updateLog keeps the original importance while updating the content', async () => {
  const load = createLoader();
  const { FlashStore } = load('data/FlashStore');
  const store = new FlashStore();
  store.initialized = true;
  store.database = { insert: async () => {} };
  store.logs = [{ ...log(), importance: 3 }];
  await store.updateLog(store.logs[0].id, '改写后的内容 !!!!');
  assert.equal(store.logs[0].content, '改写后的内容 !!!!');
  assert.equal(store.logs[0].importance, 3, '!! syntax must not re-parse on edit');
});

// --- 5. non-preset reminder offsets survive the editor -----------------------

test('non-preset reminder offset is echoed and preserved on save', async () => {
  const load = createLoader();
  const { CalendarState } = load('state/FeatureStates');
  const { CalendarController } = load('state/CalendarController');
  const state = new CalendarState();
  const r = runtime();
  let saved;
  const controller = new CalendarController(state, r, { saveTask: async t => { saved = t; } });
  const task = { id: '33333333-3333-3333-3333-333333333333', title: '任务', colorTag: 'memo',
    importance: 0, due: { kind: 'dateTime', at: '2026-09-05T09:00:00.000Z', timeZone: 'UTC' },
    reminderAt: '2026-09-05T08:30:00.000Z',
    createdAt: '2026-09-01T00:00:00.000Z', updatedAt: '2026-09-01T00:00:00.000Z' };
  state.tasks = [task];
  controller.openTaskEditor(task);
  assert.equal(state.taskReminderMinutes, 30, 'custom offset must not fold into a preset');
  await controller.saveTaskEditor();
  assert.equal(saved.reminderAt, '2026-09-05T08:30:00.000Z', 'unchanged reminder setting is preserved');

  const late = { ...task, reminderAt: '2026-09-05T10:00:00.000Z' };
  assert.equal(controller.reminderOffset(late), 0, 'reminders after the anchor clamp to at-due-time');
  assert.equal(controller.reminderOffset({ ...task, reminderAt: undefined }), -1);
});

// --- 8. exported contract fields ---------------------------------------------

test('appVersion comes from bundle info and notes stay empty', async () => {
  const base = createLoader();
  const { StoreChanges } = base('data/StoreChanges');
  const store = { logs: [], emotions: [], tasks: [], changes: new StoreChanges(),
    themeMode: 'light', welcomed: true, hasRecoveryData: false, recoveryWarning: '',
    initialize: async () => {} };
  const load = createLoader({
    'data/FlashStore': { FlashStore: { instance: store } },
    '@kit.AbilityKit': { bundleManager: {
      BundleFlag: { GET_BUNDLE_INFO_WITH_APPLICATION: 1 },
      getBundleInfoForSelf: async () => ({ versionName: '9.9.9-test' }) } }
  });
  const { AppController } = load('state/AppController');
  const { BackupService } = load('data/BackupService');
  const app = new AppController();
  try {
    await app.prepare({});
    assert.equal(BackupService.appVersion, '9.9.9-test');
    const document = JSON.parse(BackupService.exportJSON([], [], []));
    assert.equal(document.appVersion, '9.9.9-test');
    assert.equal(document.notes, '');
  } finally {
    app.dispose();
  }
});

// --- 7. LAN transfer hardening (lan-handshake-v1.1) -----------------------------

const nodeCrypto = require('node:crypto');

// Deterministic byte source: 1, 2, 3, ... so tests can predict the PIN draw
// ([1,2,3,4] -> 0x01020304 -> '909060') while nonces stay unique per length.
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

// Spec-exact reference implementations, independent of the module under test.
function referenceProof(pin, nonceHex) {
  return nodeCrypto.createHmac('sha256', Buffer.from(pin, 'ascii'))
    .update(Buffer.from(`flash-aero-handshake:${nonceHex}`, 'ascii'))
    .digest().toString('hex').slice(0, 32);
}

function referenceMac(pin, payload) {
  return nodeCrypto.createHmac('sha256', Buffer.from(pin, 'ascii'))
    .update(Buffer.from(payload)).digest().toString('hex');
}

function cryptoOverride(randomFn) {
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

function networkOverride(randomFn = deterministicRandom()) {
  const servers = [];
  const connections = [];
  function fakeConnection() {
    const connection = { handlers: {}, closed: false, sent: [],
      on(event, callback) { this.handlers[event] = callback; },
      emit(text) { this.handlers.message?.({ message: new TextEncoder().encode(text) }); },
      emitClose() { this.handlers.close?.(); },
      async send(payload) { this.sent.push(payload.data); },
      close() { this.closed = true; } };
    connections.push(connection);
    return connection;
  }
  const kit = {
    '@kit.CryptoArchitectureKit': cryptoOverride(randomFn),
    '@kit.NetworkKit': {
      mdns: {
        addLocalService: async (context, info) => info,
        removeLocalService: async () => {},
        createDiscoveryService: () => ({
          on() {}, off() {}, startSearchingMDNS() {}, stopSearchingMDNS() {} })
      },
      socket: {
        constructTCPSocketServerInstance: () => {
          const server = { handlers: {},
            on(event, callback) { this.handlers[event] = callback; },
            listen: async () => {},
            getLocalAddress: async () => ({ port: 4321 }),
            close: async () => {} };
          servers.push(server);
          return server;
        },
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
    }
  };
  return { kit, servers, fakeConnection, client: () => connections[connections.length - 1] };
}

function transferLoader(net) {
  return createLoader({ 'data/LocalBackupTransfer': null, ...net.kit });
}

function lastChallengeLine(client) {
  const line = client.sent.filter(item => typeof item === 'string' && item.startsWith('CHALLENGE ')).pop();
  assert.ok(line, 'receiver must send a CHALLENGE line');
  return line.slice('CHALLENGE '.length, -1);
}

// Malformed traffic and excess challenges never get proof answers.
test('sender drops malformed traffic silently and caps proofs per connection', async () => {
  const net = networkOverride();
  const { LocalBackupSender } = transferLoader(net)('data/LocalBackupTransfer');
  let finished;
  const sender = new LocalBackupSender({}, '{}', success => { finished = success; });
  await sender.start();
  try {
    const server = net.servers[0];
    const garbage = net.fakeConnection();
    server.handlers.connect(garbage);
    garbage.emit('GET / HTTP/1.0\r\n');
    await until(() => garbage.closed);
    assert.deepEqual(garbage.sent, [], 'malformed traffic gets no reply');
    assert.equal(finished, undefined, 'malformed requests never end the session');

    const connection = net.fakeConnection();
    server.handlers.connect(connection);
    const nonce = 'a1'.repeat(16);
    for (let round = 0; round < 5; round++) {
      connection.emit(`CHALLENGE ${nonce}\n`);
      await until(() => connection.sent.length >= (round + 1) * 3);
      assert.match(connection.sent[round * 3], /^FLASH-AERO\/1 [0-9a-f]{32}\n$/);
      assert.match(connection.sent[round * 3 + 1], /^OK 2 [0-9a-f]{64}\n$/);
    }
    assert.equal(connection.sent.length, 15, 'five proofs served');
    connection.emit(`CHALLENGE ${nonce}\n`);
    await until(() => connection.closed);
    assert.equal(connection.sent.length, 15, 'a sixth challenge gets no answer');
    assert.equal(finished, undefined, 'looping peer ends only its own connection');
  } finally {
    await sender.stop(false);
  }
});

test('sender completes the session when the verifier closes after a served payload', async () => {
  const net = networkOverride();
  const { LocalBackupSender } = transferLoader(net)('data/LocalBackupTransfer');
  let finished;
  const sender = new LocalBackupSender({}, '{"ok":true}', success => { finished = success; });
  await sender.start();
  const server = net.servers[0];
  const connection = net.fakeConnection();
  server.handlers.connect(connection);
  const nonce = 'c3'.repeat(16);
  connection.emit(`CHALLENGE ${nonce}\n`);
  await until(() => connection.sent.length === 3);
  assert.equal(new TextDecoder().decode(connection.sent[2]), '{"ok":true}');
  assert.equal(finished, undefined, 'sender waits for the verifier instead of self-closing');
  connection.emitClose();
  await until(() => finished !== undefined);
  assert.equal(finished, true, 'peer close after a served payload ends the session as success');
});

test('an idle connection is dropped and the slot is released', async () => {
  const net = networkOverride();
  const { LocalBackupSender } = transferLoader(net)('data/LocalBackupTransfer');
  const sender = new LocalBackupSender({}, '{}', () => {}, 80);
  await sender.start();
  try {
    const server = net.servers[0];
    const squatter = net.fakeConnection();
    server.handlers.connect(squatter);
    await sleep(160);
    assert.ok(squatter.closed, 'silent connection must be dropped');
    const next = net.fakeConnection();
    server.handlers.connect(next);
    assert.ok(!next.closed, 'freed slot accepts the next client');
    next.emit('FLA');
    await sleep(40);
    next.emit('SH-AERO/1 123');
    await sleep(40);
    assert.ok(!next.closed, 'drip-fed bytes renew the idle deadline');
    await sleep(160);
    assert.ok(next.closed, 'connection times out once the drip stops');
  } finally {
    await sender.stop(false);
  }
});

const FAST_BACKOFF = [1, 2, 3, 4];

test('receiver rejects wrong proofs with backoff and disconnects on the fifth failure', async () => {
  const net = networkOverride();
  const { LocalBackupReceiver } = transferLoader(net)('data/LocalBackupTransfer');
  const device = { id: 'd', name: 'n', host: '127.0.0.1', port: 4321 };
  const receiver = LocalBackupReceiver.start(device, () => '123456', 60000, 60000, FAST_BACKOFF);
  // Attach the rejection expectation up front: the result rejects while the
  // test is still polling for the close, and a transiently unhandled
  // rejection would fail the run under node --test.
  const rejection = assert.rejects(receiver.result, /PIN 不正确/);
  const client = net.client();
  await flush();
  for (let round = 0; round < 4; round++) {
    const nonce = lastChallengeLine(client);
    // The pipelined tail after a rejected proof is drained, not parsed.
    client.emit(`FLASH-AERO/1 ${referenceProof('999999', nonce)}\nOK 2 ${referenceMac('999999', '{}')}\n{}`);
    await until(() => client.sent.filter(item => typeof item === 'string' && item.startsWith('CHALLENGE ')).length === round + 2);
  }
  const lastNonce = lastChallengeLine(client);
  client.emit(`FLASH-AERO/1 ${referenceProof('999999', lastNonce)}\n`);
  await until(() => client.closed);
  assert.ok(client.sent.includes('ERR PIN\n'), 'fifth failure replies ERR PIN before closing');
  await rejection;
});

test('receiver picks up a corrected PIN on re-challenge', async () => {
  const net = networkOverride();
  const { LocalBackupReceiver } = transferLoader(net)('data/LocalBackupTransfer');
  const device = { id: 'd', name: 'n', host: '127.0.0.1', port: 4321 };
  let entered = '111111';
  const receiver = LocalBackupReceiver.start(device, () => entered, 60000, 60000, FAST_BACKOFF);
  const client = net.client();
  await flush();
  // The sender proves knowledge of the displayed PIN '999999' while the user
  // has typed '111111'; the answer (always pipelined) is rejected and drained.
  client.emit(`FLASH-AERO/1 ${referenceProof('999999', lastChallengeLine(client))}\nOK 2 ${referenceMac('999999', '{}')}\n{}`);
  await until(() => client.sent.filter(item => typeof item === 'string' && item.startsWith('CHALLENGE ')).length === 2);
  entered = '999999';
  const nonce = lastChallengeLine(client);
  const payload = '{"ok":true}';
  client.emit(`FLASH-AERO/1 ${referenceProof('999999', nonce)}\nOK ${payload.length} ${referenceMac('999999', payload)}\n${payload}`);
  assert.equal(await receiver.result, payload);
});

test('receiver timeout renews with arriving data instead of a hard deadline', async () => {
  const net = networkOverride();
  const { LocalBackupReceiver } = transferLoader(net)('data/LocalBackupTransfer');
  const device = { id: 'd', name: 'n', host: '127.0.0.1', port: 4321 };
  const receiver = LocalBackupReceiver.start(device, () => '123456', 100, 60000, FAST_BACKOFF);
  const client = net.client();
  await flush();
  const payload = '{}';
  client.emit(`FLASH-AERO/1 ${referenceProof('123456', lastChallengeLine(client))}\nOK 2 ${referenceMac('123456', payload)}\n`);
  await sleep(70);
  client.emit('{');
  await sleep(70); // 140 ms in, beyond the idle window but never idle that long
  client.emit('}');
  assert.equal(await receiver.result, '{}');

  const stalled = LocalBackupReceiver.start(device, () => '123456', 100, 60000, FAST_BACKOFF);
  const stalledClient = net.client();
  await flush();
  stalledClient.emit(`FLASH-AERO/1 ${referenceProof('123456', lastChallengeLine(stalledClient))}\nOK 2 ${referenceMac('123456', payload)}\n{`);
  await assert.rejects(stalled.result, /接收超时/);
  assert.ok(stalledClient.closed);
});
