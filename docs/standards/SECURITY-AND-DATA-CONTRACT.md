# Security, privacy and data-contract standard

> **Status: Proposed — not ratified.** See [README.md](README.md) for rule levels and labels.

> **中文摘要**：本文分两部分。第一部分是安全与隐私：威胁模型、本地存储与密钥、权限与 entitlement 基线、日志、局域网传输要求，以及“阻断发布”的安全条件。`main` 上的旧版局域网传输存在已确认漏洞（任何同网设备无需 PIN 即可取得完整明文备份），在所有者批准经过评审的替代协议之前必须保持停用。第二部分是备份数据契约：`docs/contracts/` 为唯一权威，规定字段命名、未知字段处理、严格导入与恢复导入、重复与隔离、时区语义、原子写入与回滚，以及防止四端实现悄悄分叉的测试义务。

## Part I — Security and privacy

### 1. Current state

| Observation | Evidence |
| --- | --- |
| On `main` the LAN sender answers any syntactically valid `CHALLENGE` with proof, header and the entire plaintext payload in one write sequence (`android/.../LocalBackupTransfer.kt:199-207`; same design in Swift and ArkTS). The receiver is never authenticated. | Verified (F-01) |
| The six-digit PIN keys the HMAC directly, so a captured nonce and proof allow offline recovery of the PIN in about a second; payload is unencrypted. | Inherited (B-1, reproduced by the independent review) |
| Both hardening lines remove the transport from production, drop the network permissions (`INTERNET`, `NEARBY_WIFI_DEVICES`, `CHANGE_WIFI_MULTICAST_STATE` on Android; `ohos.permission.INTERNET`; `NSBonjourServices` and `NSLocalNetworkUsageDescription` on iOS; `network.client/server` on macOS) and keep the old code only as test fixtures. A static gate `scripts/check-lan-quarantine.py` exists there. No replacement protocol has been selected. | Verified |
| No app uses Keychain, Android Keystore or HUKS. There are no app-held secrets. | Verified (`git grep`, 0 hits on `main` and `feat/paper-writing`) |
| At rest: HarmonyOS RDB `encrypt: true`, `SecurityLevel.S1`. Android Room and Apple SwiftData are unencrypted and rely on OS storage encryption. On `feat/paper-writing`, the iOS capture inbox and draft store are written with complete file protection and excluded from backup. | Verified |
| Android: `allowBackup="false"`; `data_extraction_rules.xml` excludes every domain from cloud backup and device transfer; `FileProvider` is non-exported and exposes only `cache/shared-backups/`. | Verified |
| Apple: macOS runs sandboxed with user-selected file access and hardened runtime; iOS uses App Group `group.com.flash.app.ios` for widget snapshots that hold counts and mood, not record text. Privacy manifests declare only `UserDefaults` (CA92.1). | Verified |
| Exported backups are plaintext JSON by design; the UI warns about this. Apple export writes mode 0600 and replaces atomically on the hardening line. | Verified (README), Inherited (`docs/hardening/application-security-review.md`) |
| A release keystore and literal passwords are in Git history (`4c78c55`), declared void in `android/README.md`; signing is now environment-driven and the build fails without the four variables. `.gitignore` covers `*.keystore` and `release-signing.env` only. | Verified (keystore file at `4c78c55`, signing guard, `.gitignore`); literal passwords Inherited (F-04) |
| About 62 logging call sites on `main`. The hardening line replaced interpolated error payloads with static event identifiers in storage, reminder and quarantine paths. | Verified (count), Inherited (content) |
| HarmonyOS release build enables property obfuscation while persistence and export use `JSON.stringify` of model objects. Fixed only on `fix/pr3-review-followups`. | Verified (rules file on three refs); effect on output Inherited (F-05, hypothesis) |

### 2. Threat model

Assets: journal text, ideas, mood records, tasks; exported backup files; the integrity of the local store.

| Adversary | In scope | Notes |
| --- | --- | --- |
| Another device on the same network | Yes | Can connect to any listening port, spoof mDNS, capture traffic |
| Another app on the same device | Yes | Share targets, exported components, shared storage, clipboard |
| Someone with brief physical access to an unlocked or locked device | Yes | Lock-screen widgets, notifications, debuggable builds, device backup |
| A malicious or malformed backup file | Yes | Parser exhaustion, injection into stored data, path handling |
| A compromised dependency or build tool | Yes | Supply chain |
| A recipient of a shared backup | Out of scope for confidentiality | Plaintext export is a documented product decision; the user chooses the recipient |
| An attacker with root or a forensic image of an unlocked device | Out of scope | OS responsibility unless OD-10 decides otherwise |

A change that adds a network listener, an exported component, a new permission, a new file format or a new place where record text is written updates this table in the same PR (FS-SEC-31).

### 3. Storage, secrets and keys

| ID | Level | Rule | Enforcement |
| --- | --- | --- | --- |
| FS-SEC-01 | MUST | No secret, key, credential, signing material or real user data is committed. `.gitignore` covers keystores, `.p12`, `.jks`, `.cer`, `.p7b`, `.mobileprovision`, `.env`, HarmonyOS signing material. | Planned (secret scan in CI; extend `.gitignore`) |
| FS-SEC-02 | MUST | The keystore committed at `4c78c55` is never used to sign a distributed build. The release pipeline compares the signing certificate fingerprint against a deny list. | Planned |
| FS-SEC-03 | MUST | Signing credentials reach a build only through environment variables or the CI secret store, in a protected environment that requires owner approval. They never appear in logs, artefacts or agent context. | Android: Enforced by `build.gradle.kts` guard. Others: Planned |
| FS-SEC-04 | MUST | If the app ever holds a secret (transfer keys, an encryption passphrase, tokens), it is stored only in Keychain (Apple, with an explicit accessibility class), Android Keystore-backed storage, or HUKS / Asset Store Kit (HarmonyOS). Never in preferences, files, or the database. | Manual; nothing to check today |
| FS-SEC-05 | MUST | Session keys for any transfer are ephemeral: generated per session with the platform CSPRNG, held in memory, zeroed or dropped at success, failure, timeout or cancel, and never persisted or logged. | Manual |
| FS-SEC-06 | MUST | HarmonyOS keeps the RDB encrypted. Plaintext recovered from it (quarantine files) has a bounded lifetime and stays in the app sandbox. | Manual; host tests cover TTL |
| FS-SEC-07 | MUST | On iOS, files holding record text (store, drafts, inbox, share staging) carry an explicit data-protection class; the chosen class is recorded with its trade-off for background work (widgets, intents, notification actions). | Partial on candidate; store class Undecided (OD-10) |
| FS-SEC-08 | MUST | Temporary plaintext (share copies, staging, export temp files) is created with owner-only permissions before the first byte is written, lives in app-private storage, and is deleted on completion and on next launch. | Enforced-candidate (Apple tests on hardening line); Android/HarmonyOS Manual |
| FS-SEC-09 | MUST | Device-level backup behaviour is stated per platform. Android keeps `allowBackup="false"` and the full exclusion rules. Apple and HarmonyOS record their decision (OD-16). | Android: Planned assertion. Others: Undecided |
| FS-SEC-10 | MUST | A storage or key migration never leaves two readable copies of user data behind, and never deletes the old copy before the new one is verified. | Manual |
| FS-SEC-11 | MUST | Release builds are not debuggable. A build that is debuggable or allows OS backup is never distributed. (The historical Alpha010 APK was both.) | Planned (inspect built artefact) |

### 4. Permissions, entitlements and exported surface

Baseline. Anything beyond this needs owner approval (FS-PLAT-10) and a threat-model update.

| Platform | Baseline with LAN disabled | Evidence |
| --- | --- | --- |
| Android | `POST_NOTIFICATIONS`; `MainActivity` exported as launcher; non-exported `FileProvider`. WorkManager merges `ACCESS_NETWORK_STATE`. Candidate also adds a share-target and widget receivers. | Verified (`feat/paper-writing` manifest) |
| iOS | App Group; URL scheme `flash`; notification permission requested only when a reminder is first needed | Verified |
| macOS | App Sandbox; user-selected read-write files; hardened runtime. No network entitlements. | Verified (`feat/paper-writing`) |
| HarmonyOS | `PUBLISH_AGENT_REMINDER`, `VIBRATE`; `EntryAbility` exported with the home skill; form extension | Verified (`feat/paper-writing`) |

| ID | Level | Rule | Enforcement |
| --- | --- | --- | --- |
| FS-SEC-12 | MUST | Manifests and entitlement files match the baseline. A diff to any of them is called out in the PR description. | Planned (snapshot check); Enforced-candidate for LAN declarations |
| FS-SEC-13 | MUST | Runtime permissions are requested at the moment of need, with the reason shown first, and denial leaves the feature degraded but the data intact. Data import never fails because a notification permission is missing; it reports "data imported, reminders not restored". | Enforced on Android (instrumented test); Manual elsewhere |
| FS-SEC-14 | MUST | Exported components, URL handlers, intents and share targets validate every input, map it to a closed set of actions, and never treat input as a file path, SQL or a navigation target outside that set. | Manual; iOS deep-link tests exist |
| FS-SEC-15 | MUST | Widgets, lock-screen surfaces, notifications and form cards show counts and mood at most, never record text, unless the user opts in. Apple widget content is marked privacy-sensitive. | Enforced-candidate (hardening line) |
| FS-SEC-16 | MUST | Apple privacy manifests list every required-reason API actually used, checked before each store submission. | Manual (F-18 open) |

### 5. Logging and telemetry

| ID | Level | Rule | Enforcement |
| --- | --- | --- | --- |
| FS-SEC-17 | MUST | The app sends no telemetry, analytics or crash reports to any server. | Manual; no network permission on candidate |
| FS-SEC-18 | MUST | Logs and fatal messages never contain record text, titles, tags, backup payloads, PINs, keys, file contents, or raw error payloads that may embed them. Log a static event identifier and a category. | Enforced-candidate (HarmonyOS marker test); Manual elsewhere |
| FS-SEC-19 | SHOULD | Diagnostic and seeding code is compiled only into debug builds. | Manual |

### 6. Release-blocking criteria

A build MUST NOT be released, to anyone, while any of these holds. Only the owner can waive one, in writing, per release.

| ID | Blocker | State on `main` | State on `feat/paper-writing` |
| --- | --- | --- | --- |
| RB-01 | Production code can listen, advertise or connect using the legacy LAN transport | **Fails** | Passes (static gate) |
| RB-02 | Any transfer path releases backup bytes before both sides are authenticated to each other, or allows offline verification of the pairing secret from a captured transcript | **Fails** | Not applicable (no transport) |
| RB-03 | A secret or signing key is in the tree, or the build is signed with a deny-listed key | Passes for the tree; history contains the voided key | Same |
| RB-04 | The artefact is debuggable, allows OS backup contrary to FS-SEC-09, or is unsigned / ad-hoc signed | Not verified (no release artefact exists) | Not verified |
| RB-05 | A platform's export is rejected by another platform's strict import for the same contract version, or imports lose fields | **Fails** (F-03) | Passes at codec tier; installed-app tier not verified |
| RB-06 | A valid user record can make export fail entirely (F-02 class) | **Fails** | Passes at host tier |
| RB-07 | HarmonyOS release build has not been shown to write contract-conformant keys (FS-DATA-17) | Not verified | Not verified; rules file unchanged |
| RB-08 | A degraded-storage mode performs destructive side effects (FS-ARCH-18) | **Fails** (F-07) | Passes (tests on candidate) |
| RB-09 | A database migration has no test from every released version | Android passes; Apple test exists but is not in CI; HarmonyOS none | Same |
| RB-10 | Manifests or entitlements differ from the approved baseline | Baseline not yet approved | Same |
| RB-11 | Required CI checks are not green on the release commit, or a required tier of the compatibility matrix is recorded as failed | — | — |

### 7. LAN transfer requirements

Applies to any future transport. Derived from `docs/hardening/lan-v2-decision.md` (Inherited) and the findings above.

| ID | Level | Rule |
| --- | --- | --- |
| FS-SEC-20 | MUST | Legacy `FLASH-AERO/1` stays out of production code on all four platforms. No runtime switch, no fallback, no downgrade negotiation. |
| FS-SEC-21 | MUST | A replacement is specified in `docs/contracts/` and approved by the owner before any implementation: protocol, exact library and version, test vectors. |
| FS-SEC-22 | MUST | Mutual authentication completes, and the user confirms the pairing on both devices, before any backup byte is sent. The pairing secret is used only in a PAKE or to authenticate an ephemeral key exchange with a short authentication string; never as a MAC or encryption key directly. |
| FS-SEC-23 | MUST | Payload is protected by an AEAD keyed from the session, bound to both roles, both nonces, the protocol version and the handshake transcript. Records are sequenced; replay, reorder and truncation are detected. |
| FS-SEC-24 | MUST | Unauthenticated input cannot end a session, hold the only connection slot indefinitely, or cause more than a bounded amount of work. One monotonic deadline covers the whole session; every socket is closed on stop. |
| FS-SEC-25 | MUST | The listener exists only while the user is on the transfer screen, for a bounded time, and is closed on success, failure, timeout, cancel and backgrounding. |
| FS-SEC-26 | MUST | "Sent successfully" is shown only after an authenticated acknowledgement from the intended receiver. |
| FS-SEC-27 | MUST | Security regression tests exist on every platform and as shared vectors: wrong secret, no secret, replayed transcript, truncated and reordered records, oversize frames, slow peer, unauthenticated error injection, split delivery at every byte boundary, and a check that a captured transcript gives no offline verifier. |

Enforcement for this section: FS-SEC-20 is Enforced-candidate (static gate and disablement tests on both hardening lines); FS-SEC-21 to -27 are Manual until a transport is approved, at which point their tests become required checks.

### 8. Security testing

| ID | Level | Rule | Enforcement |
| --- | --- | --- | --- |
| FS-SEC-28 | MUST | Every confirmed security finding gets a regression test that fails on the vulnerable revision. | Manual |
| FS-SEC-29 | MUST | Parsers of untrusted input have negative tests for: malformed syntax, duplicate keys, deep nesting, oversize input, oversize arrays, wrong types, and deterministic mutations of valid fixtures. | Enforced for shared fixtures; mutation tests Enforced-candidate |
| FS-SEC-30 | SHOULD | A static gate asserts that no network API is referenced from production sources while LAN is disabled. | Enforced-candidate (`check-lan-quarantine.py`) |
| FS-SEC-31 | MUST | The threat model in §2 is updated in the same PR as any change that adds a network listener, exported component, permission, file format, or a new place where record text is written. | Manual |

## Part II — Backup contract and data interoperability

### 9. Current state

`docs/contracts/` holds the JSON Schema (0.2.0), 40 fixtures with a manifest, merge and overwrite golden files, a Node reference validator, and a written contract. Android JUnit, Swift Testing and HarmonyOS host tests read the same fixture files (Verified). The schema, reference validator and HarmonyOS host tests run in CI; the Swift contract tests do not, because FlashKit tests are not in CI (Verified). On `main`, Apple writes section schema 2 and Android and HarmonyOS accept only 1 (Verified). The time-zone list on `main` is a 420-name legacy ICU enumeration; both hardening lines replace it with 439 generated names plus alias resolution and a written policy, `docs/contracts/time-zones.md` (Verified). Installed-app transfer in all directions is unverified (Inherited).

### 10. Rules

| ID | Level | Rule | Enforcement |
| --- | --- | --- | --- |
| FS-DATA-01 | MUST | `docs/contracts/` owns the format. A platform does not accept, emit or interpret anything the contract does not define. | Enforced (fixtures) |
| FS-DATA-02 | MUST | Envelope: `version`, `exportedAt`, `appVersion`, `notes`, `schemas`, `data`. Section schema versions are integers per section and are the only parsing selector. | Enforced |
| FS-DATA-03 | MUST | Keys are lowerCamelCase ASCII; instants are UTC ISO-8601 with millisecond precision on export; calendar dates are `YYYY-MM-DD`; IDs are canonical UUID strings with no surrounding whitespace or line terminators; text limits are counted in UTF-16 code units. | Enforced; UUID and date anchoring on Swift Enforced-candidate (F-09, `fix/pr3-review-followups` `2187100` only) |
| FS-DATA-04 | MUST | Strict import rejects the whole file on any violation: unknown root key, unknown section, unknown record field, wrong type, out-of-range value, duplicate ID, duplicate JSON key, unsupported version. Nothing is written. | Enforced |
| FS-DATA-05 | MUST | Recovery import is a separate, explicitly labelled entry. It may skip individual invalid or duplicate records and reports the count. It still rejects unknown fields, unknown sections and unknown versions, and never guesses semantics. It never modifies the source file. | Enforced |
| FS-DATA-06 | MUST | A platform that does not implement a section schema version rejects files that use it, with a message telling the user to update. It never imports and drops the newer fields. | Enforced |
| FS-DATA-07 | MUST | Fields added in a newer section schema are optional and nullable; a record written by an older client remains valid under the newer schema. A field's absence, `null` and `false` are preserved distinctly through import, edit and export. | Enforced-candidate (schema 2 round-trip tests) |
| FS-DATA-08 | MUST | Export validates before writing and never produces a file its own strict import would reject. A single invalid local record does not block export of the rest without telling the user which record and why. | Partly Enforced; F-21 open |
| FS-DATA-09 | MUST | Limits are identical on all platforms and defined in the contract: 50 MiB file, 100,000 records per section, scanner budgets applied before full materialisation. | Enforced (fixtures); budgets Enforced-candidate |
| FS-DATA-10 | MUST | Merge and overwrite results equal the golden files, compared semantically (order, metadata and null-versus-absent ignored as the contract states). Conflict rule per section is defined in the contract, not per platform. | Enforced |
| FS-DATA-11 | MUST | Import is transactional. Failure at any point leaves the database as it was. The user previews differences and chooses merge or overwrite; overwrite re-validates state at commit. Post-commit work (reminder rebuild) reports its own failure separately. | Android, Apple: tests. HarmonyOS: host tests with a fake store |
| FS-DATA-12 | MUST | Rows the app cannot validate are quarantined with table, ID, raw content and reason, not deleted. Merge and overwrite do not destroy quarantined originals without explicit user confirmation that names the count. (F-08.) | Enforced-candidate (`fix/pr3-review-followups` `ec53563`) |
| FS-DATA-13 | MUST | Time zones: the accepted identifier set is generated from a pinned IANA snapshot plus every identifier ever accepted; the original spelling is preserved on round trip; rules come from the OS; an identifier the OS cannot resolve fails the import before any write. No identifier is ever removed from the accepted set. | Enforced-candidate |
| FS-DATA-14 | MUST | All-day dates do not shift with the device zone; timed items keep their absolute instant and their named zone. DST gaps are rejected at entry; DST overlaps carry an explicit offset. | Enforced (fixtures), Manual on device |
| FS-DATA-15 | MUST | File writes are atomic: write to a sibling temporary file, flush, then replace. A failed write leaves the previous file intact and removes the temporary. | Apple: tests. Android/HarmonyOS: F-10 open |
| FS-DATA-16 | MUST | Local-only data never enters a backup: read-state, notification and reminder IDs, device identifiers, settings, quarantine. | Enforced (unknown fields rejected) |
| FS-DATA-17 | MUST | Serialised key names are stable under every build configuration. HarmonyOS release builds do not apply property obfuscation to model classes, and a release-build export is validated against the schema before any HarmonyOS release. Android R8 keeps no reflective serialisation; if that changes, keep rules and a release-build round-trip test are required. | Enforced-candidate (rules fix); release-build validation Planned |

### 11. Tests that prevent divergence

| ID | Level | Test obligation | Enforcement |
| --- | --- | --- | --- |
| FS-DATA-18 | MUST | Every fixture in `cases.json` is run by all four codecs (Kotlin, Swift, ArkTS, reference validator) with the expected accept or reject outcome. A platform test that skips a fixture fails. | Enforced for three; Swift Planned (CI) |
| FS-DATA-19 | MUST | **Actual-export matrix.** Each platform's real exporter output, from a fixed synthetic data set, is committed as a fixture and parsed by every other platform's strict importer, then re-exported and compared field by field. Counts alone are not sufficient. | Enforced-candidate at codec tier (`tools/verification/`, `docs/hardening/compatibility-blockers.md`); not in CI |
| FS-DATA-20 | MUST | A contract change adds positive and negative fixtures in the same PR and bumps the schema version. | Manual |
| FS-DATA-21 | MUST | Fixtures cover values that differ by environment: modern and legacy zone names, non-BMP text at length limits, sub-millisecond instants, large offsets, booleans versus integers, `1.0` versus `1`. | Enforced; zone coverage Enforced-candidate |
| FS-DATA-22 | MUST | Before a release, the installed-app matrix (4 × 4 directions, file and share paths; merge, overwrite, cancel, malformed, unsupported version; relaunch and re-export) is run on real builds and recorded, with unavailable cells marked "not verified". | Manual; currently all 16 cells unverified |
| FS-DATA-23 | SHOULD | Property-based or mutation tests feed each codec with mutated valid fixtures and assert that all four agree on accept or reject. | Planned |

### 12. Platform considerations

- **Android.** `org.json` is lenient; the strict path adds its own syntax checks. Room transactions give FS-DATA-11. Export file handling needs temp-and-replace (F-10).
- **Apple.** One codec in `FlashCore` serves iOS and macOS, so the two cannot diverge; its tests must run in CI for that to mean anything.
- **HarmonyOS.** Validation happens when rows are loaded as well as on import, which is why quarantine exists. Transaction binding on a real RDB is unverified (F-25). Obfuscation is the platform-specific risk to FS-DATA-17.
- **Reference validator.** Node, Ajv; runs anywhere; it is the tie-breaker when platforms disagree.

### 13. Testable criteria

Contract and fixture checks exit 0; each platform's test report lists every `cases.json` entry; the actual-export fixtures round-trip through all four codecs; a release HAP's export validates against the schema; `check-lan-quarantine.py` exits 0; a secret scan of the tree finds nothing.

### 14. Migration impact

Part I rules are mostly satisfied by landing the hardening line (RB-01, -05, -06, -08) and porting the fixes that exist only on `fix/pr3-review-followups` (F-05, F-08, F-09, F-23). New work: secret scan, manifest snapshot check, release-artefact inspection, deny-listed fingerprint check. Part II needs FlashKit tests in CI and the actual-export fixtures promoted from `tools/verification/` evidence into `docs/contracts/fixtures/`.

### 15. Verification

CI per [BUILD-TEST-CI-STANDARD.md](BUILD-TEST-CI-STANDARD.md); the release record lists each RB item with pass, fail or not verified and the evidence tier.

### 16. Exceptions

No reviewer-level exceptions in this document. RB items: owner only, per release, published in the release notes. FS-SEC-20 has no exception.
