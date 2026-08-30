import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { mdns, socket } from '@kit.NetworkKit';
import { BackupService } from './BackupService';

const SERVICE_TYPE = '_flashbackup._tcp';
const PROTOCOL = 'FLASH-AERO/1';
const SESSION_MILLIS = 60000;
const SOCKET_TIMEOUT = 15000;
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
  private timer: number = 0;
  private context: common.UIAbilityContext;
  private json: string;
  private onFinished: (success: boolean) => void;

  constructor(context: common.UIAbilityContext, json: string, onFinished: (success: boolean) => void) {
    this.context = context;
    this.json = json;
    this.onFinished = onFinished;
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
    let request = '';
    let handled = false;
    connection.on('message', (info: socket.SocketMessageInfo) => {
      if (this.stopped || handled) return;
      request += decode(info.message);
      if (request.length > 64) {
        handled = true;
        connection.close();
        return;
      }
      if (!request.includes('\n')) return;
      handled = true;
      const line = request.slice(0, request.indexOf('\n')).replace('\r', '');
      if (line !== `${PROTOCOL} ${this.pin}`) {
        this.attempts++;
        connection.send({ data: 'ERR PIN\n', encoding: 'UTF-8' }).finally(() => connection.close());
        if (this.attempts >= MAX_ATTEMPTS) this.stop(false);
        return;
      }
      const length = new util.TextEncoder().encodeInto(this.json).length;
      connection.send({ data: `OK ${length}\n`, encoding: 'UTF-8' })
        .then(() => connection.send({ data: this.json, encoding: 'UTF-8' }))
        .then(() => connection.close())
        .then(() => this.stop(true))
        .catch(() => {
          connection.close();
          this.stop(false);
        });
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
  static receive(device: LanDevice, pin: string): Promise<string> {
    if (!/^\d{4}$/.test(pin)) return Promise.reject(new Error('请输入四位数字 PIN'));
    if (!device.host || !Number.isInteger(device.port) || device.port < 1 || device.port > 65535) {
      return Promise.reject(new Error('发送设备地址无效'));
    }
    return new Promise<string>((resolve, reject) => {
      const client = socket.constructTCPSocketInstance();
      const headerBytes: number[] = [];
      let payload: Uint8Array | undefined;
      let payloadOffset = 0;
      let finished = false;
      const fail = (message: string): void => {
        if (finished) return;
        finished = true;
        clearTimeout(timer);
        client.close();
        reject(new Error(message));
      };
      const timer = setTimeout(() => fail('接收超时'), SOCKET_TIMEOUT);
      client.on('message', (info: socket.SocketMessageInfo) => {
        const chunk = new Uint8Array(info.message);
        let chunkOffset = 0;
        if (!payload) {
          while (chunkOffset < chunk.length && chunk[chunkOffset] !== 10) {
            headerBytes.push(chunk[chunkOffset++]);
            if (headerBytes.length > 64) { fail('发送方响应头过长'); return; }
          }
          if (chunkOffset >= chunk.length) return;
          chunkOffset++;
          const header = new util.TextDecoder('utf-8').decodeToString(new Uint8Array(headerBytes)).replace('\r', '');
          if (header === 'ERR PIN') { fail('PIN 不正确'); return; }
          if (!header.startsWith('OK ')) { fail('发送方返回了无效响应'); return; }
          const size = Number.parseInt(header.slice(3));
          if (!Number.isInteger(size) || size < 1 || size > BackupService.MAX_BYTES) {
            fail('接收的备份文件大小异常');
            return;
          }
          payload = new Uint8Array(size);
        }
        if (!payload) return;
        const remaining = payload.length - payloadOffset;
        const available = chunk.length - chunkOffset;
        if (available > remaining) { fail('发送方返回了额外数据'); return; }
        payload.set(chunk.subarray(chunkOffset), payloadOffset);
        payloadOffset += available;
        if (payloadOffset !== payload.length) return;
        try {
          const decoder = util.TextDecoder.create('utf-8', { fatal: true, ignoreBOM: true });
          const json = decoder.decodeToString(payload);
          finished = true;
          clearTimeout(timer);
          client.close();
          resolve(json);
        } catch (_) {
          fail('接收的数据不是有效的 UTF-8');
        }
      });
      client.connect({ address: { address: device.host, port: device.port }, timeout: SOCKET_TIMEOUT })
        .then(() => client.send({ data: `${PROTOCOL} ${pin}\n`, encoding: 'UTF-8' }))
        .catch(() => fail('无法连接发送设备'));
    });
  }
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
