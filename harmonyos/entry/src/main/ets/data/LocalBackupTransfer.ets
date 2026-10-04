import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { mdns, socket } from '@kit.NetworkKit';
import { BackupService } from './BackupService';

const SERVICE_TYPE = '_flashbackup._tcp';
const PROTOCOL = 'FLASH-AERO/1';
const SESSION_MILLIS = 60000;
const SOCKET_TIMEOUT = 15000;
// A connected client that stops sending data must not hold the single
// connection slot forever; idle connections are dropped after this delay.
const IDLE_MILLIS = 10000;
// Hard ceiling for one receiving transfer: a slow drip must not occupy the
// buffer and connection slot past this total, even when every chunk arrives
// inside the idle window.
const TRANSFER_MILLIS = 120000;
const MAX_ATTEMPTS = 5;
// Delay before the verifier re-challenges after proof failures 1-4. The
// schedule throttles online PIN guessing and gives the user a window to
// correct the entered PIN before the next attempt.
const PROOF_BACKOFF_MILLIS: number[] = [1000, 2000, 4000, 8000];
const HANDSHAKE_PREFIX = 'flash-aero-handshake:';
const NONCE_BYTES = 16;
const PROOF_HEX_CHARS = 32;
const MAC_HEX_CHARS = 64;
// CHALLENGE and FLASH-AERO/1 lines stay under 64 bytes; the OK header carries
// the 64-char MAC, so it needs its own larger ceiling ("OK " + 8 digits + " "
// + 64 hex = 76 bytes).
const MAX_HEADER_BYTES = 64;
const MAX_OK_HEADER_BYTES = 128;
const CHALLENGE_LINE = new RegExp(`^CHALLENGE ([0-9a-f]{${NONCE_BYTES * 2}})$`);
const PROOF_LINE = new RegExp(`^${PROTOCOL} ([0-9a-f]{${PROOF_HEX_CHARS}})$`);
const OK_LINE = new RegExp(`^OK ([0-9]+) ([0-9a-f]{${MAC_HEX_CHARS}})$`);
// Largest multiple of 10^6 below 2^32; rejecting draws above it keeps
// value % 1000000 unbiased across the full 6-digit range.
const PIN_DRAW_LIMIT = 4294000000;

function securePin(): string {
  const random = cryptoFramework.createRandom();
  let value = PIN_DRAW_LIMIT;
  while (value >= PIN_DRAW_LIMIT) {
    const bytes = random.generateRandomSync(4).data;
    value = ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) >>> 0;
  }
  return (value % 1000000).toString().padStart(6, '0');
}

function randomNonce(): string {
  return hexEncode(cryptoFramework.createRandom().generateRandomSync(NONCE_BYTES).data);
}

function hexEncode(bytes: Uint8Array): string {
  let result = '';
  for (let index = 0; index < bytes.length; index++) {
    result += bytes[index].toString(16).padStart(2, '0');
  }
  return result;
}

function asciiBytes(text: string): Uint8Array {
  return new util.TextEncoder().encodeInto(text);
}

async function hmacSha256(keyBytes: Uint8Array, message: Uint8Array): Promise<Uint8Array> {
  const generator = cryptoFramework.createSymKeyGenerator('HMAC');
  const key = await generator.convertKey({ data: keyBytes });
  const mac = cryptoFramework.createMac('SHA256');
  await mac.init(key);
  await mac.update({ data: message });
  return (await mac.doFinal()).data;
}

async function handshakeProof(pin: string, nonce: string): Promise<string> {
  const digest = await hmacSha256(asciiBytes(pin), asciiBytes(`${HANDSHAKE_PREFIX}${nonce}`));
  return hexEncode(digest).slice(0, PROOF_HEX_CHARS);
}

async function payloadMac(pin: string, payload: Uint8Array): Promise<string> {
  const digest = await hmacSha256(asciiBytes(pin), payload);
  return hexEncode(digest);
}

/** Length-aware constant-time comparison so proof and MAC checks do not leak
 * a matching prefix through early exit. */
function constantTimeEqual(left: string, right: string): boolean {
  let difference = left.length === right.length ? 0 : 1;
  const length = Math.max(left.length, right.length);
  for (let index = 0; index < length; index++) {
    const leftCode = index < left.length ? left.charCodeAt(index) : 0;
    const rightCode = index < right.length ? right.charCodeAt(index) : 0;
    difference |= leftCode ^ rightCode;
  }
  return difference === 0;
}

export class LanDevice {
  id: string = '';
  name: string = '';
  host: string = '';
  port: number = 0;
}

function decode(buffer: ArrayBuffer): string {
  return new util.TextDecoder('utf-8').decodeToString(new Uint8Array(buffer));
}

export class LocalBackupSender {
  readonly pin: string;
  private server?: socket.TCPSocketServer;
  private service?: mdns.LocalServiceInfo;
  private stopped: boolean = false;
  private activeConnection?: socket.TCPSocketConnection;
  private timer: number = 0;
  private context: common.UIAbilityContext;
  private json: string;
  private payloadBytes: Uint8Array;
  private payloadMacPromise?: Promise<string>;
  private onFinished: (success: boolean) => void;
  private idleMillis: number;

  constructor(context: common.UIAbilityContext, json: string, onFinished: (success: boolean) => void,
    idleMillis: number = IDLE_MILLIS) {
    this.context = context;
    this.json = json;
    this.payloadBytes = new util.TextEncoder().encodeInto(json);
    this.onFinished = onFinished;
    this.idleMillis = idleMillis;
    this.pin = securePin();
  }

  async start(): Promise<void> {
    this.server = socket.constructTCPSocketServerInstance();
    this.server.on('connect', (connection: socket.TCPSocketConnection) => this.handle(connection));
    await this.server.listen({ address: '0.0.0.0', family: 1, port: 0 });
    const address = await this.server.getLocalAddress();
    this.service = { serviceType: SERVICE_TYPE, serviceName: 'Flash Aero HarmonyOS', port: address.port };
    this.service = await mdns.addLocalService(this.context, this.service);
    this.timer = setTimeout(() => this.stop(false), SESSION_MILLIS);
  }

  private mac(): Promise<string> {
    if (!this.payloadMacPromise) this.payloadMacPromise = payloadMac(this.pin, this.payloadBytes);
    return this.payloadMacPromise;
  }

  /** Answer one challenge with the protocol line, the OK header and the
   * payload, pipelined in spec order. The receiver consumes the OK line only
   * after a proof it accepted; an answer it rejects is drained and the next
   * re-challenge is served the same way. */
  private async answer(connection: socket.TCPSocketConnection, nonce: string): Promise<void> {
    const proof = await handshakeProof(this.pin, nonce);
    const mac = await this.mac();
    await connection.send({ data: `${PROTOCOL} ${proof}\n`, encoding: 'UTF-8' });
    await connection.send({ data: `OK ${this.payloadBytes.length} ${mac}\n`, encoding: 'UTF-8' });
    await connection.send({ data: this.payloadBytes.buffer as ArrayBuffer });
  }

  private handle(connection: socket.TCPSocketConnection): void {
    // Process only one request at a time. Without this guard parallel
    // connections could all serve proofs while the single payload slot is
    // already taken.
    if (this.stopped || this.activeConnection) {
      connection.close();
      return;
    }
    this.activeConnection = connection;
    let buffer = '';
    let handled = false;
    let sent = false;
    let rejected = false;
    let challenges = 0;
    let connectionTimer = 0;
    const finish = (success: boolean): void => {
      if (handled) return;
      handled = true;
      clearTimeout(connectionTimer);
      connection.close();
      if (this.activeConnection === connection) this.activeConnection = undefined;
      this.stop(success);
    };
    const closeConnection = (): void => {
      clearTimeout(connectionTimer);
      connection.close();
      if (this.activeConnection === connection) this.activeConnection = undefined;
    };
    // Idle deadline, re-armed on every chunk: a client that drip-feeds
    // challenges must not hold the single slot forever.
    const armIdleTimer = (): void => {
      clearTimeout(connectionTimer);
      connectionTimer = setTimeout(() => {
        if (handled) return;
        // Data was already served; a peer that never closed is finished with
        // the connection either way, so count it as a completed send.
        if (sent) { finish(true); return; }
        // A silent connection that never sent a challenge is dropped without
        // ending the pairing session.
        handled = true;
        closeConnection();
      }, this.idleMillis);
    };
    armIdleTimer();
    connection.on('close', () => {
      if (handled) return;
      handled = true;
      clearTimeout(connectionTimer);
      if (this.activeConnection === connection) this.activeConnection = undefined;
      // The verifier closes after consuming a good transfer, and also closes
      // after the fifth rejected proof; its ERR line tells the two apart.
      if (sent || rejected) this.stop(!rejected);
    });
    connection.on('message', (info: socket.SocketMessageInfo) => {
      if (this.stopped || handled) return;
      armIdleTimer();
      buffer += decode(info.message);
      while (buffer.length > 0) {
        const newline = buffer.indexOf('\n');
        if (newline < 0) {
          if (buffer.length > MAX_HEADER_BYTES) {
            handled = true;
            closeConnection();
          }
          return;
        }
        const line = buffer.slice(0, newline).replace('\r', '');
        buffer = buffer.slice(newline + 1);
        if (line.length > MAX_HEADER_BYTES) {
          handled = true;
          closeConnection();
          return;
        }
        const challenge = CHALLENGE_LINE.exec(line);
        if (challenge) {
          challenges++;
          // Serve at most five proofs per connection, mirroring the
          // verifier's five-attempt budget; beyond that the peer is looping.
          if (challenges > MAX_ATTEMPTS) {
            handled = true;
            closeConnection();
            return;
          }
          this.answer(connection, challenge[1])
            .then(() => {
              sent = true;
            })
            .catch(() => {
              finish(false);
            });
          return;
        }
        if (line === 'ERR PIN') {
          // The verifier counted its fifth rejected proof and is closing.
          rejected = true;
          return;
        }
        // Only well-formed protocol lines are served. Malformed traffic
        // (port scans, stray connections) is dropped silently so it cannot
        // burn proof answers.
        handled = true;
        closeConnection();
        return;
      }
    });
  }

  async stop(success: boolean = false): Promise<void> {
    if (this.stopped) return;
    this.stopped = true;
    clearTimeout(this.timer);
    if (this.service) {
      try { await mdns.removeLocalService(this.context, this.service); } catch (_) {}
    }
    if (this.server) {
      try { await this.server.close(); } catch (_) {}
    }
    if (this.activeConnection) {
      try { await this.activeConnection.close(); } catch (_) {}
      this.activeConnection = undefined;
    }
    this.onFinished(success);
  }
}

export class LocalBackupDiscovery {
  private context: common.UIAbilityContext;
  private discovery?: mdns.DiscoveryService;
  private devices: Map<string, LanDevice> = new Map<string, LanDevice>();
  private onChange: (devices: LanDevice[]) => void;

  constructor(context: common.UIAbilityContext, onChange: (devices: LanDevice[]) => void) {
    this.context = context;
    this.onChange = onChange;
  }

  start(): void {
    if (this.discovery) return;
    this.discovery = mdns.createDiscoveryService(this.context, SERVICE_TYPE);
    this.discovery.on('serviceFound', (info: mdns.LocalServiceInfo) => {
      mdns.resolveLocalService(this.context, info).then((resolved: mdns.LocalServiceInfo) => {
        if (!resolved.host || resolved.port === undefined || resolved.port < 1 || resolved.port > 65535) return;
        // Key entries by host:port so a forged same-name service cannot
        // displace the genuine one; same-name devices stay listed side by side.
        const device: LanDevice = {
          id: `${resolved.host.address}:${resolved.port}`,
          name: resolved.serviceName,
          host: resolved.host.address,
          port: resolved.port
        };
        this.devices.set(device.id, device);
        this.onChange(Array.from(this.devices.values()));
      }).catch(() => {});
    });
    this.discovery.on('serviceLost', (info: mdns.LocalServiceInfo) => {
      this.devices.forEach((device: LanDevice, id: string) => {
        // A loss event carries the bare service record; only require the host
        // to match when the event actually resolved one, so unresolved losses
        // still retire every entry advertised under the lost name.
        if (device.name === info.serviceName &&
          (!info.host || device.host === info.host.address)) {
          this.devices.delete(id);
        }
      });
      this.onChange(Array.from(this.devices.values()));
    });
    this.discovery.startSearchingMDNS();
  }

  stop(): void {
    if (!this.discovery) return;
    this.discovery.stopSearchingMDNS();
    this.discovery.off('serviceFound');
    this.discovery.off('serviceLost');
    this.discovery = undefined;
    this.devices.clear();
    this.onChange([]);
  }
}

type ProofPhase = 'proof' | 'ok' | 'payload' | 'discard';

export class LocalBackupReceiver {
  readonly result: Promise<string>;
  private client: socket.TCPSocket;
  private finished: boolean = false;
  private timer: number = 0;
  private capTimer: number = 0;
  private timeoutMillis: number;
  private rejectOperation?: (reason: Error) => void;
  private lastChallengeNonce: string = '';

  private constructor(device: LanDevice, pinSource: () => string, timeoutMillis: number,
    transferMillis: number, backoffMillis: number[]) {
    if (!/^\d{6}$/.test(pinSource())) throw new Error('请输入六位数字 PIN');
    if (!device.host || !Number.isInteger(device.port) || device.port < 1 || device.port > 65535) {
      throw new Error('发送设备地址无效');
    }
    this.timeoutMillis = timeoutMillis;
    this.client = socket.constructTCPSocketInstance();
    this.result = new Promise<string>((resolve, reject) => {
      this.rejectOperation = reject;
      let phase: ProofPhase = 'proof';
      let authenticatedPin = pinSource();
      let failedProofs = 0;
      let headerBytes: number[] = [];
      let payload: Uint8Array | undefined;
      let payloadOffset = 0;
      let expectedMac = '';
      // The sender pipelines its proof answer, OK header and payload. After a
      // rejected proof that tail is drained (not parsed) before the next
      // challenge goes out. `incoming`/`cursor` keep the not-yet-consumed
      // bytes across asynchronous proof/MAC checks.
      let incoming: Uint8Array = new Uint8Array(0);
      let cursor = 0;
      let discardRemaining = 0;
      let discardHeader = true;
      let discardComplete = true;
      let backoffTimer = 0;
      let rechallengePending = false;
      this.armTimer();
      this.capTimer = setTimeout(() => this.fail('传输超时'), transferMillis);
      const sendChallenge = (): void => {
        phase = 'proof';
        headerBytes = [];
        discardComplete = false;
        rechallengePending = false;
        this.lastChallengeNonce = randomNonce();
        this.client.send({ data: `CHALLENGE ${this.lastChallengeNonce}\n`, encoding: 'UTF-8' }).catch(() => {
          this.fail('发送挑战失败');
        });
      };
      const armBackoff = (): void => {
        // Re-read the entered PIN when the next proof arrives: the user may
        // correct it while the backoff window runs.
        rechallengePending = true;
        // An empty backoff table would index -1 (undefined → 0 ms) and retry
        // instantly; fall back to the default ladder instead.
        const ladder = backoffMillis.length > 0 ? backoffMillis : PROOF_BACKOFF_MILLIS;
        const delay = ladder[Math.min(failedProofs, ladder.length) - 1];
        backoffTimer = setTimeout(() => {
          backoffTimer = 0;
          if (this.finished) return;
          if (discardComplete) {
            sendChallenge();
            process();
          }
        }, delay);
      };
      const rejectProof = (): void => {
        failedProofs++;
        if (failedProofs >= MAX_ATTEMPTS) {
          // Fifth failure: the session counts the loss and the connection
          // closes, with the legacy error line so the sender can tell a
          // rejected pairing apart from a completed transfer.
          this.client.send({ data: 'ERR PIN\n', encoding: 'UTF-8' })
            .catch(() => {})
            .finally(() => this.fail('PIN 不正确'));
          return;
        }
        discardRemaining = 0;
        discardHeader = true;
        discardComplete = false;
        phase = 'discard';
        armBackoff();
      };
      const process = (): void => {
        while (cursor < incoming.length && !this.finished) {
          if (phase === 'proof' || phase === 'ok' || (phase === 'discard' && discardHeader)) {
            const lineLimit = phase === 'proof' ? MAX_HEADER_BYTES : MAX_OK_HEADER_BYTES;
            while (cursor < incoming.length && incoming[cursor] !== 10) {
              headerBytes.push(incoming[cursor++]);
              if (headerBytes.length > lineLimit) { this.fail('发送方响应头过长'); return; }
            }
            if (cursor >= incoming.length) return;
            cursor++;
            const line = new util.TextDecoder('utf-8')
              .decodeToString(new Uint8Array(headerBytes)).replace('\r', '');
            headerBytes = [];
            if (phase === 'discard') {
              const discarded = OK_LINE.exec(line);
              if (!discarded) { this.fail('发送方返回了无效响应'); return; }
              discardRemaining = Number.parseInt(discarded[1]);
              discardHeader = false;
              continue;
            }
            if (phase === 'proof') {
              const proof = PROOF_LINE.exec(line);
              if (!proof) { this.fail('发送方返回了无效响应'); return; }
              const nonceLine = this.lastChallengeNonce;
              const proofValue = proof[1];
              handshakeProof(pinSource(), nonceLine).then((expected) => {
                if (this.finished || phase !== 'proof') return;
                if (constantTimeEqual(expected, proofValue)) {
                  authenticatedPin = pinSource();
                  phase = 'ok';
                } else {
                  rejectProof();
                }
                process();
              }).catch(() => this.fail('无法校验发送方凭证'));
              return;
            }
            const header = OK_LINE.exec(line);
            if (!header) { this.fail('发送方返回了无效响应'); return; }
            const size = Number.parseInt(header[1]);
            if (size < 1 || size > BackupService.MAX_BYTES) {
              this.fail('接收的备份文件大小异常');
              return;
            }
            expectedMac = header[2];
            payload = new Uint8Array(size);
            payloadOffset = 0;
            phase = 'payload';
            continue;
          }
          if (phase === 'discard') {
            if (discardRemaining === 0) {
              // Tail already drained; either re-arm the next round now or
              // wait for the backoff timer to fire and re-enter the loop.
              discardComplete = true;
              if (rechallengePending && backoffTimer === 0) sendChallenge();
              if (phase === 'discard') return;
              continue;
            }
            const take = Math.min(discardRemaining, incoming.length - cursor);
            cursor += take;
            discardRemaining -= take;
            if (discardRemaining === 0) {
              discardComplete = true;
              if (rechallengePending && backoffTimer === 0) sendChallenge();
            }
            continue;
          }
          if (!payload) return;
          const remaining = payload.length - payloadOffset;
          const available = incoming.length - cursor;
          if (available > remaining) { this.fail('发送方返回了额外数据'); return; }
          payload.set(incoming.subarray(cursor), payloadOffset);
          payloadOffset += available;
          cursor = incoming.length;
          if (payloadOffset !== payload.length) return;
          const received = payload;
          payloadMac(authenticatedPin, received).then((mac) => {
            if (this.finished) return;
            if (!constantTimeEqual(mac, expectedMac)) {
              // Whole-transfer integrity: a tampered payload is discarded in
              // full and never reaches parsing or preview.
              this.fail('接收的数据校验失败，已整体丢弃');
              return;
            }
            try {
              // No ignoreBOM: a UTF-8 BOM survives as U+FEFF and the strict
              // importer rejects it, matching the other platforms.
              const decoder = util.TextDecoder.create('utf-8', { fatal: true });
              const json = decoder.decodeToString(received);
              this.finished = true;
              clearTimeout(this.timer);
              clearTimeout(this.capTimer);
              clearTimeout(backoffTimer);
              this.client.close();
              resolve(json);
            } catch (_) {
              this.fail('接收的数据不是有效的 UTF-8');
            }
          }).catch(() => this.fail('无法校验接收数据'));
          return;
        }
      };
      const absorb = (chunk: Uint8Array): void => {
        if (cursor > 0) incoming = incoming.slice(cursor);
        const merged = new Uint8Array(incoming.length + chunk.length);
        merged.set(incoming, 0);
        merged.set(chunk, incoming.length);
        incoming = merged;
        cursor = 0;
        process();
      };
      this.client.on('message', (info: socket.SocketMessageInfo) => {
        if (this.finished) return;
        this.armTimer();
        absorb(new Uint8Array(info.message));
      });
      this.client.connect({ address: { address: device.host, port: device.port }, timeout: SOCKET_TIMEOUT })
        .then(() => {
          sendChallenge();
        })
        .catch(() => this.fail('无法连接发送设备'));
    });
  }

  static start(device: LanDevice, pinSource: () => string, timeoutMillis: number = SOCKET_TIMEOUT,
    transferMillis: number = TRANSFER_MILLIS, backoffMillis: number[] = PROOF_BACKOFF_MILLIS): LocalBackupReceiver {
    return new LocalBackupReceiver(device, pinSource, timeoutMillis, transferMillis, backoffMillis);
  }

  cancel(): void {
    this.fail('接收已取消');
  }

  private armTimer(): void {
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.fail('接收超时'), this.timeoutMillis);
  }

  private fail(message: string): void {
    if (this.finished) return;
    this.finished = true;
    clearTimeout(this.timer);
    clearTimeout(this.capTimer);
    this.client.close();
    this.rejectOperation?.(new Error(message));
    this.rejectOperation = undefined;
  }
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
