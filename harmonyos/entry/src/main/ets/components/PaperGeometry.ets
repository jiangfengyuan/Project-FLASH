// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

/** 种子确定的伪随机序列（FNV-1a 散列 + SplitMix64），与 iOS / Android 同算法，只用于装饰形状。 */
const MASK: bigint = (BigInt(1) << BigInt(64)) - BigInt(1);
const FNV_OFFSET: bigint = BigInt('0xcbf29ce484222325');
const FNV_PRIME: bigint = BigInt('0x100000001b3');
const GOLDEN: bigint = BigInt('0x9E3779B97F4A7C15');
const MIX1: bigint = BigInt('0xBF58476D1CE4E5B9');
const MIX2: bigint = BigInt('0x94D049BB133111EB');
const TWO_53: number = Math.pow(2, 53);

function utf8Bytes(text: string): number[] {
  const bytes: number[] = [];
  for (const symbol of text) {
    const code = symbol.codePointAt(0) as number;
    if (code < 0x80) bytes.push(code);
    else if (code < 0x800) bytes.push(0xc0 | (code >> 6), 0x80 | (code & 63));
    else if (code < 0x10000) bytes.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 63), 0x80 | (code & 63));
    else bytes.push(0xf0 | (code >> 18), 0x80 | ((code >> 12) & 63), 0x80 | ((code >> 6) & 63), 0x80 | (code & 63));
  }
  return bytes;
}

export class SeededJitter {
  private state: bigint;

  constructor(seed: string) {
    let hash = FNV_OFFSET;
    utf8Bytes(seed).forEach((byte: number) => {
      hash = hash ^ BigInt(byte);
      hash = (hash * FNV_PRIME) & MASK;
    });
    this.state = hash;
  }

  /** [-1, 1] 区间的下一个值 */
  next(): number {
    this.state = (this.state + GOLDEN) & MASK;
    let z = this.state;
    z = ((z ^ (z >> BigInt(30))) * MIX1) & MASK;
    z = ((z ^ (z >> BigInt(27))) * MIX2) & MASK;
    z = z ^ (z >> BigInt(31));
    return Number(z >> BigInt(11)) / TWO_53 * 2 - 1;
  }
}

function fmt(value: number): string {
  return value.toFixed(2);
}

/** 毛边线（开放路径，SVG 命令，单位 px） */
export function tornLineCommands(seed: string, width: number, height: number, amplitude: number, step: number): string {
  if (width <= 0) return '';
  const jitter = new SeededJitter(seed);
  const midY = height / 2;
  let x = 0;
  let out = `M${fmt(x)} ${fmt(midY + jitter.next() * amplitude)}`;
  while (x < width) {
    x = Math.min(width, x + step * (0.7 + (jitter.next() + 1) * 0.3));
    out += ` L${fmt(x)} ${fmt(midY + jitter.next() * amplitude)}`;
  }
  return out;
}

/** 手绘线：低频起伏的二次贝塞尔 */
export function handLineCommands(seed: string, width: number, height: number, amplitude: number, segmentLength: number): string {
  if (width <= 0) return '';
  const jitter = new SeededJitter(seed);
  const segments = Math.max(2, Math.floor(width / segmentLength));
  const midY = height / 2;
  const startInset = Math.abs(jitter.next()) * 0.015;
  const endInset = Math.abs(jitter.next()) * 0.02;
  let px = startInset * width;
  let py = midY + jitter.next() * amplitude;
  let out = `M${fmt(px)} ${fmt(py)}`;
  for (let index = 1; index <= segments; index++) {
    const t = startInset + (1 - startInset - endInset) * index / segments;
    const nx = t * width;
    const ny = midY + jitter.next() * amplitude;
    const cy = (py + ny) / 2 + jitter.next() * amplitude;
    out += ` Q${fmt((px + nx) / 2)} ${fmt(cy)} ${fmt(nx)} ${fmt(ny)}`;
    px = nx;
    py = ny;
  }
  return out;
}

/** 撕开的底边：盖在卡片底部的一条页面色毛边（闭合路径，单位 px） */
export function tornEdgeMaskCommands(seed: string, width: number, height: number, amplitude: number, step: number): string {
  if (width <= 0) return '';
  const jitter = new SeededJitter(seed);
  const base = height - amplitude - 1;
  let x = 0;
  let out = `M0 ${fmt(base + jitter.next() * amplitude)}`;
  while (x < width) {
    x = Math.min(width, x + step * (0.7 + (jitter.next() + 1) * 0.3));
    out += ` L${fmt(x)} ${fmt(base + jitter.next() * amplitude)}`;
  }
  out += ` L${fmt(width)} ${fmt(height)} L0 ${fmt(height)} Z`;
  return out;
}

/** 手绘圈：一笔略不圆、收笔搭头的椭圆（单位 px） */
export function handCircleCommands(seed: string, size: number, wobble: number): string {
  const jitter = new SeededJitter(seed);
  const radius = size / 2;
  const start = jitter.next() * Math.PI;
  const sweep = 2 * Math.PI + Math.PI / 10;
  const phase = jitter.next() * Math.PI;
  const steps = 48;
  let out = '';
  for (let step = 0; step <= steps; step++) {
    const progress = step / steps;
    const angle = start + sweep * progress;
    const scale = 1 + wobble * Math.sin(angle * 2 + phase) + wobble * 0.5 * progress;
    const x = radius + Math.cos(angle) * radius * scale;
    const y = radius + Math.sin(angle) * radius * scale;
    out += `${step === 0 ? 'M' : ' L'}${fmt(x)} ${fmt(y)}`;
  }
  return out;
}

/** 便签底页的错位：种子决定角度与横向偏移 */
export function stickyOffset(seed: string): number[] {
  const jitter = new SeededJitter(seed);
  const angle = jitter.next() * 1.4;
  return [angle === 0 ? 1 : angle, jitter.next() * 3];
}
