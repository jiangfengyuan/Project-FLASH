const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');

test('quarantine IO diagnostics do not copy exception payloads into logs', async () => {
  const secret = 'FICTIONAL_BACKUP_BODY_AND_SESSION_MATERIAL';
  const load = createLoader({ '@kit.CoreFileKit': { fileIo: {
    access: async () => { throw new Error(secret); },
    mkdir: async () => { throw new Error(secret); }
  } } });
  const store = new (load('data/FlashStore').FlashStore)();
  store.filesDir = '/fictional-private-container';
  const recorded = [], original = console.error;
  console.error = (...args) => recorded.push(args.join(' '));
  try {
    assert.equal(await store.writeQuarantineFile('logs.json', secret), false);
    assert.equal(recorded.length, 1, 'operation failure remains diagnosable');
    assert.equal(recorded.join('\n').includes(secret), false, 'untrusted error text is private');
  } finally { console.error = original; }
});
