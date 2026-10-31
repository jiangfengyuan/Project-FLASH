# FLASH-LAN/2 — byte-level review draft

Status: **candidate for isolated implementation; not release-approved**. On
2026-11-01 the owner requested Codex self-review instead of an external reviewer.
See [self-review and limits](../hardening/lan-v2-self-review-20261101.md).
This does not replace the disabled legacy adapter or waive the vector, application
integration and physical-device acceptance gates.

## Roles, scope and trust

S is the backup sender and TCP listener; R is the receiver and TCP initiator.
Only an explicit send/receive action starts discovery. Service type is
`_flashbackup2._tcp`; use a fresh random label and no persistent identifiers in
discovery. Discovery names/IP addresses are untrusted candidate-selection hints.
The two users must compare the current codes over an impersonation-resistant
channel (normally both devices in front of them); neither a service name nor
clicking confirmation on only one device establishes identity.

No remembered pairing, resumption, 0-RTT, partial resume, compression, automatic
import, synchronization or legacy fallback. Each connection uses fresh ephemeral
keys and 32-byte OS-random nonces. An old/unknown protocol fails closed. The
existing `flash-backup-v2` schema and strict import/preview/commit semantics stay
unchanged.

The commitment ordering is adapted from [Matrix SAS v1.16](https://spec.matrix.org/v1.16/client-server-api/#short-authentication-string-sas-verification).
Flash has no Matrix device identity keys, server or signed-key verification.
Its transcript confirmation and record layer below are a new composition requiring
review; Matrix's analysis and vodozemac's audit do not automatically cover Flash.

## Binary encoding

All integers are unsigned, big endian. No optional or repeated fields, JSON,
base64, text normalization or trailing bytes in handshake messages. A frame is
`u32 body_length || body`. Reject a wrong length/type/order before interpreting
fields or allocating an attacker-sized buffer. Prefix and body are both part of
the transcript. Reads may split or combine frames at any byte boundary.

| Frame | Type byte | Remaining body, in order |
| --- | --- | --- |
| R hello | 01 | ASCII `FLASH-LAN/2` (11 bytes), version u16=2, suite u16=1, role u8=2, random nonce[32], max_bytes u64, log/emotion/task schema masks u8 each |
| S hello | 02 | same encoding; role u8=1 |
| S commitment | 03 | commitment[32] |
| R public key | 04 | raw X25519 public key[32] |
| S public key | 05 | raw X25519 public key[32] |
| Local acceptance | 06 | confirmation MAC[32] |

Hello body length is 60 including type; all other handshake body lengths are 33.
Suite 1 fixes vodozemac X25519/SAS, HKDF-SHA256, HMAC-SHA256 and libsodium
XChaCha20-Poly1305; negotiation is not an algorithm list. Unknown versions/suites
are rejected. `max_bytes` must be 1..52,428,800; the connection cap is the lower
offer. Each schema mask must be 03 (support section schema 1 and 2); actual
received content still goes through the strict backup parser. This draft does
not specify a legacy schema fallback or rewrite exported fields.

## Commitment, SAS and acceptance

Sequence is exactly R hello, S hello, S commitment, R key, S key; the two final
acceptance frames may cross. S fixes its ephemeral key before sending commitment.
R does not disclose its key until commitment is received. S does not disclose its
key until R's key is received. Public keys are validated by the library, including
noncontributory/all-zero shared-secret rejection; never add a permissive fallback.

Notation: `||` concatenates exact bytes, `NUL` is one 00 byte, and `hex(T)` is
64 lowercase ASCII hexadecimal characters. Domain strings contain the exact
spaces and punctuation shown below. No implicit terminator is added unless NUL
is written explicitly.

```
C = SHA256(ASCII("FLASH-LAN/2 commitment") || NUL ||
           full_R_hello || full_S_hello || raw_S_public_key)
T = SHA256(ASCII("FLASH-LAN/2 transcript") || NUL ||
           full_R_hello || full_S_hello || full_commitment ||
           full_R_key || full_S_key)
```

R checks C in constant time before showing a code. Both use the established
vodozemac SAS object's `bytes("FLASH-LAN/2 sas:" + hex(T)).decimals()` and display
the resulting three four-digit numbers (1000..9191), in order. Do not truncate,
choose an easier code, or use the human-readable code as a cryptographic key.
Three numbers encode 39 bits; this is not by itself a claim of Flash authentication
strength. Review must establish active-attack bounds and the commitment assumptions.

Only after the local user selects “codes match” does that role send type 06:

```
MAC input = "accept:" + role + ":" + hex(T)
MAC info  = "FLASH-LAN/2 confirm:" + role + ":" + hex(T)
role      = ASCII "S" or "R"
MAC       = EstablishedSas.calculate_mac(input, info).as_bytes()
```

Verify with the corresponding peer-role library API. Record protection and
snapshot preparation remain unavailable until both the local user has accepted
and the peer acceptance MAC has verified. A peer MAC received first may be held
for this connection; it must not auto-accept the local UI. A second acceptance,
role reflection, altered transcript, unexpected frame, rejection or expiry closes
this connection. Any retry starts with fresh keys/nonces and no retained MAC.

## Protected records and completion

Use `EstablishedSas.bytes_raw(info, count)` with the exact info strings below;
wrap returned secret buffers immediately in a zeroizing owner. Never expose the
secret, keys, code, MAC or plaintext to platform logs or diagnostics.

| Purpose | Info string | Bytes |
| --- | --- | --- |
| S to R key | `FLASH-LAN/2 key:S>R:` + hex(T) | 32 |
| R to S key | `FLASH-LAN/2 key:R>S:` + hex(T) | 32 |
| S to R nonce prefix | `FLASH-LAN/2 nonce:S>R:` + hex(T) | 16 |
| R to S nonce prefix | `FLASH-LAN/2 nonce:R>S:` + hex(T) | 16 |

Body is `type u8 || direction u8 || sequence u64 || ciphertext_length u32 ||
ciphertext`. Direction is 1 for S>R, 2 for R>S. Sequence starts at 0 separately
in each direction and must equal the exact next expected value. Never accept
duplicates, gaps, reordered or reflected records, and never wrap a counter.
The send counter is consumed when ciphertext is created, before I/O. The pending
record is immutable and must drain before the next is created. A partial/failed
write closes the connection; never encrypt new plaintext with a pending nonce.
The receive counter advances only after authentication and record-state checks;
a failed check closes the connection rather than reusing that sequence number.
Nonce is that direction's prefix[16] followed by sequence u64. AAD is ASCII
`FLASH-LAN/2 record`, NUL, T[32], and the complete frame prefix/header through
ciphertext_length. Encrypt/decrypt with libsodium's combined AEAD API.

Plaintext records are at most 65,536 bytes. Ciphertext length must be 16..65,552;
body length must equal 14+ciphertext_length (maximum 65,566). Verify before
releasing any plaintext to the receiver assembly buffer. The receiver keeps at
most the negotiated aggregate backup cap; overflow closes the connection.

| Type | Direction | Plaintext and state |
| --- | --- | --- |
| 20 data | S>R | nonempty strict backup UTF-8 bytes, only during transfer |
| 21 finish | S>R | total_bytes u64 + SHA256(entire backup)[32], exactly once |
| 22 receipt | R>S | exact finish plaintext, only after length/digest checks and strict backup parsing succeed |
| 23 error | either | u16 local error code (1 export, 2 invalid backup, 3 canceled); no remote text |

R does not publish a preview until finish is authenticated and the complete
backup parses strictly. Receiving never writes the database. S reports transfer
success only on authenticated matching receipt; EOF or lost receipt is
unconfirmed delivery. Receipt means validated receipt, not import or persistence.
R retains its independent preview/merge/overwrite confirmation flow and rechecks
stale previews before destructive commit. Further records after terminal state
are rejected. Export and schema validation failures never become empty backups.

## Lifetime, cancellation and resource budget

One active connection per locally opened service; total opening window 120s,
connect/network-idle limit 10s, local SAS comparison limit 60s from code display,
transfer/export/receipt absolute limit 120s from mutual acceptance. All clocks are
monotonic and deadlines close blocked I/O. Three locally counted failed
connections end the opening; backoff 1s then 2s, without extending the original
opening deadline. Malformed bytes, unauthenticated error claims or EOF cannot
directly set a session-wide remote-success or remote-failure state.

Before mutual acceptance, expiry closes the connection and returns to discovery
only if local opening budget remains. Mutual acceptance stops discovery and
switches to the separate transfer deadline. Do not resume or re-use the connection
after any failure. Local cancel always ends the opening and transfer immediately.
UI dismissal, mobile background entry, process exit, and macOS system sleep close
listeners/connections and release secret/buffer owners. Mere mobile inactive
state during permission prompts or macOS loss of keyboard focus is not background
entry. Late callbacks must carry a generation token and cannot alter a new session.

Local “codes differ” ends the local opening, just like cancel. Input bytes and
cryptographic/state transitions are serialized; an adapter cannot parse following
frames while asynchronous verification/validation is pending. During post-finish
backup validation, only authenticated errors are accepted, never more backup data.

The protocol core must be a bounded event-driven state machine with no platform
socket/UI/database APIs. Platform adapters supply monotonic time, input bytes,
local accept/reject/cancel, and a deferred strict snapshot provider. Snapshot
provider invocation is a tested effect after mutual acceptance only.

## Review/vector gate

The owner-selected self-review covers this file revision, commitment/SAS composition,
unknown-key/role/version/session binding, directional key separation, confirmation
semantics, nonce/AAD/length encoding, cancellation and receipt failure behavior.
Deterministic test-only vectors must contain all exact frame bytes, keys, nonce,
T/C/SAS/MAC/AAD/ciphertext and expected state, with independent recomputation.
vodozemac's public SAS constructor does not accept deterministic private keys;
do not patch production RNG or expose a deterministic production constructor to
work around vector generation. Resolve a test-only reference strategy explicitly
before claiming a full Flash known-answer vector gate.
