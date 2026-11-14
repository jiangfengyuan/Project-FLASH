// Reference implementation of the flash-backup-enc-v1 envelope
// (docs/contracts/flash-backup-enc-v1.md). Development-only: native ports use
// their platform crypto APIs and must agree with the shared fixtures.
const crypto = require('node:crypto');
const { TextDecoder } = require('node:util');

const VERSION = 'flash-backup-enc-v1';
const VERSION_PREFIX = 'flash-backup-enc-';
const KDF_NAME = 'PBKDF2-HMAC-SHA256';
const CIPHER_NAME = 'AES-256-GCM';
const EXPORT_ITERATIONS = 600000;
const MIN_ITERATIONS = 100000;
const MAX_ITERATIONS = 10000000;
const SALT_BYTES = 16;
const NONCE_BYTES = 12;
const TAG_BYTES = 16;
const MAX_PLAINTEXT_BYTES = 50 * 1024 * 1024;
const MAX_ENVELOPE_BYTES = 72 * 1024 * 1024;
const MAX_CIPHERTEXT_BASE64 = 4 * Math.ceil((MAX_PLAINTEXT_BYTES + TAG_BYTES) / 3);
const MIN_EXPORT_PASSPHRASE = 8;
const MAX_PASSPHRASE = 1024;

class EnvelopeError extends Error {
  constructor(code, path, message) {
    super(`${code} ${path}: ${message}`);
    this.code = code; // invalidJSON | invalidEnvelope | unsupported | authenticationFailed
    this.path = path;
  }
}
const invalid = (path, message) => new EnvelopeError('invalidEnvelope', path, message);
const unsupported = (path, message) => new EnvelopeError('unsupported', path, message);

/** Canonical RFC 4648 §4: decoding then re-encoding must reproduce the input exactly. */
function decodeCanonicalBase64(value, path) {
  if (typeof value !== 'string') throw invalid(path, 'expected a base64 string');
  const bytes = Buffer.from(value, 'base64');
  if (bytes.toString('base64') !== value) throw invalid(path, 'non-canonical base64');
  return bytes;
}

function exactKeys(object, keys, path) {
  if (object === null || typeof object !== 'object' || Array.isArray(object)) throw invalid(path, 'expected an object');
  const actual = Object.keys(object);
  for (const key of actual) if (!keys.includes(key)) throw invalid(`${path}/${key}`, 'unknown field');
  for (const key of keys) if (!actual.includes(key)) throw invalid(`${path}/${key}`, 'missing field');
}

/** True when a parsed root declares any encrypted-envelope version. */
function isEnvelopeRoot(root) {
  return root !== null && typeof root === 'object' && !Array.isArray(root) &&
    typeof root.version === 'string' && root.version.startsWith(VERSION_PREFIX);
}

/** Staged validation; order is part of the contract (unsupported before field-shape errors). */
function parseEnvelope(root) {
  if (root === null || typeof root !== 'object' || Array.isArray(root)) throw invalid('/', 'expected an object');
  if (typeof root.version !== 'string' || !root.version.startsWith(VERSION_PREFIX)) throw invalid('/version', 'not an encrypted backup');
  if (root.version !== VERSION) throw unsupported('/version', root.version);
  exactKeys(root, ['version', 'kdf', 'cipher', 'ciphertext'], '');

  const kdf = root.kdf;
  if (kdf === null || typeof kdf !== 'object' || Array.isArray(kdf)) throw invalid('/kdf', 'expected an object');
  if (typeof kdf.name !== 'string') throw invalid('/kdf/name', 'expected a string');
  if (kdf.name !== KDF_NAME) throw unsupported('/kdf/name', kdf.name);
  exactKeys(kdf, ['name', 'iterations', 'salt'], '/kdf');
  if (typeof kdf.iterations !== 'number' || !Number.isInteger(kdf.iterations) ||
      kdf.iterations < MIN_ITERATIONS || kdf.iterations > MAX_ITERATIONS) throw invalid('/kdf/iterations', 'out of range');
  const salt = decodeCanonicalBase64(kdf.salt, '/kdf/salt');
  if (salt.length !== SALT_BYTES) throw invalid('/kdf/salt', `expected ${SALT_BYTES} bytes`);

  const cipher = root.cipher;
  if (cipher === null || typeof cipher !== 'object' || Array.isArray(cipher)) throw invalid('/cipher', 'expected an object');
  if (typeof cipher.name !== 'string') throw invalid('/cipher/name', 'expected a string');
  if (cipher.name !== CIPHER_NAME) throw unsupported('/cipher/name', cipher.name);
  exactKeys(cipher, ['name', 'nonce'], '/cipher');
  const nonce = decodeCanonicalBase64(cipher.nonce, '/cipher/nonce');
  if (nonce.length !== NONCE_BYTES) throw invalid('/cipher/nonce', `expected ${NONCE_BYTES} bytes`);

  if (typeof root.ciphertext !== 'string') throw invalid('/ciphertext', 'expected a base64 string');
  if (root.ciphertext.length > MAX_CIPHERTEXT_BASE64) throw invalid('/ciphertext', 'too large');
  const sealed = decodeCanonicalBase64(root.ciphertext, '/ciphertext');
  if (sealed.length < TAG_BYTES) throw invalid('/ciphertext', 'shorter than the tag');
  return { iterations: kdf.iterations, salt, nonce, sealed };
}

function passphraseBytes(passphrase) {
  return Buffer.from(passphrase.normalize('NFC'), 'utf8');
}

function deriveKey(passphrase, salt, iterations) {
  return crypto.pbkdf2Sync(passphraseBytes(passphrase), salt, iterations, 32, 'sha256');
}

function open(envelope, passphrase) {
  const key = deriveKey(passphrase, envelope.salt, envelope.iterations);
  const body = envelope.sealed.subarray(0, envelope.sealed.length - TAG_BYTES);
  const tag = envelope.sealed.subarray(envelope.sealed.length - TAG_BYTES);
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, envelope.nonce, { authTagLength: TAG_BYTES });
  decipher.setAAD(Buffer.from(VERSION, 'utf8'));
  decipher.setAuthTag(tag);
  try {
    return Buffer.concat([decipher.update(body), decipher.final()]);
  } catch (_) {
    throw new EnvelopeError('authenticationFailed', '/ciphertext', 'wrong passphrase or corrupted file');
  }
}

/** File bytes → decrypted plaintext bytes (still to be validated as flash-backup-v2). */
function decryptBytes(bytes, passphrase) {
  if (bytes.byteLength > MAX_ENVELOPE_BYTES) throw invalid('/', 'file too large');
  let root;
  try {
    if (bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) throw new Error('BOM');
    const text = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
    require('./validate.cjs').rejectDuplicateKeys(text);
    root = JSON.parse(text);
  } catch (_) {
    throw new EnvelopeError('invalidJSON', '/', 'Expected UTF-8 JSON without BOM');
  }
  return open(parseEnvelope(root), passphrase);
}

function encryptBytes(plaintext, passphrase, { salt = crypto.randomBytes(SALT_BYTES),
  nonce = crypto.randomBytes(NONCE_BYTES), iterations = EXPORT_ITERATIONS } = {}) {
  if (plaintext.byteLength > MAX_PLAINTEXT_BYTES) throw new Error('plaintext exceeds 50 MiB');
  const key = deriveKey(passphrase, salt, iterations);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, nonce, { authTagLength: TAG_BYTES });
  cipher.setAAD(Buffer.from(VERSION, 'utf8'));
  const sealed = Buffer.concat([cipher.update(plaintext), cipher.final(), cipher.getAuthTag()]);
  const envelope = {
    version: VERSION,
    kdf: { name: KDF_NAME, iterations, salt: salt.toString('base64') },
    cipher: { name: CIPHER_NAME, nonce: nonce.toString('base64') },
    ciphertext: sealed.toString('base64')
  };
  return Buffer.from(JSON.stringify(envelope, null, 2) + '\n', 'utf8');
}

/** Export-time passphrase rule; import accepts any non-empty passphrase. */
function exportPassphraseProblem(passphrase) {
  const length = [...passphrase.normalize('NFC')].length;
  if (length < MIN_EXPORT_PASSPHRASE) return 'tooShort';
  if (length > MAX_PASSPHRASE) return 'tooLong';
  return null;
}

module.exports = {
  VERSION, VERSION_PREFIX, KDF_NAME, CIPHER_NAME, EXPORT_ITERATIONS, MIN_ITERATIONS, MAX_ITERATIONS,
  SALT_BYTES, NONCE_BYTES, TAG_BYTES, MAX_PLAINTEXT_BYTES, MAX_ENVELOPE_BYTES, MAX_CIPHERTEXT_BASE64,
  MIN_EXPORT_PASSPHRASE, MAX_PASSPHRASE,
  EnvelopeError, isEnvelopeRoot, parseEnvelope, decryptBytes, encryptBytes, exportPassphraseProblem, deriveKey
};
