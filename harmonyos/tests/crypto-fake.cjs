// Node-backed stand-in for @kit.CryptoArchitectureKit used by host tests.
// It follows the documented cryptoFramework shapes (DataBlob, GcmParamsSpec,
// PBKDF2Spec, encrypt doFinal returning the GCM tag) so the actual
// BackupEncryption.ets logic runs unchanged. It is NOT native verification:
// hvigor builds and devices must still confirm the platform implementation.
const crypto = require('node:crypto');

const CryptoMode = { ENCRYPT_MODE: 0, DECRYPT_MODE: 1 };

function cryptoFramework() {
  return {
    CryptoMode,
    createRandom: () => ({ generateRandomSync: n => ({ data: new Uint8Array(crypto.randomBytes(n)) }) }),
    createKdf: algorithm => {
      if (algorithm !== 'PBKDF2|SHA256') throw new Error(`unsupported kdf ${algorithm}`);
      return {
        generateSecret: async spec => {
          const password = typeof spec.password === 'string' ? Buffer.from(spec.password, 'utf8') : Buffer.from(spec.password);
          return { data: new Uint8Array(crypto.pbkdf2Sync(password, Buffer.from(spec.salt), spec.iterations, spec.keySize, 'sha256')) };
        }
      };
    },
    createSymKeyGenerator: algorithm => {
      if (algorithm !== 'AES256') throw new Error(`unsupported key ${algorithm}`);
      // Copy: the caller zeroes its derived-secret buffer after conversion.
      return { convertKey: async blob => ({ algName: 'AES256', bytes: Buffer.from(blob.data) }) };
    },
    createCipher: transformation => {
      if (transformation !== 'AES256|GCM|NoPadding') throw new Error(`unsupported cipher ${transformation}`);
      let engine = null;
      let mode = null;
      return {
        init: async (cipherMode, key, params) => {
          mode = cipherMode;
          const iv = Buffer.from(params.iv.data);
          engine = mode === CryptoMode.ENCRYPT_MODE ?
            crypto.createCipheriv('aes-256-gcm', key.bytes, iv) : crypto.createDecipheriv('aes-256-gcm', key.bytes, iv);
          if (params.aad) engine.setAAD(Buffer.from(params.aad.data));
          if (mode === CryptoMode.DECRYPT_MODE) engine.setAuthTag(Buffer.from(params.authTag.data));
        },
        update: async blob => ({ data: new Uint8Array(engine.update(Buffer.from(blob.data))) }),
        doFinal: async blob => {
          const tail = blob ? engine.update(Buffer.from(blob.data)) : Buffer.alloc(0);
          const final = engine.final(); // throws on GCM authentication failure
          const out = mode === CryptoMode.ENCRYPT_MODE ? Buffer.concat([tail, final, engine.getAuthTag()]) : Buffer.concat([tail, final]);
          return { data: new Uint8Array(out) };
        }
      };
    }
  };
}

/** util.Base64Helper subset; strictness is enforced by BackupEncryption's own canonical pattern. */
class Base64Helper {
  encodeToStringSync(bytes) { return Buffer.from(bytes).toString('base64'); }
  decodeSync(text) { return new Uint8Array(Buffer.from(text, 'base64')); }
}

module.exports = { cryptoFramework, Base64Helper, CryptoMode };
