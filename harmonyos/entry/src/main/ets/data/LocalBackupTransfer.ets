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
const MAX_ATTEMPTS = 5;

function securePin(): string {
  const random = cryptoFramework.createRandom();
  let value = 65535;
  while (value >= 60000) {
    const bytes = random.generateRandomSync(2).data;
    value = (bytes[0] << 8) | bytes[1];
  }
  return (value % 10000).toString().padStart(4, '0');
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
  private attempts: number = 0;
  private stopped: boolean = false;
  private activeConnection?: socket.TCPSocketConnection;
  private timer: number = 0;
  private context: common.UIAbilityContext;
  private json: string;
  private onFinished: (success: boolean) => void;
  private idleMillis: number;

  constructor(context: common.UIAbilityContext, json: string, onFinished: (success: boolean) => void,
    idleMillis: number = IDLE_MILLIS) {
    this.context = context;
    this.json = json;
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

  private handle(connection: socket.TCPSocketConnection): void {
    // Count attempts globally and process only one request at a time. Without
    // this guard parallel connections could all validate before the shared
    // five-attempt limit was observed.
    if (this.stopped || this.activeConnection) {
      connection.close();
      return;
    }
    this.activeConnection = connection;
    let request = '';
    let handled = false;
    let connectionTimer = 0;
    const closeConnection = (): void => {
      clearTimeout(connectionTimer);
      connection.close();
      if (this.activeConnection === connection) this.activeConnection = undefined;
    };
    // Idle deadline, re-armed on every chunk: a slow drip can hold the single
    // slot forever under a fixed connect-to-handshake timeout.
    const armIdleTimer = (): void => {
      clearTimeout(connectionTimer);
      connectionTimer = setTimeout(() => {
        if (handled) return;
        handled = true;
        closeConnection();
      }, this.idleMillis);
    };
    armIdleTimer();
    connection.on('message', (info: socket.SocketMessageInfo) => {
      if (this.stopped || handled) return;
      armIdleTimer();
      request += decode(info.message);
      if (request.length > 64) {
        handled = true;
        closeConnection();
        return;
      }
      if (!request.includes('\n')) return;
      handled = true;
      const line = request.slice(0, request.indexOf('\n')).replace('\r', '');
      if (line === `${PROTOCOL} ${this.pin}`) {
        const length = new util.TextEncoder().encodeInto(this.json).length;
        connection.send({ data: `OK ${length}\n`, encoding: 'UTF-8' })
          .then(() => connection.send({ data: this.json, encoding: 'UTF-8' }))
          .then(closeConnection)
          .then(() => this.stop(true))
          .catch(() => {
            closeConnection();
            this.stop(false);
          });
        return;
      }
      // Only a well-formed protocol header with a wrong PIN costs an attempt.
      // Malformed traffic (port scans, stray connections) is dropped silently
      // so it cannot exhaust the legitimate receiver's pairing chances.
      if (line.startsWith(`${PROTOCOL} `)) {
        this.attempts++;
        connection.send({ data: 'ERR PIN\n', encoding: 'UTF-8' }).finally(closeConnection);
        if (this.attempts >= MAX_ATTEMPTS) this.stop(false);
        return;
      }
      closeConnection();
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
        const device: LanDevice = {
          id: `${resolved.serviceName}@${resolved.host.address}:${resolved.port}`,
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
        if (device.name === info.serviceName) this.devices.delete(id);
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

export class LocalBackupReceiver {
  readonly result: Promise<string>;
  private client: socket.TCPSocket;
  private finished: boolean = false;
  private timer: number = 0;
  private timeoutMillis: number;
  private rejectOperation?: (reason: Error) => void;

  private constructor(device: LanDevice, pin: string, timeoutMillis: number = SOCKET_TIMEOUT) {
    if (!/^\d{4}$/.test(pin)) throw new Error('请输入四位数字 PIN');
    if (!device.host || !Number.isInteger(device.port) || device.port < 1 || device.port > 65535) {
      throw new Error('发送设备地址无效');
    }
    this.timeoutMillis = timeoutMillis;
    this.client = socket.constructTCPSocketInstance();
    this.result = new Promise<string>((resolve, reject) => {
      this.rejectOperation = reject;
      const headerBytes: number[] = [];
      let payload: Uint8Array | undefined;
      let payloadOffset = 0;
      // The deadline renews with every arriving chunk: a large backup may need
      // longer than the idle timeout in total, but 15 silent seconds still
      // mean the transfer has stalled.
      this.armTimer();
      this.client.on('message', (info: socket.SocketMessageInfo) => {
        if (this.finished) return;
        this.armTimer();
        const chunk = new Uint8Array(info.message);
        let chunkOffset = 0;
        if (!payload) {
          while (chunkOffset < chunk.length && chunk[chunkOffset] !== 10) {
            headerBytes.push(chunk[chunkOffset++]);
            if (headerBytes.length > 64) { this.fail('发送方响应头过长'); return; }
          }
          if (chunkOffset >= chunk.length) return;
          chunkOffset++;
          const header = new util.TextDecoder('utf-8').decodeToString(new Uint8Array(headerBytes)).replace('\r', '');
          if (header === 'ERR PIN') { this.fail('PIN 不正确'); return; }
          if (!header.startsWith('OK ')) { this.fail('发送方返回了无效响应'); return; }
          const size = Number.parseInt(header.slice(3));
          if (!Number.isInteger(size) || size < 1 || size > BackupService.MAX_BYTES) {
            this.fail('接收的备份文件大小异常');
            return;
          }
          payload = new Uint8Array(size);
        }
        if (!payload) return;
        const remaining = payload.length - payloadOffset;
        const available = chunk.length - chunkOffset;
        if (available > remaining) { this.fail('发送方返回了额外数据'); return; }
        payload.set(chunk.subarray(chunkOffset), payloadOffset);
        payloadOffset += available;
        if (payloadOffset !== payload.length) return;
        try {
          const decoder = util.TextDecoder.create('utf-8', { fatal: true, ignoreBOM: true });
          const json = decoder.decodeToString(payload);
          this.finished = true;
          clearTimeout(this.timer);
          this.client.close();
          resolve(json);
        } catch (_) {
          this.fail('接收的数据不是有效的 UTF-8');
        }
      });
      this.client.connect({ address: { address: device.host, port: device.port }, timeout: SOCKET_TIMEOUT })
        .then(() => this.client.send({ data: `${PROTOCOL} ${pin}\n`, encoding: 'UTF-8' }))
        .catch(() => this.fail('无法连接发送设备'));
    });
  }

  static start(device: LanDevice, pin: string, timeoutMillis: number = SOCKET_TIMEOUT): LocalBackupReceiver {
    return new LocalBackupReceiver(device, pin, timeoutMillis);
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
    this.client.close();
    this.rejectOperation?.(new Error(message));
    this.rejectOperation = undefined;
  }
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
