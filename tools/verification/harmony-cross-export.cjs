#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const { createLoader } = require(path.join(root, 'harmonyos/tests/ets-loader.cjs'));
assert.equal(process.argv.length, 4, 'Usage: harmony-cross-export.cjs actual-input.json NEW-output.json');
const bytes = fs.readFileSync(process.argv[2]);
const { BackupService } = createLoader()('data/BackupService');
const incoming = BackupService.parseStrict(bytes.toString('utf8'));
const encoded = BackupService.exportJSON(incoming.logs, incoming.emotions, incoming.tasks,
  'Fictional cross-platform exporter evidence');
const decoded = BackupService.parseStrict(encoded);
const inputData = JSON.parse(bytes.toString('utf8')).data, outputData = JSON.parse(encoded).data;
for (const section of ['logs', 'emotions', 'tasks']) {
  assert.deepEqual(decoded[section], incoming[section]);
  for (const item of inputData[section]) {
    const out = outputData[section].find(record => record.id === item.id);
    assert.ok(out);
    for (const key of ['isFavorite', 'intensity', 'sourceLogId']) assert.deepEqual(out[key] ?? null, item[key] ?? null);
  }
}
fs.writeFileSync(process.argv[3], encoded, { flag: 'wx', mode: 0o600 });
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
console.log(JSON.stringify({ kind: 'Harmony production codec on Node; not native RDB/device',
  inputSHA256: sha(bytes), outputSHA256: sha(Buffer.from(encoded)), bytes: Buffer.byteLength(encoded),
  incomingMetadataCompared: true, schemas: JSON.parse(encoded).schemas,
  counts: { logs: decoded.logs.length, emotions: decoded.emotions.length, tasks: decoded.tasks.length },
  sourceSHA256: sha(fs.readFileSync(path.join(root, 'harmonyos/entry/src/main/ets/data/BackupService.ets'))) }, null, 2));
