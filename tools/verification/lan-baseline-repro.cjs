#!/usr/bin/env node
'use strict';
// Diagnostic for the legacy protocol, NOT a passing security acceptance test.
// Runs the baseline Harmony sender or explicit archived test-only fixture.
// Native network/crypto kits are faked; archived success is not a live-app bypass.
// No real listener, user data, database writes, PIN reads or secret output.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const root = path.resolve(process.argv[2] || path.join(__dirname, '../..'));
const { createLoader } = require(path.join(root, 'harmonyos/tests/ets-loader.cjs'));
const payload = fs.readFileSync(path.join(root, 'docs/contracts/fixtures/valid-full.json'));
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const flush = () => new Promise(resolve => setImmediate(resolve));
async function until(predicate) {
  const deadline = performance.now() + 2000;
  while (!predicate()) {
    assert.ok(performance.now() < deadline, 'diagnostic control flow timed out');
    await flush();
  }
}
function environment() {
  const state = { advertised: 0, withdrawn: 0, finished: [], closed: false };
  const server = { handlers: {}, on(event, callback) { this.handlers[event] = callback; },
    async listen() {}, async getLocalAddress() { return { port: 4321 }; },
    async close() { state.closed = true; } };
  const load = createLoader({
    'data/LocalBackupTransfer': null,
    '@kit.NetworkKit': { socket: { constructTCPSocketServerInstance: () => server }, mdns: {
      async addLocalService(context, info) { state.advertised++; return info; },
      async removeLocalService() { state.withdrawn++; }
    } },
    '@kit.CryptoArchitectureKit': { cryptoFramework: {
      createRandom: () => ({ generateRandomSync: length => ({ data: crypto.randomBytes(length) }) }),
      createSymKeyGenerator: () => ({ convertKey: async blob => ({ bytes: blob.data }) }),
      createMac: () => { let mac; return {
        async init(key) { mac = crypto.createHmac('sha256', key.bytes); },
        async update(blob) { mac.update(blob.data); },
        async doFinal() { return { data: new Uint8Array(mac.digest()) }; }
      }; }
    } }
  }, { legacyLan: true });
  const { LocalBackupSender } = load('data/LocalBackupTransfer');
  const sender = new LocalBackupSender({}, payload.toString('utf8'), success => state.finished.push(success));
  const connection = { handlers: {}, sent: [], closed: false,
    on(event, callback) { this.handlers[event] = callback; },
    async send(packet) { this.sent.push(typeof packet.data === 'string' ?
      Buffer.from(packet.data) : Buffer.from(packet.data)); },
    close() { if (!this.closed) { this.closed = true; this.handlers.close?.(); } },
    emit(line) { const bytes = new TextEncoder().encode(line); this.handlers.message?.({ message: bytes.buffer }); }
  };
  return { state, sender, connection, connect: () => server.handlers.connect(connection) };
}
async function run() {
  const results = [];
  for (const scenario of ['invalid-challenge-control', 'public-challenge', 'unauthenticated-error-close']) {
    const { state, sender, connection, connect } = environment();
    try {
      await sender.start(); connect();
      if (scenario === 'public-challenge') {
        // The attacker never accesses sender.pin and never supplies a PIN or proof.
        connection.emit(`CHALLENGE ${'00'.repeat(16)}\n`);
        await until(() => connection.sent.length === 3);
        assert.deepEqual(connection.sent[2], payload);
        results.push({ scenario, reproduced: true, suppliedPIN: false,
          plaintextBytes: connection.sent[2].length, payloadSHA256: sha(connection.sent[2]) });
      } else if (scenario === 'unauthenticated-error-close') {
        connection.emit('ERR PIN\n'); connection.close();
        await until(() => state.finished.length === 1);
        assert.deepEqual(state.finished, [false]);
        assert.equal(state.withdrawn, 1); assert.equal(state.closed, true);
        assert.equal(connection.sent.length, 0);
        results.push({ scenario, reproduced: true, suppliedPIN: false,
          advertisementsWithdrawn: state.withdrawn, senderSessionClosed: state.closed });
      } else {
        connection.emit('CHALLENGE invalid\n');
        await until(() => connection.closed);
        assert.equal(connection.sent.length, 0); assert.equal(state.finished.length, 0);
        results.push({ scenario, payloadBytesSent: 0, sessionPreserved: true });
      }
    } finally { await sender.stop(false); }
  }
  const archived = fs.existsSync(path.join(root, 'harmonyos/tests/fixtures/LegacyLocalBackupTransfer.ets'));
  console.log(JSON.stringify({ kind: archived ? 'test-only archived legacy diagnostic' : 'legacy-protocol-diagnostic', platform: 'HarmonyOS source on Node',
    nativeNetwork: false, commit: execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim(),
    sourceSHA256: sha(fs.readFileSync(path.join(root, archived ? 'harmonyos/tests/fixtures/LegacyLocalBackupTransfer.ets' : 'harmonyos/entry/src/main/ets/data/LocalBackupTransfer.ets'))),
    payloadOrigin: 'fictional valid-full.json contract fixture', results }, null, 2));
}
run().catch(error => { console.error(error.message); process.exitCode = 1; });
