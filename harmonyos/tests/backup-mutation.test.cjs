// Deterministic structural mutation testing of the actual strict codec against
// the existing contract oracle. This is host coverage, not a native OOM proof.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createLoader } = require('./ets-loader.cjs');
const { validateBytes } = require('../../scripts/backup-contract/validate.cjs');

test('256 deterministic structural backup mutations agree with the contract oracle', () => {
  const source = fs.readFileSync(path.join(__dirname, '../../docs/contracts/fixtures/valid-full.json'), 'utf8');
  const { BackupService } = createLoader()('data/BackupService');
  let state = 0xf1a5;
  const next = () => (state = (Math.imul(state, 1664525) + 1013904223) >>> 0);
  const chars = ['{', '}', '[', ']', ':', ',', '"', '\\', '0', 'x', ' ', '\n'];
  for (let i = 0; i < 256; i++) {
    const at = next() % source.length;
    const replacement = chars[next() % chars.length];
    const candidate = source.slice(0, at) + replacement + source.slice(at + (i % 2));
    const expected = validateBytes(Buffer.from(candidate)).valid;
    let actual = true;
    try { BackupService.parseStrict(candidate); } catch { actual = false; }
    assert.equal(actual, expected, `seed=f1a5 mutation=${i} offset=${at}`);
  }
});
