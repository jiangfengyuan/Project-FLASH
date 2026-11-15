// Copyright (c) 2026 Fengyuan Jiang · MPL-2.0
import { BackupImport } from './BackupService';
import { common } from '@kit.AbilityKit';
import { mdns, socket } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { SecureLanConnection, LanConnectionEvents, lanNow } from './SecureLanConnection';

export const LAN_ENABLED: boolean = false;
export const LAN_UNAVAILABLE_MESSAGE: string = '局域网传输暂时停用：安全 LAN v2 正在验收。请使用“导出备份”或“系统分享”传输 JSON 文件；旧版 LAN 不再支持。';
const SERVICE_TYPE: string = '_flashbackup2._tcp';
export enum LanPhase { IDLE, WAITING, DISCOVERING, HANDSHAKE, CONFIRMING, WAITING_FOR_PEER, TRANSFERRING, VERIFYING, COMPLETED, FAILED }
export class LanDevice { id: string = ''; name: string = ''; host: string = ''; port: number = 0; }
export interface LanEvents {
  phase: (phase: LanPhase, code: number[]) => void;
  devices: (devices: LanDevice[]) => void;
  sent: () => void;
  received: (backup: BackupImport) => void;
  failed: (message: string) => void;
}
export class SecureLanTransfer {
  private static current?: SecureLanTransfer;
  static stopForBackground(): void { SecureLanTransfer.current?.cancel(); }
  private epoch: number = 0;
  private attempt: number = 0;
  private end: number = 0;
  private retryAfter: number = 0;
  private failures: number = 0;
  private sending: boolean = false;
  private connecting: boolean = false;
  private timer: number = 0;
  private server?: socket.TCPSocketServer;
  private advertised?: mdns.LocalServiceInfo;
  private discovery?: mdns.DiscoveryService;
  private active?: SecureLanConnection;
  private pending?: socket.TCPSocket;
  private found: Map<string, LanDevice> = new Map<string, LanDevice>();
  private resolving: number = 0;
  private snapshot?: () => Promise<string>;
  private context: common.UIAbilityContext;
  private events: LanEvents;
  private allowed: boolean;
  constructor(context: common.UIAbilityContext, events: LanEvents, allowed: boolean = LAN_ENABLED) {
    this.context = context; this.events = events; this.allowed = allowed;
  }
  private begin(sender: boolean): number {
    this.cancel();
    if (!this.allowed) { this.events.failed(LAN_UNAVAILABLE_MESSAGE); return -1; }
    SecureLanTransfer.current = this;
    this.sending = sender; this.end = lanNow() + 120000; this.failures = 0; this.retryAfter = 0;
    const epoch = this.epoch;
    this.events.phase(sender ? LanPhase.WAITING : LanPhase.DISCOVERING, []);
    this.timer = setInterval(() => {
      if (epoch !== this.epoch) return;
      if (!this.connecting && lanNow() >= this.end) this.fail('本次开启已超时，请重新发起');
    }, 250);
    return epoch;
  }
  async send(snapshot: () => Promise<string>): Promise<void> {
    const epoch = this.begin(true); if (epoch < 0) return;
    this.snapshot = snapshot;
    const server = socket.constructTCPSocketServerInstance(); this.server = server;
    server.on('connect', (connection: socket.TCPSocketConnection) => {
      const now = lanNow();
      if (epoch !== this.epoch || this.connecting || now >= this.end || now < this.retryAfter || this.failures >= 3) {
        connection.close().catch(() => {}); return;
      }
      this.connecting = true; this.attach(connection, epoch);
    });
    server.on('error', () => { if (epoch === this.epoch) this.fail('无法开启本地网络服务'); });
    try {
      await server.listen({ address: '0.0.0.0', family: 1, port: 0 });
      if (epoch !== this.epoch) { server.close().catch(() => {}); return; }
      const address = await server.getLocalAddress();
      if (epoch !== this.epoch) return;
      const info: mdns.LocalServiceInfo = { serviceType: SERVICE_TYPE,
        serviceName: 'Flash-' + util.generateRandomUUID().slice(0, 8), port: address.port };
      const registered = await mdns.addLocalService(this.context, info);
      if (epoch !== this.epoch) { mdns.removeLocalService(this.context, registered).catch(() => {}); return; }
      this.advertised = registered;
    } catch (_) { if (epoch === this.epoch) this.fail('无法开启本地网络服务，请检查权限'); }
  }
  receive(): void {
    const epoch = this.begin(false); if (epoch < 0) return;
    try {
      const discovery = mdns.createDiscoveryService(this.context, SERVICE_TYPE); this.discovery = discovery;
      discovery.on('discoveryStart', (info: mdns.DiscoveryEventInfo) => {
        if (epoch === this.epoch && info.errorCode !== undefined) this.fail('无法发现设备，请检查网络权限');
      });
      discovery.on('serviceFound', (info: mdns.LocalServiceInfo) => {
        if (epoch !== this.epoch || this.resolving + this.found.size >= 64) return;
        this.resolving++;
        mdns.resolveLocalService(this.context, info).then((resolved: mdns.LocalServiceInfo) => {
          if (epoch !== this.epoch || !resolved.host || resolved.port === undefined || resolved.port < 1 || resolved.port > 65535) return;
          const device: LanDevice = { id: `${resolved.host.address}:${resolved.port}`,
            name: resolved.serviceName.slice(0, 80), host: resolved.host.address, port: resolved.port };
          this.found.set(device.id, device); this.events.devices(Array.from(this.found.values()));
        }).catch(() => {}).finally(() => { if (epoch === this.epoch) this.resolving--; });
      });
      discovery.on('serviceLost', (info: mdns.LocalServiceInfo) => {
        if (epoch !== this.epoch) return;
        this.found.forEach((device: LanDevice, id: string) => {
          if (device.name === info.serviceName.slice(0, 80) && (!info.host || device.host === info.host.address)) this.found.delete(id);
        });
        this.events.devices(Array.from(this.found.values()));
      });
      discovery.startSearchingMDNS();
    } catch (_) { this.fail('无法发现设备，请检查网络权限'); }
  }
  async connect(device: LanDevice): Promise<void> {
    const now = lanNow();
    if (this.sending || this.connecting || !this.found.has(device.id) || now >= this.end || now < this.retryAfter) return;
    this.connecting = true; const epoch = this.epoch; const attempt = ++this.attempt;
    const client = socket.constructTCPSocketInstance(); this.pending = client;
    this.events.phase(LanPhase.HANDSHAKE, []);
    const timeout = setTimeout(() => {
      if (epoch === this.epoch && attempt === this.attempt && !this.active) {
        client.close().catch(() => {}); this.connectionFailed();
      }
    }, Math.min(10000, this.end - now));
    try {
      await client.connect({ address: { address: device.host, family: device.host.indexOf(':') >= 0 ? 2 : 1, port: device.port },
        timeout: Math.min(10000, this.end - now) });
      if (epoch !== this.epoch || attempt !== this.attempt) { client.close().catch(() => {}); return; }
      clearTimeout(timeout); this.pending = undefined; this.attach(client, epoch);
    } catch (_) { if (epoch === this.epoch && attempt === this.attempt) this.connectionFailed(); }
    finally { clearTimeout(timeout); }
  }
  private attach(stream: socket.TCPSocket | socket.TCPSocketConnection, epoch: number): void {
    const attempt = ++this.attempt;
    const events: LanConnectionEvents = {
      state: (state: number, code: number[]) => {
        if (epoch !== this.epoch || attempt !== this.attempt) return;
        const phase = state === 6 ? LanPhase.CONFIRMING : state === 7 ? LanPhase.WAITING_FOR_PEER :
          state === 11 ? LanPhase.VERIFYING : state >= 8 && state <= 12 ? LanPhase.TRANSFERRING : LanPhase.HANDSHAKE;
        this.events.phase(phase, code);
      },
      completed: (backup?: BackupImport) => {
        if (epoch !== this.epoch || attempt !== this.attempt) return;
        const sender = this.sending; this.cancel(); this.events.phase(LanPhase.COMPLETED, []);
        if (sender) this.events.sent(); else if (backup !== undefined) this.events.received(backup);
      },
      failed: () => { if (epoch === this.epoch && attempt === this.attempt) this.connectionFailed(); }
    };
    try {
      const remaining = this.end - lanNow();
      if (remaining <= 0) throw new Error('LAN opening expired');
      this.active = new SecureLanConnection(stream, this.sending, remaining,
        async (): Promise<string> => { if (!this.snapshot) throw new Error('LAN snapshot unavailable'); return this.snapshot(); }, events);
      this.active.start();
    } catch (_) { stream.close().catch(() => {}); this.connectionFailed(); }
  }
  confirm(): void { this.active?.confirm(); }
  reject(): void { this.fail('短码不一致，已取消本次传输'); }
  private connectionFailed(): void {
    this.attempt++; this.active?.cancel(); this.active = undefined;
    this.pending?.close().catch(() => {}); this.pending = undefined;
    this.connecting = false; this.failures++;
    if (this.failures >= 3 || lanNow() >= this.end) { this.fail('安全传输未完成，请重新发起；收到备份后仍需确认导入'); return; }
    this.retryAfter = lanNow() + this.failures * 1000;
    this.events.phase(this.sending ? LanPhase.WAITING : LanPhase.DISCOVERING, []);
  }
  private fail(message: string): void { this.cancel(); this.events.phase(LanPhase.FAILED, []); this.events.failed(message); }
  cancel(): void {
    this.epoch++; this.attempt++; clearInterval(this.timer); this.timer = 0;
    this.active?.cancel(); this.active = undefined;
    this.pending?.close().catch(() => {}); this.pending = undefined;
    if (this.server) { this.server.off('connect'); this.server.off('error'); this.server.close().catch(() => {}); this.server = undefined; }
    if (this.advertised) { mdns.removeLocalService(this.context, this.advertised).catch(() => {}); this.advertised = undefined; }
    if (this.discovery) {
      this.discovery.off('serviceFound'); this.discovery.off('serviceLost');
      this.discovery.off('discoveryStart');
      try { this.discovery.stopSearchingMDNS(); } catch (_) {}
      this.discovery = undefined;
    }
    this.snapshot = undefined; this.found.clear(); this.resolving = 0; this.connecting = false;
    this.events.devices([]); this.events.phase(LanPhase.IDLE, []);
    if (SecureLanTransfer.current === this) SecureLanTransfer.current = undefined;
  }
}
