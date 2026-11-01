// Exercise the actual ArkTS recovery entry, with the existing explicit platform fakes.
const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');

test('recovery rejects duplicate and escaped-equivalent keys before materialization', () => {
  const { BackupService } = createLoader()('data/BackupService');
  for (const key of ['logs', '\\u006cogs']) {
    const json = `{"version":"flash-backup-v1","logs":[],"${key}":[],"emotions":[]}`;
    assert.throws(() => BackupService.parseRecovery(json), /重复键/);
  }
});

test('recovery rejects deeply nested skipped records before JSON.parse', () => {
  const { BackupService } = createLoader()('data/BackupService');
  const nested = '['.repeat(130) + '0' + ']'.repeat(130);
  const json = `{"version":"flash-backup-v1","logs":[${nested}],"emotions":[]}`;
  assert.throws(() => BackupService.parseRecovery(json), /JSON/);
});

test('recovery still reports ordinary damaged records and accepts legacy empty backups', () => {
  const { BackupService } = createLoader()('data/BackupService');
  const recovered = BackupService.parseRecovery('{"version":"flash-backup-v1","logs":[null],"emotions":[]}');
  assert.equal(recovered.skippedLogs, 1);
  assert.equal(recovered.logs.length, 0);
  const empty = BackupService.parseRecovery('{"version":"flash-backup-v1","logs":[],"emotions":[]}');
  assert.equal(empty.skippedLogs, 0);
});

test('recovery rejects dense under-byte-cap input before allocating its object tree', () => {
  const { BackupService } = createLoader()('data/BackupService');
  const json = '{"version":"flash-backup-v1","logs":[' + '0,'.repeat(10_000_000) + '0],"emotions":[]}';
  assert.ok(Buffer.byteLength(json) < 50 * 1024 * 1024);
  assert.throws(() => BackupService.parseRecovery(json), /资源上限/);
});
