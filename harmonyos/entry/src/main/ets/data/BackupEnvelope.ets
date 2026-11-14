/**
 * flash-backup-enc-v1 的常量与错误类型（docs/contracts/flash-backup-enc-v1.md）。
 * 不依赖平台模块：BackupService 与 BackupFiles 只需识别加密文件，不必加载加密框架。
 */
export const ENVELOPE_VERSION: string = 'flash-backup-enc-v1';
export const ENVELOPE_VERSION_PREFIX: string = 'flash-backup-enc-';
/** 加密文件上限：50 MiB 明文 Base64 后约 66.7 MiB，另留信封头余量 */
export const MAX_ENVELOPE_BYTES: number = 72 * 1024 * 1024;

export enum EnvelopeErrorKind {
  /** 文件是加密备份，需要口令（界面据此弹出口令框，而不是报错） */
  PASSPHRASE_REQUIRED = 'passphraseRequired',
  /** 信封不符合 §2（字段、取值或 Base64 编码） */
  INVALID = 'invalidEnvelope',
  /** 未知的信封版本、KDF 或算法 */
  UNSUPPORTED = 'unsupported',
  /** GCM 认证失败：口令错误或文件被改动，二者无法区分；可直接重试 */
  AUTHENTICATION_FAILED = 'authenticationFailed'
}

export class EnvelopeError extends Error {
  kind: EnvelopeErrorKind;

  constructor(kind: EnvelopeErrorKind, message: string) {
    super(message);
    this.kind = kind;
  }
}

export function envelopeErrorKind(error: Object | undefined | null): EnvelopeErrorKind | undefined {
  return error instanceof EnvelopeError ? error.kind : undefined;
}
