// Host tests for the second bug-fix round: corrupted reminder-id preferences,
// an empty proof backoff table, DST round-trip validation in the task editor
// clock conversion, and the quarantine mtime unit defense. Kits are faked.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const nodeCrypto = require('node:crypto');
const { createLoader } = require('./ets-loader.cjs');

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const flush = () => new Promise(resolve => setImmediate(resolve));
async function waitFor(condition, timeoutMs) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (condition()) return true;
    await sleep(25);
  }
  return condition();
}
function runtime() {
  const messages = [];
  return { messages, context: () => ({}), notify: m => messages.push(m), errorMessage: e => e.message };
}

// --- A4: corrupted reminder-id preferences -----------------------------------

function reminderKits(seed) {
  const published = [];
  const memory = new Map(Object.entries(seed));
  const prefs = {
    getPreferences: async () => ({
      getAll: async () => Object.fromEntries(memory),
      put: async (key, value) => { memory.set(key, value); },
      delete: async (key) => { memory.delete(key); },
      flush: async () => {}
    })
  };
  const kits = {
    '@kit.ArkData': { preferences: prefs, relationalStore: { ConflictResolution: { ON_CONFLICT_REPLACE: 1 } } },
    '@kit.BackgroundTasksKit': { reminderAgentManager: {
      ReminderType: { REMINDER_TYPE_CALENDAR: 0 },
      getAllValidReminders: async () => [],
      publishReminder: async (request) => { published.push(request); return published.length; },
      cancelReminder: async () => {}
    } },
    '@kit.NotificationKit': { notificationManager: {
      SlotType: { UNKNOWN_TYPE: 0, SOCIAL_COMMUNICATION: 1, SERVICE_INFORMATION: 2 },
      getSlot: async () => null,
      addSlot: async () => {},
      requestEnableNotification: async () => {},
      openNotificationSettings: async () => {} } }
  };
  return { published, memory, kits };
}

function futureTask(id) {
  return { id, title: '任务', colorTag: 'daily', importance: 1,
    createdAt: '2026-09-05T00:00:00.000Z', updatedAt: '2026-09-05T00:00:00.000Z',
    reminderAt: '2027-01-01T00:00:00.000Z' };
}

test('rebuild treats corrupted stored ids as no record and publishes valid ids', async () => {
  const { published, memory, kits } = reminderKits({
    't-string': 'bogus', 't-range': 2147483647, 't-fraction': 2.5, 't-zero': 0
  });
  const load = createLoader({ 'data/TaskReminderScheduler': null, ...kits });
  const { TaskReminderScheduler } = load('data/TaskReminderScheduler');
  const tasks = ['t-string', 't-range', 't-fraction', 't-zero'].map(futureTask);
  await TaskReminderScheduler.rebuild({}, tasks, false);
  assert.equal(published.length, 4, 'a corrupted value must not abort the publish loop');
  const ids = published.map(request => request.notificationId);
  for (const id of ids) {
    assert.ok(Number.isInteger(id) && id >= 1 && id <= 2147483646, `valid notification id, got ${id}`);
  }
  assert.equal(new Set(ids).size, ids.length, 'freshly allocated ids do not collide');
  for (const task of tasks) {
    assert.ok(Number.isInteger(memory.get(task.id)), 'the corrupted entry is replaced by the persisted id');
  }
});

// --- A5: empty proof backoff table -------------------------------------------

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
  const connections = [];
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
        constructTCPSocketServerInstance: async () => ({ handlers: {},
          on(event, callback) { this.handlers[event] = callback; },
          listen: async () => {}, getLocalAddress: async () => ({ port: 4321 }), close: async () => {} }),
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
  return { kit, client: () => connections[connections.length - 1] };
}

function transferLoader(net) {
  return createLoader({ 'data/LocalBackupTransfer': null, ...net.kit });
}

function challengeCount(client) {
  return client.sent.filter(item => typeof item === 'string' && item.startsWith('CHALLENGE ')).length;
}

function lastChallengeLine(client) {
  const line = client.sent.filter(item => typeof item === 'string' && item.startsWith('CHALLENGE ')).pop();
  assert.ok(line, 'receiver must send a CHALLENGE line');
  return line.slice('CHALLENGE '.length, -1);
}

test('receiver falls back to the default backoff ladder when the table is empty', async () => {
  const net = networkOverride();
  const { LocalBackupReceiver } = transferLoader(net)('data/LocalBackupTransfer');
  const device = { id: 'd', name: 'n', host: '127.0.0.1', port: 4321 };
  const receiver = LocalBackupReceiver.start(device, () => '123456', 60000, 60000, []);
  const client = net.client();
  await flush();
  const nonce = lastChallengeLine(client);
  client.emit(`FLASH-AERO/1 ${referenceProof('999999', nonce)}\nOK 2 ${referenceMac('999999', '{}')}\n{}`);
  await sleep(150);
  assert.equal(challengeCount(client), 1, 'an empty table must not retry instantly (index -1 means 0 ms)');
  assert.equal(await waitFor(() => challengeCount(client) === 2, 3000), true,
    'the default ladder re-challenges after its first delay');
  const rejection = assert.rejects(receiver.result, /接收已取消/);
  receiver.cancel();
  await rejection;
});

// --- A6: DST round-trip validation ---------------------------------------------

// US-style 2026 rules: EDT (UTC-4) from 2026-03-08T07:00Z, EST (UTC-5) after
// 2026-11-01T06:00Z. Enough to build a nonexistent and an ambiguous wall time.
function dstZoneKit() {
  const EDT = -4 * 3600000;
  const EST = -5 * 3600000;
  const springForward = Date.UTC(2026, 2, 8, 7, 0);
  const fallBack = Date.UTC(2026, 10, 1, 6, 0);
  return { '@kit.LocalizationKit': { i18n: { getTimeZone: (id) => ({
    getID: () => id ?? 'UTC',
    getOffset: (instant) => (instant >= springForward && instant < fallBack) ? EDT : EST
  }) } } };
}

test('localDateToInstant rejects wall times that do not survive a DST round-trip', () => {
  const load = createLoader(dstZoneKit());
  const { CalendarState } = load('state/FeatureStates');
  const { CalendarController } = load('state/CalendarController');
  const controller = new CalendarController(new CalendarState(), runtime(), { saveTask: async () => {} });
  // 2026-03-08 02:30 never happens in the zone (spring forward 02:00 -> 03:00).
  assert.equal(controller.localDateToInstant('2026-03-08', '02:30', 'America/New_York'), undefined);
  // The same minutes on a plain day and right after the gap still resolve.
  assert.equal(controller.localDateToInstant('2026-03-07', '02:30', 'America/New_York').toISOString(),
    '2026-03-07T07:30:00.000Z');
  assert.equal(controller.localDateToInstant('2026-03-08', '03:30', 'America/New_York').toISOString(),
    '2026-03-08T07:30:00.000Z');
  // An ambiguous fall-back wall time resolves deterministically to the first occurrence.
  assert.equal(controller.localDateToInstant('2026-11-01', '01:30', 'America/New_York').toISOString(),
    '2026-11-01T05:30:00.000Z');
});

// --- A7: quarantine mtime unit defense -----------------------------------------

function fileIoWithMtime(unit) {
  const C = fs.constants;
  return {
    OpenMode: { READ_ONLY: C.O_RDONLY, READ_WRITE: C.O_RDWR, CREATE: C.O_CREAT, TRUNC: C.O_TRUNC },
    accessSync: p => fs.existsSync(p),
    mkdirSync: (p, recursive) => fs.mkdirSync(p, { recursive: !!recursive }),
    unlinkSync: p => fs.unlinkSync(p),
    openSync: (p, mode = C.O_RDONLY) => ({ fd: fs.openSync(p, mode) }),
    writeSync: (fd, data, options) => fs.writeSync(fd, data, null, options?.encoding ?? 'utf-8'),
    readSync: (fd, buffer, options) =>
      fs.readSync(fd, Buffer.from(buffer), 0, options?.length ?? buffer.byteLength, 0),
    statSync: fd => {
      const stat = fs.fstatSync(fd);
      const millis = stat.mtime.getTime();
      return { size: stat.size, mtime: unit === 'millis' ? millis : Math.floor(millis / 1000) };
    },
    closeSync: file => fs.closeSync(typeof file === 'object' ? file.fd : file)
  };
}

test('quarantine TTL cleanup works whether stat mtime arrives in seconds or milliseconds', () => {
  for (const unit of ['seconds', 'millis']) {
    const filesDir = fs.mkdtempSync(path.join(os.tmpdir(), `flash-mtime-${unit}-`));
    const load = createLoader({ '@kit.CoreFileKit': { fileIo: fileIoWithMtime(unit) } });
    const { FlashStore } = load('data/FlashStore');
    const store = new FlashStore();
    store.filesDir = filesDir;
    const quarantine = path.join(filesDir, 'quarantine');
    fs.mkdirSync(quarantine);
    const oldFile = path.join(quarantine, 'legacy-logs.json');
    const freshFile = path.join(quarantine, 'legacy-tasks.json');
    fs.writeFileSync(oldFile, 'old');
    fs.writeFileSync(freshFile, 'fresh');
    const old = new Date(Date.now() - 31 * 24 * 60 * 60 * 1000);
    fs.utimesSync(oldFile, old, old);
    store.cleanupQuarantine();
    assert.equal(fs.existsSync(oldFile), false, `${unit}: expired quarantine file is removed`);
    assert.equal(fs.existsSync(freshFile), true, `${unit}: fresh quarantine file survives`);
  }
});
