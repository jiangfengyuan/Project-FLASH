// flash-backup-enc-v1 on HarmonyOS: the actual BackupEncryption.ets / BackupController.ets
// sources run against a Node-backed cryptoFramework fake (tests/crypto-fake.cjs).
// This verifies codec and flow logic, not the native cryptoFramework implementation.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createLoader } = require('./ets-loader.cjs');
const { validateBytes } = require('../../scripts/backup-contract/validate.cjs');

const fixtures = path.resolve(__dirname, '../../docs/contracts/fixtures');
const read = relative => fs.readFileSync(path.join(fixtures, relative), 'utf8');
const manifest = JSON.parse(read('encrypted/cases.json'));

function modules() {
  const load = createLoader();
  return { load, ...load('data/BackupEncryption'), ...load('data/BackupEnvelope'), ...load('data/BackupService') };
}

function category(error, EnvelopeError) {
  if (error instanceof EnvelopeError) return error.kind;
  return 'invalidJSON';
}

test('shared encrypted corpus', async () => {
  const { BackupEncryption, BackupService, EnvelopeError } = modules();
  assert.ok(manifest.cases.length >= 30);
  for (const item of manifest.cases) {
    const envelope = read(`encrypted/${item.file}`);
    const passphrase = item.passphrase ?? manifest.passphrase;
    if (item.expect === 'ok') {
      const plaintext = await BackupEncryption.decrypt(envelope, passphrase);
      assert.equal(plaintext, read(item.plaintext), item.file);
      let innerValid = true;
      try { BackupService.parseStrict(plaintext); } catch (_) { innerValid = false; }
      assert.equal(innerValid, item.innerValid, item.file);
    } else {
      await assert.rejects(BackupEncryption.decrypt(envelope, passphrase),
        error => category(error, EnvelopeError) === item.expect, item.file);
    }
  }
});

test('plaintext importers signal encrypted files instead of reporting a version mismatch', async () => {
  const { BackupEncryption, BackupService, EnvelopeErrorKind } = modules();
  const envelope = read('encrypted/valid-enc-full.json');
  for (const parse of [BackupService.parseStrict, BackupService.parseRecovery]) {
    assert.throws(() => parse(envelope), error => error.kind === EnvelopeErrorKind.PASSPHRASE_REQUIRED);
  }
  const future = read('encrypted/enc-unknown-version.json');
  assert.throws(() => BackupService.parseStrict(future), error => error.kind === EnvelopeErrorKind.PASSPHRASE_REQUIRED);
  await assert.rejects(BackupEncryption.decrypt(future, 'x'), error => error.kind === EnvelopeErrorKind.UNSUPPORTED);
});

test('round trip uses fresh salt/nonce and 600,000 iterations', async () => {
  const { BackupEncryption, EnvelopeErrorKind } = modules();
  const plaintext = read('valid-full.json');
  const a = JSON.parse(await BackupEncryption.encrypt(plaintext, 'correct horse'));
  const b = JSON.parse(await BackupEncryption.encrypt(plaintext, 'correct horse'));
  assert.equal(a.kdf.iterations, 600000);
  assert.notEqual(a.kdf.salt, b.kdf.salt);
  assert.notEqual(a.cipher.nonce, b.cipher.nonce);
  assert.equal(await BackupEncryption.decrypt(JSON.stringify(a), 'correct horse'), plaintext);
  await assert.rejects(BackupEncryption.decrypt(JSON.stringify(a), 'correct horsE'),
    error => error.kind === EnvelopeErrorKind.AUTHENTICATION_FAILED);
});

test('deterministic encryption matches the reference fixture byte-for-byte', async () => {
  const { BackupEncryption } = modules();
  const expected = read('encrypted/valid-enc-minimal.json');
  const root = JSON.parse(expected);
  const produced = await BackupEncryption.encrypt(read('valid-minimal.json'), manifest.passphrase, {
    salt: new Uint8Array(Buffer.from(root.kdf.salt, 'base64')),
    nonce: new Uint8Array(Buffer.from(root.cipher.nonce, 'base64')),
    iterations: root.kdf.iterations
  });
  assert.equal(produced, expected);
});

test('export passphrase rules count NFC code points', async () => {
  const { BackupEncryption } = modules();
  assert.notEqual(BackupEncryption.exportPassphraseProblem('1234567'), '');
  assert.equal(BackupEncryption.exportPassphraseProblem('12345678'), '');
  assert.notEqual(BackupEncryption.exportPassphraseProblem('😀'.repeat(7)), '');
  assert.notEqual(BackupEncryption.exportPassphraseProblem('café 12'), '');
  assert.notEqual(BackupEncryption.exportPassphraseProblem('x'.repeat(1025)), '');
  await assert.rejects(BackupEncryption.encrypt('{}', 'short'));
  assert.equal(BackupEncryption.MAX_CIPHERTEXT_BASE64, 69905088);
});

test('parseText keeps inner rules and never decrypts nested envelopes', async () => {
  const { BackupEncryption, EnvelopeErrorKind } = modules();
  const inner = read('encrypted/enc-inner-invalid.json');
  await assert.rejects(BackupEncryption.parseText(inner, false, manifest.passphrase));
  assert.equal((await BackupEncryption.parseText(inner, true, manifest.passphrase)).skippedLogs, 1);
  await assert.rejects(BackupEncryption.parseText(read('encrypted/enc-inner-envelope.json'), false, manifest.passphrase),
    error => error.kind !== EnvelopeErrorKind.PASSPHRASE_REQUIRED);
  const full = read('valid-full.json');
  assert.deepEqual((await BackupEncryption.parseText(full, false, 'ignored')).logs.map(x => x.id),
    JSON.parse(full).data.logs.map(x => x.id));
});

// ---- BackupController flows ----

function runtime() {
  const messages = [];
  return { messages, context: () => ({}), notify: message => messages.push(message),
    errorMessage: error => error.message };
}

function store() {
  const data = { logs: [], emotions: [], tasks: [] };
  return { ready: true, snapshot: () => ({ logs: data.logs.slice(), emotions: data.emotions.slice(), tasks: data.tasks.slice() }) };
}

function controllerWith(files) {
  const load = createLoader({ 'data/BackupFiles': { BackupFiles: files } });
  const { BackupState, ImportPhase } = load('state/FeatureStates');
  const { BackupController } = load('state/BackupController');
  const state = new BackupState();
  const r = runtime();
  return { controller: new BackupController(state, r, store()), state, r, ImportPhase, load };
}

test('export options default to encryption and write an envelope with an -encrypted name', async () => {
  const written = [];
  const files = {
    exportJSON: async (context, json, prefix, encrypted) => { written.push({ json, prefix, encrypted }); },
    importJSON: async () => { throw new Error('unused'); },
    sharedExportName: (prefix, day, encrypted = false) => `${prefix}-${day}${encrypted ? '-encrypted' : ''}.json`
  };
  const { controller, state, load } = controllerWith(files);
  controller.requestExport('file');
  assert.equal(state.exportTarget, 'file');
  await controller.confirmExport('correct horse');
  assert.equal(state.exportTarget, '');
  assert.equal(written[0].encrypted, true);
  const { BackupEncryption } = load('data/BackupEncryption');
  const plaintext = await BackupEncryption.decrypt(written[0].json, 'correct horse');
  assert.deepEqual(validateBytes(Buffer.from(plaintext)), { valid: true, errors: [] });

  controller.requestExport('file');
  await controller.confirmExport(undefined);
  assert.equal(written[1].encrypted, false);
  assert.deepEqual(validateBytes(Buffer.from(written[1].json)), { valid: true, errors: [] });
});

test('importing an encrypted file asks for the passphrase, retries after a wrong one, then previews', async () => {
  let picks = 0;
  const files = {
    exportJSON: async () => {},
    importJSON: async () => { picks++; return read('encrypted/valid-enc-full.json'); },
    sharedExportName: (prefix, day) => `${prefix}-${day}.json`
  };
  const { controller, state, ImportPhase } = controllerWith(files);
  await controller.chooseBackup();
  assert.equal(state.importPhase, ImportPhase.PASSPHRASE);
  assert.equal(state.passphraseError, '');

  await controller.submitPassphrase('wrong passphrase');
  assert.equal(state.importPhase, ImportPhase.PASSPHRASE, 'stays on the passphrase panel');
  assert.ok(state.passphraseError.length > 0);

  await controller.submitPassphrase(manifest.passphrase);
  assert.equal(state.importPhase, ImportPhase.PREVIEW);
  assert.equal(state.passphraseError, '');
  assert.equal(picks, 1, 'the file picker is not reopened for a retry');
});

test('cancelling the passphrase panel drops the pending encrypted text', async () => {
  const files = {
    exportJSON: async () => {},
    importJSON: async () => read('encrypted/valid-enc-full.json'),
    sharedExportName: (prefix, day) => `${prefix}-${day}.json`
  };
  const { controller, state, ImportPhase } = controllerWith(files);
  await controller.chooseBackup(true);
  assert.equal(state.importPhase, ImportPhase.PASSPHRASE);
  controller.cancelImport();
  assert.equal(state.importPhase, ImportPhase.IDLE);
  await controller.submitPassphrase(manifest.passphrase);
  assert.equal(state.importPhase, ImportPhase.IDLE, 'nothing left to decrypt after cancel');
});

test('unsupported envelopes are reported, not prompted for', async () => {
  const files = {
    exportJSON: async () => {},
    importJSON: async () => read('encrypted/enc-unknown-cipher.json'),
    sharedExportName: (prefix, day) => `${prefix}-${day}.json`
  };
  const { controller, state, r, ImportPhase } = controllerWith(files);
  await controller.chooseBackup();
  assert.equal(state.importPhase, ImportPhase.PASSPHRASE, 'version is recognised first');
  await controller.submitPassphrase('anything');
  assert.equal(state.importPhase, ImportPhase.IDLE);
  assert.ok(r.messages.some(m => m.includes('更新')));
});
