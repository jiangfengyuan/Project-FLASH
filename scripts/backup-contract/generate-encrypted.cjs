// Deterministic encrypted-envelope corpus (flash-backup-enc-v1). Salts and
// nonces are fixed per fixture so the committed files can be regenerated
// byte-for-byte; real exports always draw fresh random values.
// Usage: node generate-encrypted.cjs [--check]
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const envelope = require('./envelope.cjs');

const fixtures = path.resolve(__dirname, '../../docs/contracts/fixtures');
const root = path.join(fixtures, 'encrypted');
// NFC passphrase with CJK and a precomposed é; cases also feed its NFD spelling.
const PASSPHRASE = 'Flash 备份 café 2026';
const PASSPHRASE_NFD = 'Flash 备份 café 2026';
const WRONG_PASSPHRASE = 'Flash 备份 cafe 2026';
const FIXTURE_ITERATIONS = envelope.MIN_ITERATIONS; // keeps four ports' test suites fast

const fixed = (label, name, length) => crypto.createHash('sha256').update(`${label}:${name}`).digest().subarray(0, length);
const sealFile = (name, plaintext, iterations = FIXTURE_ITERATIONS) => envelope.encryptBytes(plaintext, PASSPHRASE, {
  salt: fixed('salt', name, envelope.SALT_BYTES), nonce: fixed('nonce', name, envelope.NONCE_BYTES), iterations
});
const readFixture = file => fs.readFileSync(path.join(fixtures, file));
const stringify = value => JSON.stringify(value, null, 2) + '\n';
// Manifest stays pure ASCII so editors cannot silently re-normalize the passphrases.
const ascii = text => text.replace(/[\u007f-￿]/g, c => '\\u' + c.charCodeAt(0).toString(16).padStart(4, '0'));

function build() {
  const files = new Map();
  const cases = [];
  const add = (file, contents, ...entries) => {
    if (contents !== undefined) files.set(file, Buffer.isBuffer(contents) ? contents : Buffer.from(contents, 'utf8'));
    for (const entry of entries) cases.push({ file, ...entry });
  };

  // Valid envelopes. The minimal one uses the export iteration count.
  add('valid-enc-full.json', sealFile('valid-enc-full.json', readFixture('valid-full.json')),
    { expect: 'ok', plaintext: 'valid-full.json', innerValid: true },
    { expect: 'ok', passphrase: PASSPHRASE_NFD, plaintext: 'valid-full.json', innerValid: true },
    { expect: 'authenticationFailed', passphrase: WRONG_PASSPHRASE });
  add('valid-enc-schema2.json', sealFile('valid-enc-schema2.json', readFixture('valid-schema2.json')),
    { expect: 'ok', plaintext: 'valid-schema2.json', innerValid: true });
  const minimal = sealFile('valid-enc-minimal.json', readFixture('valid-minimal.json'), envelope.EXPORT_ITERATIONS);
  add('valid-enc-minimal.json', minimal, { expect: 'ok', plaintext: 'valid-minimal.json', innerValid: true });
  // Decrypts fine; the inner document must then fail the normal v2 importer.
  add('enc-inner-invalid.json', sealFile('enc-inner-invalid.json', readFixture('invalid-importance-range.json')),
    { expect: 'ok', plaintext: 'invalid-importance-range.json', innerValid: false });
  add('enc-inner-envelope.json', sealFile('enc-inner-envelope.json', minimal),
    { expect: 'ok', plaintext: 'encrypted/valid-enc-minimal.json', innerValid: false });

  // Authentication failures from tampering (base: valid-enc-full).
  const full = JSON.parse(files.get('valid-enc-full.json').toString('utf8'));
  const tamper = (file, mutate) => {
    const d = structuredClone(full); mutate(d); add(file, stringify(d), { expect: 'authenticationFailed' });
  };
  const flip = (b64, index) => { const b = Buffer.from(b64, 'base64'); b[(index + b.length) % b.length] ^= 0x01; return b.toString('base64'); };
  tamper('enc-tampered-ciphertext.json', d => { d.ciphertext = flip(d.ciphertext, 0); });
  tamper('enc-tampered-tag.json', d => { d.ciphertext = flip(d.ciphertext, -1); });
  tamper('enc-tampered-nonce.json', d => { d.cipher.nonce = flip(d.cipher.nonce, 0); });
  tamper('enc-tampered-salt.json', d => { d.kdf.salt = flip(d.kdf.salt, 0); });
  tamper('enc-tampered-iterations.json', d => { d.kdf.iterations += 1; });

  // Shape errors and unsupported algorithms (base: valid-enc-minimal; rejected before any KDF).
  const base = JSON.parse(minimal.toString('utf8'));
  const mutate = (name, expect, change) => {
    const d = structuredClone(base); change(d); add(`enc-${name}.json`, stringify(d), { expect });
  };
  mutate('unknown-version', 'unsupported', d => { d.version = 'flash-backup-enc-v9'; d.extra = true; });
  mutate('unknown-kdf', 'unsupported', d => { d.kdf = { name: 'Argon2id', memoryKiB: 65536, passes: 3, salt: d.kdf.salt }; });
  mutate('unknown-cipher', 'unsupported', d => { d.cipher = { name: 'ChaCha20-Poly1305', nonce: d.cipher.nonce }; });
  mutate('iterations-low', 'invalidEnvelope', d => { d.kdf.iterations = envelope.MIN_ITERATIONS - 1; });
  mutate('iterations-high', 'invalidEnvelope', d => { d.kdf.iterations = envelope.MAX_ITERATIONS + 1; });
  mutate('iterations-boolean', 'invalidEnvelope', d => { d.kdf.iterations = true; });
  mutate('iterations-fraction', 'invalidEnvelope', d => { d.kdf.iterations = 100000.5; });
  mutate('iterations-string', 'invalidEnvelope', d => { d.kdf.iterations = '600000'; });
  mutate('salt-short', 'invalidEnvelope', d => { d.kdf.salt = Buffer.alloc(15, 7).toString('base64'); });
  mutate('nonce-long', 'invalidEnvelope', d => { d.cipher.nonce = Buffer.alloc(13, 7).toString('base64'); });
  // 16 bytes end in one sextet with 4 unused bits; setting one makes it non-canonical.
  mutate('salt-noncanonical', 'invalidEnvelope', d => {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    const last = d.kdf.salt[21];
    d.kdf.salt = d.kdf.salt.slice(0, 21) + alphabet[alphabet.indexOf(last) | 1] + '==';
  });
  mutate('salt-unpadded', 'invalidEnvelope', d => { d.kdf.salt = d.kdf.salt.replace(/=+$/, ''); });
  mutate('ciphertext-whitespace', 'invalidEnvelope', d => { d.ciphertext = d.ciphertext.slice(0, 8) + '\n' + d.ciphertext.slice(8); });
  mutate('ciphertext-short', 'invalidEnvelope', d => { d.ciphertext = Buffer.alloc(15, 7).toString('base64'); });
  mutate('ciphertext-not-string', 'invalidEnvelope', d => { d.ciphertext = 42; });
  mutate('missing-ciphertext', 'invalidEnvelope', d => { delete d.ciphertext; });
  mutate('unknown-root-field', 'invalidEnvelope', d => { d.exportedAt = '2026-11-08T00:00:00.000Z'; });
  mutate('unknown-kdf-field', 'invalidEnvelope', d => { d.kdf.pepper = 'x'; });
  mutate('kdf-not-object', 'invalidEnvelope', d => { d.kdf = 'PBKDF2-HMAC-SHA256'; });
  mutate('cipher-name-not-string', 'invalidEnvelope', d => { d.cipher.name = 1; });

  // Raw text: JSON.parse would erase the first key; escaped spelling must still collide.
  add('enc-duplicate-key.json', minimal.toString('utf8').replace('"ciphertext":', '"\\u0063iphertext": "AAAA",\n  "ciphertext":'),
    { expect: 'invalidJSON' });

  const manifest = { passphrase: PASSPHRASE, cases };
  files.set('cases.json', Buffer.from(ascii(stringify(manifest)), 'utf8'));
  return files;
}

if (require.main === module) {
  const check = process.argv.includes('--check');
  const files = build();
  if (!check) fs.mkdirSync(root, { recursive: true });
  for (const [file, contents] of files) {
    const target = path.join(root, file);
    if (check) {
      if (!fs.existsSync(target) || !fs.readFileSync(target).equals(contents)) throw new Error(`Stale encrypted fixture: ${file}`);
    } else fs.writeFileSync(target, contents);
  }
  if (check) {
    const extra = fs.readdirSync(root).filter(file => !files.has(file));
    if (extra.length) throw new Error(`Unexpected encrypted fixtures: ${extra.join(', ')}`);
  }
}

module.exports = { build, PASSPHRASE, PASSPHRASE_NFD, WRONG_PASSPHRASE };
