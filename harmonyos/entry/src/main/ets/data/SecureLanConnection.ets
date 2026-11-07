// Copyright (c) 2026 Fengyuan Jiang · MPL-2.0
import { socket } from '@kit.NetworkKit';
import { systemDateTime } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import * as lan from 'libflash_lan.so';
import { BackupImport, BackupService } from './BackupService';

export function lanNow(): number { return systemDateTime.getUptime(systemDateTime.TimeType.STARTUP); }
export interface LanConnectionEvents {
  state: (state: number, code: number[]) => void;
  completed: (backup?: BackupImport) => void;
  failed: () => void;
}
export class SecureLanConnection {
  private handle: number;
  private closed: boolean = false;
  private pumping: boolean = false;
  private again: boolean = false;
  private timer: number = 0;
  private writingAt: number = 0;
  private previous: number = 0;
  private validated?: BackupImport;
  private stream: socket.TCPSocket | socket.TCPSocketConnection;
  private sender: boolean;
  private snapshot: () => Promise<string>;
  private events: LanConnectionEvents;
  constructor(stream: socket.TCPSocket | socket.TCPSocketConnection,
    sender: boolean, remaining: number, snapshot: () => Promise<string>,
    events: LanConnectionEvents) {
    this.stream = stream; this.sender = sender; this.snapshot = snapshot; this.events = events;
    this.handle = lan.create(sender ? 1 : 2, lanNow(), remaining);
    if (this.handle <= 0) throw new Error('LAN core unavailable');
  }
  start(): void {
    this.stream.on('message', (info: socket.SocketMessageInfo) => {
      if (this.closed) return;
      try {
        // Feed synchronously into the bounded native parser. No Promise chain
        // may retain arbitrarily many fragmented network buffers during a write.
        this.check(lan.input(this.handle, 1, info.message, lanNow()));
        this.pump();
      } catch (_) { this.fail(); }
    });
    this.stream.on('close', () => {
      if (this.closed) return;
      // The sender may close immediately after authenticating our receipt,
      // before the platform resolves the pending send Promise. EOF grants no
      // success: wait for that write result (or the write watchdog) instead.
      try { if (this.writingAt > 0 && lan.action(this.handle, 1, lanNow(), 0) === 13) return; }
      catch (_) {}
      this.fail();
    });
    this.stream.on('error', () => { if (!this.closed) this.fail(); });
    this.timer = setInterval(() => {
      if (this.closed) return;
      try {
        if (this.writingAt > 0 && lanNow() - this.writingAt >= 10000) throw new Error('LAN write timeout');
        this.check(lan.action(this.handle, 3, lanNow(), 0));
      } catch (_) { this.fail(); }
    }, 250);
    this.pump();
  }
  private check(result: number): number {
    if (result < 0) throw new Error('LAN native failure');
    return result;
  }
  confirm(): void {
    if (this.closed) return;
    try { this.check(lan.action(this.handle, 5, lanNow(), 0)); this.pump(); }
    catch (_) { this.fail(); }
  }
  private async pump(): Promise<void> {
    if (this.closed) return;
    if (this.pumping) { this.again = true; return; }
    this.pumping = true;
    try {
      do {
        this.again = false;
        const state = this.check(lan.action(this.handle, 1, lanNow(), 0));
        if (state === 14) throw new Error('LAN native failure');
        if (state !== this.previous) {
          this.previous = state;
          this.events.state(state, state === 6 ? lan.sas(this.handle) : []);
        }
        if (state === 8) {
          const json = await this.snapshot();
          if (this.closed) return;
          const bytes = new util.TextEncoder().encodeInto(json);
          try { this.check(lan.input(this.handle, 2, bytes.buffer as ArrayBuffer, lanNow())); }
          finally { bytes.fill(0); }
        } else if (state === 11) {
          const buffer: ArrayBuffer = lan.received(this.handle);
          const bytes = new Uint8Array(buffer);
          try {
            // UTF-8/BOM were checked by the core before this platform decoder.
            const json = new util.TextDecoder('utf-8').decodeToString(bytes);
            const backup = BackupService.parseStrict(json);
            this.check(lan.action(this.handle, 8, lanNow(), 1));
            this.validated = backup;
          } finally { bytes.fill(0); }
        }
        const packet: ArrayBuffer | null = lan.output(this.handle, lanNow());
        if (packet !== null) {
          this.writingAt = lanNow();
          await this.stream.send({ data: packet });
          if (this.closed) return;
          this.writingAt = 0;
          this.check(lan.action(this.handle, 4, lanNow(), 0));
          this.again = true;
        } else if (this.check(lan.action(this.handle, 1, lanNow(), 0)) === 13) {
          const backup = this.validated;
          if (!this.sender && backup === undefined) throw new Error('LAN backup missing');
          this.cancel(); this.events.completed(backup); return;
        }
      } while (this.again && !this.closed);
    } catch (_) { this.fail(); }
    finally { this.pumping = false; }
  }
  private fail(): void { if (!this.closed) { this.cancel(); this.events.failed(); } }
  cancel(): void {
    if (this.closed) return;
    this.closed = true;
    clearInterval(this.timer); this.timer = 0;
    this.stream.off('message'); this.stream.off('close'); this.stream.off('error');
    this.stream.close().catch(() => {});
    lan.action(this.handle, 9, lanNow(), 0);
    this.handle = 0; this.validated = undefined;
  }
}
