const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const root = process.env.FLASH_LAN_PROBE_REPO || path.resolve(__dirname, '..');
const { createLoader } = require(path.join(root, 'tests/ets-loader.cjs'));

test('all production LAN actions stay idle before export/context/transport access', async () => {
  let sideEffects = 0;
  const forbidden = () => { sideEffects++; throw new Error('unexpected LAN side effect'); };
  const reason = '局域网传输暂时停用：请使用导出备份或系统分享';
  const load = createLoader({ 'data/LocalBackupTransfer': {
    LAN_UNAVAILABLE_MESSAGE: reason,
    LocalBackupSender: class { constructor() { forbidden(); } },
    LocalBackupDiscovery: class { constructor() { forbidden(); } },
    LocalBackupReceiver: { start: forbidden }
  } });
  const { BackupState, TransferPhase: P } = load('state/FeatureStates');
  const { BackupController } = load('state/BackupController');
  const state = new BackupState(), messages = [];
  const controller = new BackupController(state,
    { context: forbidden, notify: text => messages.push(text), errorMessage: e => e.message },
    { ready: true, snapshot: forbidden });
  await controller.startLanSend();
  assert.equal(state.lanMode, P.IDLE);
  controller.startLanReceive();
  assert.equal(state.lanMode, P.IDLE);
  state.lanMode = P.RECEIVING;
  state.lanDevices = [{ id: 'spoof', name: 'Spoofed sender', host: '127.0.0.1', port: 9 }];
  state.selectedLanDevice = 'spoof'; state.lanEnteredPin = '123456';
  await controller.receiveLan();
  assert.equal(state.lanMode, P.IDLE);
  assert.equal(state.lanPin, ''); assert.deepEqual(state.lanDevices, []);
  assert.equal(state.importSummary, ''); assert.equal(sideEffects, 0);
  assert.deepEqual(messages, [reason, reason, reason]);
});

test('production transfer module exports no legacy network adapters', () => {
  const module = createLoader({ 'data/LocalBackupTransfer': null })('data/LocalBackupTransfer');
  for (const name of ['LocalBackupSender', 'LocalBackupDiscovery', 'LocalBackupReceiver']) {
    assert.equal(module[name], undefined);
  }
  assert.match(module.LAN_UNAVAILABLE_MESSAGE, /局域网传输暂时停用/);
});
