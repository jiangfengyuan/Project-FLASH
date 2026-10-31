# Independent review — baseline (Phase 1)

Base: `e9a0aa6` (head of PR #2 `feat/ios-native`, OPEN, 37 commits, not merged). Reviewer: Claude. Status of Codex branch `codex/security-performance-hardening` at 2026-10-24: no commits, clean worktree — nothing under review yet.

## Baseline finding B-1 (reproduced): offline PIN recovery from a passive capture

- Spec: `docs/contracts/lan-handshake-v1.1.md`; code: `LanHandshake.proof/payloadMAC` in `shared/FlashKit/.../LocalBackupTransfer.swift`.
- `proof = HMAC-SHA256(key = PIN ASCII, "flash-aero-handshake:" || nonce)[0:16]`, payload MAC keyed by the same PIN. Nonce and proof cross the LAN in clear.
- Reproduction: `python3 -I scripts/review/offline_pin_crack.py --selftest` (uses the vector committed in `LocalBackupTransferTests.swift:27`).
- Result (Python 3.13.7, single core, Apple host, not a tuned cracker): PIN 123456 recovered in 0.16 s; worst case PIN 999999 recovered in 1.23 s. With the PIN the attacker verifies the payload MAC and can compute valid MACs for forged payloads.
- Not mitigated by: the 5-attempt limit and 1/2/4/8 s back-off (per-connection, enforced by the honest receiver; irrelevant to offline attack); 60 s session window; 6-digit PIN.
- Also: payload is plaintext on the wire (no confidentiality) — the spec defers this to a future PAKE.
- Acceptance bar for the hardening work: a captured transcript (all bytes both directions) must not allow offline PIN verification. `offline_pin_crack.py` must exit 1 / have nothing to run against on the new protocol. A PAKE (SPAKE2/CPace/OPAQUE) or equivalent reviewed construction with session-key-derived AEAD satisfies this; HMAC-keyed-by-PIN in any form does not.

## Environment
Xcode-beta present; Node v26.2.0; Python 3.13.7; Android SDK present (`adb` not on PATH); DevEco Studio present; no HarmonyOS or Android device evidence (per `docs/contracts/acceptance.md`).
