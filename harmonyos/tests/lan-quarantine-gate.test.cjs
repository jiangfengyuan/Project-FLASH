// Security regression for PR #3 F-01/B-1: while no reviewed transport exists,
// no production target may carry a network surface a LAN peer could reach.
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const repo = path.resolve(__dirname, '../..');

test('static gate proves no production listener, adapter or network declaration', () => {
  const run = spawnSync('python3', [path.join(repo, 'scripts/check-lan-quarantine.py')], { encoding: 'utf8' });
  assert.equal(run.status, 0, run.stderr);
  assert.equal(JSON.parse(run.stdout).passed, true);
});
