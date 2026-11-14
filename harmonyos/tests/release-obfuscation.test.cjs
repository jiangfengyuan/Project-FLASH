// PR #3 F-05: a release build with property obfuscation renamed colorTag -> w5,
// schemas -> i14 and createdAt -> a6 (observed in nameCache.json and modules.abc),
// which would corrupt every backup and database row serialized with JSON.stringify.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('release obfuscation cannot rename serialized properties', () => {
  const rules = fs.readFileSync(path.join(__dirname, '../entry/obfuscation-rules.txt'), 'utf8');
  const active = rules.split('\n').map(line => line.trim()).filter(line => line && !line.startsWith('#'));
  assert.ok(!active.includes('-enable-property-obfuscation'));
  assert.ok(!active.includes('-enable-string-property-obfuscation'));
  const profile = fs.readFileSync(path.join(__dirname, '../entry/build-profile.json5'), 'utf8');
  assert.match(profile, /obfuscation-rules\.txt/);
});
