// PR #3 F-23: socket events can split or coalesce protocol bytes at any boundary,
// including while the async proof/MAC check is pending. Exercises the archived
// legacy receiver; the production app ships no LAN transport (see lan-disablement).
const test = require('node:test');
const assert = require('node:assert/strict');
const nodeCrypto = require('node:crypto');
const { createLoader } = require('./ets-loader.cjs');

const PIN = '123456';
const flush = () => new Promise(resolve => setImmediate(resolve));
const proofFor = nonce => nodeCrypto.createHmac('sha256', Buffer.from(PIN, 'ascii'))
  .update(Buffer.from(`flash-aero-handshake:${nonce}`, 'ascii')).digest('hex').slice(0, 32);
const macFor = payload => nodeCrypto.createHmac('sha256', Buffer.from(PIN, 'ascii'))
  .update(Buffer.from(payload)).digest('hex');

function start() {
  const clients = [];
  const load = createLoader({
    'data/LocalBackupTransfer': null,
    '@kit.CryptoArchitectureKit': { cryptoFramework: {
      createRandom: () => ({ generateRandomSync: length => ({ data: nodeCrypto.randomBytes(length) }) }),
      createSymKeyGenerator: () => ({ convertKey: async blob => ({ blob: blob.data }) }),
      createMac: () => {
        let hmac;
        return {
          init: async key => { hmac = nodeCrypto.createHmac('sha256', Buffer.from(key.blob)); },
          update: async data => { hmac.update(Buffer.from(data.data)); },
          doFinal: async () => ({ data: new Uint8Array(hmac.digest()) })
        };
      }
    } },
    '@kit.NetworkKit': { mdns: {}, socket: { constructTCPSocketInstance: () => {
      const client = { handlers: {}, closed: false, sent: [],
        on(event, callback) { this.handlers[event] = callback; },
        emit(bytes) {
          const data = typeof bytes === 'string' ? new TextEncoder().encode(bytes) : bytes;
          this.handlers.message?.({ message: data });
        },
        async connect() {},
        async send(payload) { this.sent.push(payload.data); },
        close() { if (!this.closed) { this.closed = true; this.handlers.close?.(); } } };
      clients.push(client);
      return client;
    } } }
  }, { legacyLan: true });
  const { LocalBackupReceiver } = load('data/LocalBackupTransfer');
  const receiver = LocalBackupReceiver.start({ id: 'd', name: 'n', host: '127.0.0.1', port: 4321 },
    () => PIN, 60000, 60000, [1, 2, 3, 4]);
  return { receiver, client: clients[clients.length - 1] };
}

async function challenge(client) {
  for (let i = 0; i < 1000 && client.sent.length === 0; i++) await flush();
  return client.sent[client.sent.length - 1].slice('CHALLENGE '.length, -1);
}

const PAYLOAD = JSON.stringify({ logs: Array.from({ length: 40 }, (_, index) => `第 ${index} 条灵感`) });

test('OK header in a later synchronous event than the proof line is not read as the proof', async () => {
  const { receiver, client } = start();
  const nonce = await challenge(client);
  client.emit(`FLASH-AERO/1 ${proofFor(nonce)}\n`);
  client.emit(`OK ${Buffer.byteLength(PAYLOAD)} ${macFor(PAYLOAD)}\n${PAYLOAD}`);
  assert.equal(await receiver.result, PAYLOAD);
});

test('a payload delivered one byte per event survives pending async checks', async () => {
  const { receiver, client } = start();
  const nonce = await challenge(client);
  const bytes = Buffer.from(`FLASH-AERO/1 ${proofFor(nonce)}\nOK ${Buffer.byteLength(PAYLOAD)} ${macFor(PAYLOAD)}\n${PAYLOAD}`);
  for (const byte of bytes) client.emit(Uint8Array.of(byte));
  assert.equal(await receiver.result, PAYLOAD);
});

test('fragments that yield to the event loop between chunks still parse', async () => {
  const { receiver, client } = start();
  const nonce = await challenge(client);
  const bytes = Buffer.from(`FLASH-AERO/1 ${proofFor(nonce)}\nOK ${Buffer.byteLength(PAYLOAD)} ${macFor(PAYLOAD)}\n${PAYLOAD}`);
  for (let offset = 0; offset < bytes.length; offset += 7) {
    client.emit(new Uint8Array(bytes.subarray(offset, offset + 7)));
    await flush();
  }
  assert.equal(await receiver.result, PAYLOAD);
});

test('fully coalesced delivery parses in one event', async () => {
  const { receiver, client } = start();
  const nonce = await challenge(client);
  client.emit(`FLASH-AERO/1 ${proofFor(nonce)}\nOK ${Buffer.byteLength(PAYLOAD)} ${macFor(PAYLOAD)}\n${PAYLOAD}`);
  assert.equal(await receiver.result, PAYLOAD);
});

test('a wrong proof keeps the tail buffered and discards it without misparsing', async () => {
  const { receiver, client } = start();
  const nonce = await challenge(client);
  const tail = `OK ${Buffer.byteLength(PAYLOAD)} ${macFor(PAYLOAD)}\n${PAYLOAD}`;
  client.emit(`FLASH-AERO/1 ${'0'.repeat(32)}\n`);
  client.emit(tail);
  for (let i = 0; i < 1000 && client.sent.length < 2; i++) await new Promise(resolve => setTimeout(resolve, 1));
  assert.equal(client.sent.length, 2, 'a fresh challenge follows the drained tail');
  const second = client.sent[1].slice('CHALLENGE '.length, -1);
  assert.notEqual(second, nonce);
  client.emit(`FLASH-AERO/1 ${proofFor(second)}\n`);
  client.emit(tail);
  assert.equal(await receiver.result, PAYLOAD);
});

test('truncation before the full payload rejects promptly instead of idling', async () => {
  const { receiver, client } = start();
  const nonce = await challenge(client);
  client.emit(`FLASH-AERO/1 ${proofFor(nonce)}\nOK ${Buffer.byteLength(PAYLOAD)} ${macFor(PAYLOAD)}\n${PAYLOAD.slice(0, 10)}`);
  await flush(); await flush();
  client.close();
  await assert.rejects(receiver.result, /连接已断开/);
});

test('a line split mid-truncation does not yield a result', async () => {
  const { receiver, client } = start();
  await challenge(client);
  client.emit('FLASH-AERO/1 ab');
  client.close();
  await assert.rejects(receiver.result, /连接已断开/);
});

test('extra bytes arriving during the MAC check are rejected', async () => {
  const { receiver, client } = start();
  const nonce = await challenge(client);
  client.emit(`FLASH-AERO/1 ${proofFor(nonce)}\n`);
  client.emit(`OK ${Buffer.byteLength(PAYLOAD)} ${macFor(PAYLOAD)}\n${PAYLOAD}`);
  client.emit('x');
  await assert.rejects(receiver.result, /额外数据/);
});

test('over-limit input while a check is pending is rejected, not buffered', async () => {
  const { receiver, client } = start();
  const nonce = await challenge(client);
  client.emit(`FLASH-AERO/1 ${proofFor(nonce)}\n`);
  client.emit(new Uint8Array(50 * 1024 * 1024 + 256 + 1));
  await assert.rejects(receiver.result, /过长|过大/);
  assert.ok(client.closed);
});

test('over-long header lines and oversize OK sizes are rejected', async () => {
  const first = start();
  await challenge(first.client);
  first.client.emit('A'.repeat(65));
  await assert.rejects(first.receiver.result, /过长/);
  const second = start();
  const nonce = await challenge(second.client);
  second.client.emit(`FLASH-AERO/1 ${proofFor(nonce)}\n`);
  second.client.emit(`OK 52428801 ${'ab'.repeat(32)}\n`);
  await assert.rejects(second.receiver.result, /大小异常/);
});
