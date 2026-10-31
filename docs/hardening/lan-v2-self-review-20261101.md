# LAN v2 composition self-review · 2026-11-01

Owner instruction: “你自行审查”. This replaces the external-review dependency
with Codex self-review for this iteration. It is **not an independent audit**,
certification or proof of security. Review scope is the concrete
`docs/contracts/lan-v2-review-draft.md` candidate and feasibility probes, not
unwritten application adapters. Formal enablement remains gated by implementation
tests, installed-app verification and the physical-device matrix.

## Threat/control review

| Threat or boundary | Candidate control / required evidence |
| --- | --- |
| Old PIN-less pull, captured PIN verifier | No PIN password or payload release before both human acceptance and peer confirmation |
| Adaptive-key MITM | Commit before R key, reveal afterward; commitment binds both exact offers and S key; SAS binds ordered transcript; humans compare all groups over a trusted channel |
| Role/version/session confusion | Fixed roles/suite, role-specific MAC info, directional record infos, fresh nonces/keys; discovery names are untrusted |
| Downgrade/replay | New service/version, no fallback, transcript-bound acceptance; unexpected types/order/versions close connection |
| Nonce reuse after partial writes | Clarified: consume counter at ciphertext creation; pending record immutable; serialized write before next record; failure closes without old-key retry |
| Truncation/forged success | Authenticated finish with total/hash and exact sequence; strict parse before protected receipt; EOF/lost receipt is not success |
| Harmony parsing race | Clarified: serialize cryptographic/state processing; no data accepted during post-finish strict validation |
| Local rejection | Clarified: “codes differ” ends local opening; no automatic retry or acceptance |
| Resource exhaustion | Fixed pre-auth sizes, bounded records/aggregate, monotonic total+idle deadlines, one connection and local failure budget; active denial of service remains possible |
| Logs/memory | No secret-bearing Debug/session serialization; wipe owned key/backup buffers, release handles on exit; upstream internal copies/registers/OS memory are not proven erased |
| UI confirmation | No automatic confirmation/default affirmative action; show/read all three groups and require an explicit local choice |
| Data semantics | Deferred strict snapshot; no auto-commit; retain strict parsing, preview, TOCTOU checks, rollback and reminder error semantics |

## Result and limits

No blocker to **isolated protocol implementation and adversarial testing** was
identified after the clarifications above. This is not a release approval and
does not assert that implementation already enforces the controls. Each row must
acquire core/adapter test evidence before production enablement.

vodozemac's public SAS constructor has no deterministic private-key input. Do
not patch production RNG or access private memory layouts for known-answer tests.
Use upstream interoperability checks for its SAS primitive, independent fixed-secret
reference vectors for framing/KDF/records, and real randomized peer sessions for
the complete state machine. Label these separately; do not claim fixed-secret
vectors execute the opaque SAS constructor.

Failure to compare codes, compromised endpoints, traffic analysis, and local
process/OS memory compromise remain outside this transport's guarantees. The
display encodes 39 bits; no separate formal analysis of Flash's active-attack
success probability has been delivered.
