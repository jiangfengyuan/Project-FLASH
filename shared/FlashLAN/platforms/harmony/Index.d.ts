// Copyright (c) 2026 Fengyuan Jiang. SPDX-License-Identifier: MPL-2.0
export const create: (role: number, now: number, remaining: number) => number;
export const action: (id: number, operation: number, now: number, parameter: number) => number;
export const input: (id: number, operation: number, bytes: ArrayBuffer, now: number) => number;
export const output: (id: number, now: number) => ArrayBuffer | null;
export const received: (id: number) => ArrayBuffer;
export const sas: (id: number) => number[];
