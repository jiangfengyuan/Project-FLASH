import { describe, it, expect } from 'vitest';

function versionToCode(version: string): number {
  const [major, minor, patch] = version.split('.').map(Number);
  return major * 10000 + minor * 100 + patch;
}

describe('versionToCode', () => {
  it('maps semantic version to integer code', () => {
    expect(versionToCode('0.1.0')).toBe(100);
    expect(versionToCode('1.2.3')).toBe(10203);
    expect(versionToCode('2.11.7')).toBe(21107);
  });
});
