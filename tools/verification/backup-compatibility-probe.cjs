#!/usr/bin/env node
'use strict';
// Executes the production Harmony codec on Node. Native kits use the explicit
// ets-loader fakes: this does not verify ArkTS native/DB/UI behavior.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const { execFileSync } = require('node:child_process');
const root = path.resolve(process.argv[2] || path.join(__dirname, '../..'));
const { createLoader } = require(path.join(root, 'harmonyos/tests/ets-loader.cjs'));
const { BackupService } = createLoader()('data/BackupService');
const fixture = JSON.parse(fs.readFileSync(path.join(root, 'docs/contracts/fixtures/valid-full.json'), 'utf8'));
const results = [];
for (const zone of ['Europe/Kyiv', 'Europe/Kiev', 'Asia/Kolkata', 'Asia/Calcutta', 'UTC', 'Invalid/Unknown']) {
  const input = structuredClone(fixture); input.data.tasks[0].due.timeZone = zone;
  let runtimeAccepted = false, resolvedZone = null, codecAccepted = false;
  try { resolvedZone = new Intl.DateTimeFormat('en', { timeZone: zone }).resolvedOptions().timeZone;
    runtimeAccepted = true; } catch (_) {}
  try { BackupService.parseStrict(JSON.stringify(input)); codecAccepted = true; } catch (_) {}
  results.push({ zone, runtimeAccepted, resolvedZone, codecAccepted });
}
const imported = BackupService.parseStrict(JSON.stringify(fixture));
const exported = BackupService.exportJSON(imported.logs, imported.emotions, imported.tasks, 'fictional codec probe');
const roundtrip = BackupService.parseStrict(exported);
assert.equal(roundtrip.logs.length, 1); assert.equal(roundtrip.emotions.length, 1);
assert.equal(roundtrip.tasks.length, 2);
// Keep actual exported bytes for a later native cross-platform import, rather
// than reporting a fixture/hand-edited schema as an actual Apple export.
const output = process.argv[3];
if (output) fs.writeFileSync(output, exported, { flag: 'wx', mode: 0o600 });
const actualExports = [{ sender: 'HarmonyOS production codec on Node', receiver: 'same codec on Node',
  schemas: JSON.parse(exported).schemas, status: 'accepted', counts: { logs: 1, emotions: 1, tasks: 2 },
  bytes: Buffer.byteLength(exported), sha256: crypto.createHash('sha256').update(exported).digest('hex') }];
// Optional input MUST be an actual recorded export from an app/production
// exporter. Its origin/commit is documented by the caller, not inferred here.
if (process.argv[4]) {
  const bytes = fs.readFileSync(process.argv[4]); let status = 'accepted', error = null;
  try { BackupService.parseStrict(bytes.toString('utf8')); } catch (failure) { status = 'rejected'; error = failure.message; }
  actualExports.push({ sender: 'caller-supplied export; see provenance', receiver: 'HarmonyOS production codec on Node',
    status, error, bytes: bytes.length, sha256: crypto.createHash('sha256').update(bytes).digest('hex') });
}
console.log(JSON.stringify({ kind: 'backup compatibility diagnostic', native: false,
  commit: execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim(),
  codecSHA256: crypto.createHash('sha256').update(fs.readFileSync(path.join(root,
    'harmonyos/entry/src/main/ets/data/BackupService.ets'))).digest('hex'),
  host: { node: process.version, icu: process.versions.icu, tz: process.versions.tz },
  timezoneResults: results, actualExports,
  unverified: ['Apple app/UI export -> Android/Harmony installed app import',
    'all native device imports and persistence', 'platform timezone alias equivalence'] }, null, 2));
