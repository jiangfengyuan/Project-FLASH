// Actual native N-API bridge + actual ArkTS adapter, synthetic fragmented I/O.
// Run via shared/FlashLAN/platforms/harmony/test-host.py. Never fake crypto success.
const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');
const addon = process.env.FLASH_LAN_NATIVE_NODE;
const fixture = JSON.stringify({ version: 'flash-backup-v2', exportedAt: '2026-11-01T00:00:00.000Z', appVersion: 'test',
  notes: 'synthetic fragmentation '.repeat(700), schemas: {logs:2, emotions:2, tasks:2}, data: {logs:[], emotions:[], tasks:[]} });
class Pipe {
  constructor() { this.handlers = {}; this.closed = false; }
  on(event, cb) { this.handlers[event] = cb; }
  off(event) { delete this.handlers[event]; }
  async send({ data }) {
    const bytes = new Uint8Array(data); let offset = 0, index = 0;
    if (this.dropReceipt && bytes[4] === 0x22) return;
    while (offset < bytes.length) {
      if (this.closed || this.peer.closed) throw Error('Closed socket');
      const end = Math.min(bytes.length, offset + [1, 2, 7, 31][index++ % 4]);
      this.peer.handlers.message?.({message:bytes.slice(offset,end).buffer});
      offset = end;
      await Promise.resolve();
    }
  }
  async close() { this.closed = true; queueMicrotask(() => this.peer.handlers.close?.()); }
}
async function pair(json) {
  const core = require(addon);
  const load = createLoader({'libflash_lan.so':core});
  const { SecureLanConnection } = load('data/SecureLanConnection');
  const left = new Pipe(), right = new Pipe(); left.peer = right; right.peer = left;
  const state = {codes:[], snapshots:0, sent:false, received:undefined, failures:0};
  const sender = new SecureLanConnection(left,true,120000,async()=>{state.snapshots++; return json;},{
    state:(s,code)=>{if(s===6) state.codes[0]=code;}, completed:()=>{state.sent=true;}, failed:()=>{state.failures++;}});
  const receiver = new SecureLanConnection(right,false,120000,async()=>{throw Error('Receiver exported');},{
    state:(s,code)=>{if(s===6) state.codes[1]=code;}, completed:json=>{state.received=json;}, failed:()=>{state.failures++;}});
  // Install receiver before its first Hello write reaches the sender.
  sender.start(); receiver.start();
  return {state,sender,receiver,left,right};
}
async function wait(condition) {
  const end=performance.now()+5000;
  while(!condition()) {if(performance.now()>=end) throw Error('Native adapter test timeout'); await new Promise(r=>setTimeout(r,5));}
}
test('N-API and ArkTS: fragmented records and close before ACK write completion', {skip:!addon}, async()=>{
  const {state,sender,receiver}=await pair(fixture);
  try {
    await wait(()=>state.codes.length===2);
    assert.deepEqual(state.codes[0],state.codes[1]); assert.equal(state.snapshots,0);
    sender.confirm(); await new Promise(r=>setTimeout(r,50)); assert.equal(state.snapshots,0);
    receiver.confirm(); await wait(()=>state.sent&&state.received!==undefined);
    assert.equal(state.received,fixture); assert.equal(state.snapshots,1); assert.equal(state.failures,0);
  } finally {sender.cancel();receiver.cancel();}
});
test('N-API and ArkTS: strict rejection produces no receipt or preview', {skip:!addon}, async()=>{
  const {state,sender,receiver}=await pair('{}');
  try {
    await wait(()=>state.codes.length===2); sender.confirm();receiver.confirm();
    await wait(()=>state.failures>=2); assert.equal(state.received,undefined);assert.equal(state.sent,false);
  } finally {sender.cancel();receiver.cancel();}
});

test('N-API and ArkTS: lost receipt never gives sender success', {skip:!addon}, async()=>{
  const {state,sender,receiver,right}=await pair(fixture); right.dropReceipt=true;
  try {
    await wait(()=>state.codes.length===2); sender.confirm();receiver.confirm();
    await wait(()=>state.failures>=1&&state.received!==undefined);
    assert.equal(state.sent,false);assert.equal(state.received,fixture);
  } finally {sender.cancel();receiver.cancel();}
});
test('N-API and ArkTS: cancellation during code comparison never exports', {skip:!addon}, async()=>{
  const {state,sender,receiver}=await pair(fixture);
  try {
    await wait(()=>state.codes.length===2); receiver.cancel();
    await wait(()=>state.failures>=1); assert.equal(state.snapshots,0);assert.equal(state.sent,false);assert.equal(state.received,undefined);
  } finally {sender.cancel();receiver.cancel();}
});
