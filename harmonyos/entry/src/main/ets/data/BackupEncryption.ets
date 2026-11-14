import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { tr } from './I18n';
import { BackupImport, BackupService } from './BackupService';
import {
  ENVELOPE_VERSION,
  ENVELOPE_VERSION_PREFIX,
  EnvelopeError,
  EnvelopeErrorKind,
  MAX_ENVELOPE_BYTES
} from './BackupEnvelope';

interface EnvelopeDocument {
  version?: Object | null;
  kdf?: Object | null;
  cipher?: Object | null;
  ciphertext?: Object | null;
}

interface EnvelopeKdf {
  name?: Object | null;
  iterations?: Object | null;
  salt?: Object | null;
}

interface EnvelopeCipher {
  name?: Object | null;
  nonce?: Object | null;
}

/** 已通过 §2 校验的信封 */
export interface ParsedEnvelope {
  iterations: number;
  salt: Uint8Array;
  nonce: Uint8Array;
  sealed: Uint8Array;
}

/** 测试注入用；正式导出一律随机生成 salt / nonce 并用 600,000 次 */
export interface EncryptionParameters {
  salt: Uint8Array;
  nonce: Uint8Array;
  iterations: number;
}

/**
 * 口令加密备份信封 `flash-backup-enc-v1`。明文是一份完整 flash-backup-v2 导出的 UTF-8 字节；
 * 本类只负责加解密，解出的明文仍交给 BackupService.parseStrict / parseRecovery。
 * 只用系统 cryptoFramework：PBKDF2|SHA256（API 11+）与 AES256|GCM|NoPadding。
 * KDF 与加解密走异步接口，在系统线程执行，不阻塞界面。
 */
export class BackupEncryption {
  static readonly KDF_NAME: string = 'PBKDF2-HMAC-SHA256';
  static readonly CIPHER_NAME: string = 'AES-256-GCM';
  static readonly EXPORT_ITERATIONS: number = 600000;
  static readonly MIN_ITERATIONS: number = 100000;
  static readonly MAX_ITERATIONS: number = 10000000;
  static readonly MIN_PASSPHRASE_LENGTH: number = 8;
  static readonly MAX_PASSPHRASE_LENGTH: number = 1024;
  private static readonly SALT_BYTES: number = 16;
  private static readonly NONCE_BYTES: number = 12;
  private static readonly TAG_BYTES: number = 16;
  /** 50 MiB 明文 + 标签的 Base64 长度 */
  static readonly MAX_CIPHERTEXT_BASE64: number = 4 * Math.ceil((BackupService.MAX_BYTES + 16) / 3);
  /** 分段送入 GCM：输出与一次性计算相同，避免单次调用的数据量限制 */
  private static readonly CHUNK_BYTES: number = 1024 * 1024;
  /** RFC 4648 §4 规范编码（带填充、无空白、尾位为零） */
  private static readonly CANONICAL_BASE64: RegExp =
    /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/][AQgw]==|[A-Za-z0-9+/]{2}[AEIMQUYcgkosw048]=)?$/;

  // ---- 口令 ----

  private static normalized(passphrase: string): string {
    return passphrase.normalize('NFC');
  }

  /** 导出时检查口令长度（NFC 后按 Unicode 码点计）；返回错误文案或空串。导入接受任何非空口令。 */
  static exportPassphraseProblem(passphrase: string): string {
    const count = Array.from(BackupEncryption.normalized(passphrase)).length;
    if (count < BackupEncryption.MIN_PASSPHRASE_LENGTH) return tr('口令至少需要 8 个字符');
    if (count > BackupEncryption.MAX_PASSPHRASE_LENGTH) return tr('口令不能超过 1024 个字符');
    return '';
  }

  private static async deriveKey(passphrase: string, salt: Uint8Array, iterations: number): Promise<cryptoFramework.SymKey> {
    const password = new util.TextEncoder().encodeInto(BackupEncryption.normalized(passphrase));
    const spec: cryptoFramework.PBKDF2Spec = {
      algName: 'PBKDF2', password: password, salt: salt, iterations: iterations, keySize: 32
    };
    const secret = await cryptoFramework.createKdf('PBKDF2|SHA256').generateSecret(spec);
    password.fill(0);
    try {
      return await cryptoFramework.createSymKeyGenerator('AES256').convertKey({ data: secret.data });
    } finally {
      secret.data.fill(0);
    }
  }

  // ---- 识别与解密 ----

  /** 根对象是否声明任意加密信封版本（>50 MiB 的文件只可能是信封） */
  static isEnvelope(json: string): boolean {
    try {
      const root = JSON.parse(json) as EnvelopeDocument;
      return !!root && typeof root.version === 'string' && root.version.startsWith(ENVELOPE_VERSION_PREFIX);
    } catch (_) {
      return false;
    }
  }

  private static invalid(): EnvelopeError {
    return new EnvelopeError(EnvelopeErrorKind.INVALID, tr('加密备份文件已损坏或格式不正确'));
  }

  private static unsupported(): EnvelopeError {
    return new EnvelopeError(EnvelopeErrorKind.UNSUPPORTED, tr('需要更新 Flash 才能打开此加密备份'));
  }

  private static isObject(value: Object | null | undefined): boolean {
    return !!value && typeof value === 'object' && !Array.isArray(value);
  }

  private static exactKeys(value: Object, keys: string[]): void {
    const actual = Object.keys(value);
    if (actual.length !== keys.length || keys.some((key: string) => !actual.includes(key))) {
      throw BackupEncryption.invalid();
    }
  }

  private static canonicalBase64(value: Object | null | undefined): Uint8Array {
    if (typeof value !== 'string' || !BackupEncryption.CANONICAL_BASE64.test(value)) throw BackupEncryption.invalid();
    return new util.Base64Helper().decodeSync(value);
  }

  /** 按契约顺序校验：先版本，再字段集合；KDF / 算法名先于其余字段判断「不支持」。 */
  static parseEnvelope(json: string): ParsedEnvelope {
    if (json.length > MAX_ENVELOPE_BYTES) throw new Error(tr('备份文件超过 72 MB'));
    if (json.startsWith('﻿')) throw new Error(tr('/：不允许 BOM'));
    BackupService.scanStrictJSON(json);
    let root: EnvelopeDocument;
    try {
      root = JSON.parse(json) as EnvelopeDocument;
    } catch (_) {
      throw new Error(tr('备份文件不是有效的 JSON 对象'));
    }
    if (!BackupEncryption.isObject(root) || typeof root.version !== 'string' ||
      !root.version.startsWith(ENVELOPE_VERSION_PREFIX)) throw BackupEncryption.invalid();
    if (root.version !== ENVELOPE_VERSION) throw BackupEncryption.unsupported();
    BackupEncryption.exactKeys(root, ['version', 'kdf', 'cipher', 'ciphertext']);

    if (!BackupEncryption.isObject(root.kdf)) throw BackupEncryption.invalid();
    const kdf = root.kdf as EnvelopeKdf;
    if (typeof kdf.name !== 'string') throw BackupEncryption.invalid();
    if (kdf.name !== BackupEncryption.KDF_NAME) throw BackupEncryption.unsupported();
    BackupEncryption.exactKeys(kdf, ['name', 'iterations', 'salt']);
    const iterations = kdf.iterations;
    if (typeof iterations !== 'number' || !Number.isInteger(iterations) ||
      iterations < BackupEncryption.MIN_ITERATIONS || iterations > BackupEncryption.MAX_ITERATIONS) {
      throw BackupEncryption.invalid();
    }
    const salt = BackupEncryption.canonicalBase64(kdf.salt);
    if (salt.length !== BackupEncryption.SALT_BYTES) throw BackupEncryption.invalid();

    if (!BackupEncryption.isObject(root.cipher)) throw BackupEncryption.invalid();
    const cipher = root.cipher as EnvelopeCipher;
    if (typeof cipher.name !== 'string') throw BackupEncryption.invalid();
    if (cipher.name !== BackupEncryption.CIPHER_NAME) throw BackupEncryption.unsupported();
    BackupEncryption.exactKeys(cipher, ['name', 'nonce']);
    const nonce = BackupEncryption.canonicalBase64(cipher.nonce);
    if (nonce.length !== BackupEncryption.NONCE_BYTES) throw BackupEncryption.invalid();

    const ciphertext = root.ciphertext;
    if (typeof ciphertext !== 'string' || ciphertext.length > BackupEncryption.MAX_CIPHERTEXT_BASE64) {
      throw BackupEncryption.invalid();
    }
    const sealed = BackupEncryption.canonicalBase64(ciphertext);
    if (sealed.length < BackupEncryption.TAG_BYTES) throw BackupEncryption.invalid();
    return { iterations: iterations, salt: salt, nonce: nonce, sealed: sealed };
  }

  private static gcmParams(nonce: Uint8Array, tag: Uint8Array): cryptoFramework.GcmParamsSpec {
    return {
      algName: 'GcmParamsSpec',
      iv: { data: nonce },
      aad: { data: new util.TextEncoder().encodeInto(ENVELOPE_VERSION) },
      authTag: { data: tag }
    };
  }

  private static async run(cipher: cryptoFramework.Cipher, input: Uint8Array): Promise<Uint8Array> {
    const parts: Uint8Array[] = [];
    for (let offset = 0; offset < input.length; offset += BackupEncryption.CHUNK_BYTES) {
      const out = await cipher.update({ data: input.subarray(offset, Math.min(input.length, offset + BackupEncryption.CHUNK_BYTES)) });
      if (out && out.data && out.data.length > 0) parts.push(out.data);
    }
    const last = await cipher.doFinal(null);
    if (last && last.data && last.data.length > 0) parts.push(last.data);
    let total = 0;
    for (const part of parts) total += part.length;
    const joined = new Uint8Array(total);
    let at = 0;
    for (const part of parts) {
      joined.set(part, at);
      at += part.length;
    }
    return joined;
  }

  private static async open(envelope: ParsedEnvelope, key: cryptoFramework.SymKey): Promise<Uint8Array> {
    const bodyLength = envelope.sealed.length - BackupEncryption.TAG_BYTES;
    try {
      const cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
      await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, key,
        BackupEncryption.gcmParams(envelope.nonce, envelope.sealed.slice(bodyLength)));
      return await BackupEncryption.run(cipher, envelope.sealed.subarray(0, bodyLength));
    } catch (_) {
      throw new EnvelopeError(EnvelopeErrorKind.AUTHENTICATION_FAILED, tr('口令错误，或文件已损坏'));
    }
  }

  /** 校验信封、派生密钥并解密，返回内层 flash-backup-v2 文本（尚未校验）。 */
  static async decrypt(json: string, passphrase: string): Promise<string> {
    const envelope = BackupEncryption.parseEnvelope(json);
    const key = await BackupEncryption.deriveKey(passphrase, envelope.salt, envelope.iterations);
    const plaintext = await BackupEncryption.open(envelope, key);
    if (plaintext.length > BackupService.MAX_BYTES) throw new Error(tr('/：文件超过 50 MiB'));
    try {
      // 不忽略 BOM：U+FEFF 会被严格入口拒绝，与读取明文文件一致
      return util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(plaintext);
    } catch (_) {
      throw new Error(tr('备份文件不是有效的 UTF-8 JSON'));
    } finally {
      plaintext.fill(0);
    }
  }

  /**
   * 文本 → 导入结果。明文 v1/v2 行为不变；加密备份缺口令时抛 PASSPHRASE_REQUIRED，
   * 口令错误抛 AUTHENTICATION_FAILED（可直接重试）。解出的明文只按 v2 解析，不递归解密。
   */
  static async parseText(text: string, recovery: boolean, passphrase?: string): Promise<BackupImport> {
    // 每个字符至少 1 字节：长度超过 50 MiB 的文本不可能是明文备份；信封是纯 ASCII
    if (text.length > BackupService.MAX_BYTES) {
      if (!BackupEncryption.isEnvelope(text)) throw new Error(tr('/：文件超过 50 MiB'));
    } else {
      try {
        return recovery ? BackupService.parseRecovery(text) : BackupService.parseStrict(text);
      } catch (error) {
        if (!(error instanceof EnvelopeError) || error.kind !== EnvelopeErrorKind.PASSPHRASE_REQUIRED) throw error as Error;
      }
    }
    if (passphrase === undefined) {
      throw new EnvelopeError(EnvelopeErrorKind.PASSPHRASE_REQUIRED, tr('这是加密备份，请输入导出时设置的口令'));
    }
    const plaintext = await BackupEncryption.decrypt(text, passphrase);
    try {
      return recovery ? BackupService.parseRecovery(plaintext) : BackupService.parseStrict(plaintext);
    } catch (error) {
      if (error instanceof EnvelopeError && error.kind === EnvelopeErrorKind.PASSPHRASE_REQUIRED) {
        throw new Error(tr('/version：加密备份里不能再嵌套加密备份'));
      }
      throw error as Error;
    }
  }

  // ---- 加密 ----

  /** 加密一份已校验的 v2 导出文本，随后用同一密钥解密自检。 */
  static async encrypt(plaintext: string, passphrase: string, parameters?: EncryptionParameters): Promise<string> {
    if (!parameters) {
      const problem = BackupEncryption.exportPassphraseProblem(passphrase);
      if (problem) throw new Error(problem);
    }
    const random = cryptoFramework.createRandom();
    const salt = parameters ? parameters.salt : random.generateRandomSync(BackupEncryption.SALT_BYTES).data;
    const nonce = parameters ? parameters.nonce : random.generateRandomSync(BackupEncryption.NONCE_BYTES).data;
    const iterations = parameters ? parameters.iterations : BackupEncryption.EXPORT_ITERATIONS;
    const bytes = new util.TextEncoder().encodeInto(plaintext);
    if (bytes.length > BackupService.MAX_BYTES) throw new Error(tr('/：文件超过 50 MiB'));
    const key = await BackupEncryption.deriveKey(passphrase, salt, iterations);
    const cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding');
    await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, key,
      BackupEncryption.gcmParams(nonce, new Uint8Array(BackupEncryption.TAG_BYTES)));
    // 输出为 密文 || 16 字节标签（GCM 加密时 doFinal 给出标签）
    const sealed = await BackupEncryption.run(cipher, bytes);
    const check = await BackupEncryption.open({ iterations: iterations, salt: salt, nonce: nonce, sealed: sealed }, key);
    const matches = check.length === bytes.length && check.every((value: number, index: number) => value === bytes[index]);
    check.fill(0);
    if (!matches) throw new EnvelopeError(EnvelopeErrorKind.AUTHENTICATION_FAILED, tr('口令错误，或文件已损坏'));
    const base64 = new util.Base64Helper();
    // 与参考实现相同的键序与缩进，方便人工核对；读取端不依赖排版
    return '{\n' +
      `  "version": "${ENVELOPE_VERSION}",\n` +
      '  "kdf": {\n' +
      `    "name": "${BackupEncryption.KDF_NAME}",\n` +
      `    "iterations": ${iterations},\n` +
      `    "salt": "${base64.encodeToStringSync(salt)}"\n` +
      '  },\n' +
      '  "cipher": {\n' +
      `    "name": "${BackupEncryption.CIPHER_NAME}",\n` +
      `    "nonce": "${base64.encodeToStringSync(nonce)}"\n` +
      '  },\n' +
      `  "ciphertext": "${base64.encodeToStringSync(sealed)}"\n` +
      '}\n';
  }
}
