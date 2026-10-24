# Flash hardening review checkpoint — 2026-10-25

The candidate contains security/data fixes and one measured shared-code optimization. **Independent acceptance is pending. Four-platform app performance and the full screenshot/device matrix are incomplete.** Codex supplies implementation/evidence; Claude supplies independent review/evidence; the owner decides acceptance and fix ownership. No merge, push, tag, release, signing/team/deployment change or new runtime dependency/permission.

Approved base: PR#2 head `e9a0aa6a2a147b8ebd9be81d1c298c5b4a2eab25`, checked open/unmerged at baseline2026-10-24. Original checkout remains at that revision. Append-only implementation continued from `codex/security-performance-hardening` at4d28844 into `codex/hardening-continuation` when the workspace became read-only. Current worktree: `/Users/haydenjiang/Documents/DEV/flash-Alpha/.worktrees/codex-hardening`. All original milestones remain ancestors; no amend/rebase/force-push. Mandatory external CHANGELOG was updated for each milestone.

## 1. Findings in severity order

References below are repository-relative. Historical vulnerable source locations refer to immutable e9a0aa6, whose network implementations now live only in test fixtures. User initiation and a LAN-reachable temporary port are prerequisites; no Internet-wide exploitation or deployed compromise is claimed.

| Priority / finding | Source and synthetic evidence | Candidate response / remaining boundary |
| --- | --- | --- |
| High, highest-priority F-01: receiver need not know PIN | e9 `shared/FlashKit/Sources/FlashCore/Data/LocalBackupTransfer.swift:358`, `android/app/src/main/java/com/flash/app/data/LocalBackupTransfer.kt:240`, `harmonyos/entry/src/main/ets/data/LocalBackupTransfer.ets:151`: public valid CHALLENGE pipelines full payload. Actual Harmony sender released all1619fictional bytes without supplying/reading PIN; malformed control released0. Apple/Android executed loopback tests likewise send only CHALLENGE before receiving all synthetic bytes | Owner-approved disablement39d8fe0 removes production adapters/listening/discovery/connect actions. Parent controller regressions fail, candidate passes. This removes exposure in updated apps; it does not repair installed legacy peers or deliver a replacement protocol |
| High: plaintext backup on TCP | Same sender paths encode raw JSON; HMAC is not encryption. Passive on-path host/AP can read private logs/ideas/emotions/tasks | Disabled; no AEAD transport enabled. Proposed reviewed PAKE or authenticated ephemeral-key/SAS direction requires further review/approval |
| Medium: offline PIN enumeration | Public nonce/proof plus HMAC directly keyed by six-digit PIN supplies an offline verifier for1,000,000candidates. Online backoff cannot limit this | Disabled; no PIN-length-only or added-HMAC-round claim. No new secret or crypto dependency |
| Medium: blocking socket lifecycle / unbounded waits | Android accepted sockets were not owned by stop/deadline; SO_TIMEOUT does not bound writes. Legacy challenge waits and slow framing could outlive the intended total session | fbb5c9e/0c02f5e add owned sockets, monotonic total deadlines/cancellable waits and framing bounds, then archive transport under disablement. Loopback/negative tests are historical fixtures, not a secure transport claim |
| Medium: parser preallocation/recovery boundary | Apple/Harmony recovery bypassed duplicate/depth scanning; Android/Harmony dense primitive input could allocate before entry-count checks | deb207e/5c5d1f2 enforce scanners and10M-value budget before full materialization. Duplicate/escaped duplicate keys, deep nesting, oversized and deterministic mutation cases pass; valid schema/50MiB limits unchanged. Not sustained coverage-guided fuzzing |
| Low: export permissions / partial staging | Apple wrote before restricting mode; default Foundation replacement could restore0644 on an existing destination | 8883f85 creates exclusive/no-follow0600 before first plaintext, cleans failed writes and uses private replacement metadata. Parent0644 replacement regression fails; descriptor/symlink/failure tests pass. Remote/provider ACLs remain unverified |
| Low, F-06 availability: unauthenticated error ends session | e9 sender accepts ERR PIN as global terminal state. Actual Harmony source reproduced service withdrawal before authentication | Production legacy path disabled; future protocol must constrain unauthenticated errors to a bounded connection. Android total waits separately bounded; no claim that changing proof alone fixes F-01/F-06 |

Additional compatibility/integrity findings are not inflated into attacker exploits: F-02 modern names were rejected by a frozen ICU-derived list; F-03 actual Apple schema2 output was rejected by Android/Harmony; Android stale overwrite/cancellation could change unintended data; Harmony postcommit read-state cleanup could leave committed rows and stale UI. Candidate fixes and exact tiered evidence follow below. Error-log interpolation and widget sensitivity received privacy hardening; a synthetic Harmony IO exception marker reproduced log copying before removal. Credentials/keystores remain a separate remediation boundary.

The companion managed security scan reports **seven baseline findings with partial coverage**. The441-file inventory was not exhaustively reconciled, and physical privacy/advisory coverage remains open. It is not a clean bill of health for either baseline or candidate.

## 2. Fixes by platform and immutable milestone

| Scope | Commits | Result |
| --- | --- | --- |
| Shared Apple / iOS / macOS | deb207e,8883f85,d65bb47 | Recovery input guards; private atomic export; cancellation checked before repository commit and detached result publication |
| All LAN apps | 6e56e6f,fbb5c9e,0c02f5e,39d8fe0,b5d23c8 | Neutral per-session identity/lifecycle/framing maintenance, followed by approved production quarantine and clear file/share guidance. NetService main-RunLoop fix/regression retained in test fixture |
| Android | 5c5d1f2,4d28844,4a1eef0 | JSON budgets; generation-owned input/jobs, consumed preview and atomic stale-overwrite confirmation; nullable schema2 fields through Room/entities/mappers and approved additive4→5 |
| Harmony | 5c5d1f2,6914f04,d095696 | JSON budgets; lossless schema2 normalization/editing in existing payload tables; atomic business/read-state overwrite/clear/delete and postcommit publication |
| Cross-platform time zones | 1acf52d | Pinned generated IANA naming/Link/backzone facts plus strict native rules; preserve original wire spelling; shared alias resolution for validation/calendar/editor/cards/forms; unsupported native zone fails before write |
| Privacy | 0943583 | Static storage/reminder/read-state/quarantine diagnostics, no raw exception text in these logs/fatal message; native WidgetKit sensitivity markers without changing refresh/store/capture behavior |
| Build chain | a6b6099 | Pin official checksum for existing Gradle8.14.3; checked-in wrapper JAR matches official checksum; versions/signing unchanged |
| Test/evidence | 0aee15a,4c8794c | Deterministic iOS reminder fixture with all assertions retained; actual-export and native cross-process evidence/probes |
| Performance only | 4e67c13,0b84ec2,d6ce569,fe12e62 | Reproducible Release harness, validated UTC normalization/allocation optimization, raw before/after evidence |
| UI planning only | 9b4d8e7 | Native token/coupling audit, reversible next-beta plan and16original Android screenshots; no visual refresh/theme framework |

Android migration adds five nullable columns; no table replacement, destructive fallback, store move or backup-envelope/schema rewrite. Old Android v4 binaries may not open v5; old Harmony binaries can discard metadata despite unchanged SQL. Roll back visual code while retaining compatible data/serializer layers and LAN disablement, or roll forward. See [migration/rollback plan](schema2-migration-plan.md).

## 3. Protocol and actual backup compatibility

All four updated apps intentionally perform **no legacy LAN transfer**. New→new and either new/old direction stop at the new app's local explanatory message, before export/permissions/networking. Old→old retains its known vulnerabilities; updating one endpoint does not secure another old sender. New apps do not silently downgrade, advertise, listen or negotiate a replacement. Old apps may time out because no new service exists.

[LAN proposal](lan-v2-decision.md) requires mutual confirmation before any backup bytes, authenticated bounded error handling, explicit version/capability offers, role/session/transcript binding, maintained AEAD/unique nonces and expiry/cancel cleanup. Reviewed PAKE or ephemeral-key/SAS options are screened, not selected/implemented. No homemade PAKE/cryptography, accept-all certificate path or insecure fallback.

Actual recorded Apple export (2639bytes, SHA256 cc9718…fa2) was first rejected unchanged by Android/Harmony. Candidate paths now preserve every schema2 metadata field, including false favorites, intensity and dangling source links:

| Exact production exporter bytes → receiver | Verified tier |
| --- | --- |
| Apple → Android | Native API36 parser/Room, write→force-stop→read→native export; pass |
| Apple → Harmony | Actual ArkTS codec on Node with explicit kit substitutes; pass |
| Android native export → Apple / Harmony | Native macOS FlashCore / actual ArkTS Node codecs; pass |
| Harmony export → Android | Host production Kotlin codec and native API36 separate write/read invocations; pass |
| Harmony export → Apple | Native FlashCore parse/export; pass |
| Harmony→Android native output → Apple persistence | Exact bytes pass native codec plus separate SwiftData/repository/read-state processes; pass |

These are actual exporter/parser artifacts, not only shared fixtures. They do **not** complete the16-cell installed-app UI matrix or physical devices. Harmony native RDB, iOS/macOS file-picker app exports/imports, UI merge/overwrite/cancel/relaunch/reminders and all physical directions remain unverified. [Matrix/provenance](compatibility-blockers.md), [committed receipts](evidence/compatibility/manifest.json), [reproduction tools](../../tools/verification/README.md).

Time-zone facts preserve all420legacy IDs and add the complete modern geographic IANA naming set (439total), generated rather than hand-appended names. Native Foundation/ZoneId/Harmony available-ID+Intl validation supplies rules; raw input spelling persists. Native Android tzdata2025a, host Intl2026b and pinned2026e naming facts are different authorities, not evidence of identical rule versions. [Policy and regeneration](../contracts/time-zones.md). Older-OS alias absence is simulated; oldest supported OS/physical validation is pending.

## 4. Measured performance and remaining bottlenecks

MacBook Pro M3Pro11cores/36GB, macOS27.2, Xcode-beta27.2/Swift6.4; Release host harness, two warmups/seven samples, fictional1k/10k/100klogs plus half as many emotions and one-fifth tasks over1/5/10years. Baseline4e67c13→d6ce569; exact dataset fingerprints/bytes match. Serial idle reserved environment documented in raw conditions.

| Dataset logs | Before strict parse median [range], ms | After, ms |
| ---: | ---: | ---: |
| 1,000 |140.597 [139.839–147.626]|33.746 [32.814–34.061]|
| 10,000 |1472.487 [1423.151–1485.697]|322.284 [320.911–333.975]|
| 100,000 |14893.932 [14762.504–14961.820]|3301.493 [3262.519–3349.243]|

100k median is4.51× faster (~77.8% lower time). Whole-process peak RSS remains about2.06GB (+~0.3%), not per-import peak; this remains a major large-data/mobile concern. Search/calendar variations are not claimed improvements. Native sample showed formatter work; an unusable xctrace attempt is excluded.432correctness cases and full shared gates protect normalization. No blind pagination/cache/widget throttling.

| Platform app Release metrics | Before / after |
| --- | --- |
| macOS app launch/scroll/queries/charts/energy |not verified / not verified; only shared native host results above|
| iOS app/device |not verified / not verified|
| Android app/device |not verified / not verified; Release JVM gates are not an app benchmark; signing guard preserved|
| Harmony app/device |not verified / not verified; unsigned Debug build/Node tests are not device profiling|

Later schema/time-zone/security commits were not rebenchmarked; the measured harness uses all-day tasks. Do not extrapolate these medians to named-zone tasks or mobile/UI behavior. [All raw samples, resources, native sampling and exact reproduction](performance.md).

## 5. Next-beta UI proposal and rollback boundary

[Proposal](next-beta-ui-plan.md) inventories semantic tokens, FlashDesign/native shells, typography/spacing/glass/motion/empty states, hard-coded values and state/navigation/data coupling. Retain native iPhone tabs, Mac sidebar/menus/keyboard, Compose and ArkUI behavior. Approve direction/IA first; migrate token/component families incrementally, with accessibility/screenshot/device gates and an optional minimal disabled seam only if needed. No seam or redesign was implemented.

16current Android primary-screen PNG/XML baselines cover light/dark and font1/2 on1080×1920compact GLASS. This is empty data, not AX5 or full accessibility coverage. Other states/styles/sizes and iOS/macOS/Harmony screenshots remain pending. Xcode27.2 Device Hub was located, but the Mac locked before UI selection; CUA requires manual unlock, requested separately. No lock bypass or generated stand-in image. A sample home empty-state action is partly behind the dock initially; record/review for reachability rather than silently redesigning it.

Preserve AX5/Dynamic Type, VoiceOver/TalkBack/ScreenReader, Reduce Motion, contrast, keyboard/focus and native minimum touch bounds. Revert only future visual commits; retain security, schema2/v5-compatible persistence, strict validation, widget refresh and disabled legacy LAN. No data migration may hide inside a UI refresh.

## 6. Gates, residual risks and device gaps

| Latest affected gate | Executed result |
| --- | --- |
| FlashKit host package |204passed; includes retained archived Bonjour/loopback and current cancellation/persistence guards|
| macOS app/widget compile + behavior |13passed, unchanged count after shared changes|
| iOS app/widget test build + simulator |build passed;14passed. One earlier timestamp-tie fixture failure disclosed/corrected test-only, no removed assertion|
| Android Debug/Release JVM + Debug app/test APK |93passed per variant; APKs built|
| Android API36/Android16 native suite |13passed +1intentional two-process assumption skip (14reported); explicit Apple and Harmony write/read phases separately passed|
| Contract + Harmony host |287passed after four parent-failing transaction regressions|
| Harmony native ArkTS/HAP |build passed unsigned; no signing changes|
| Gradle checksum configuration |official distribution/JAR values matched; cached8.14.3 launch passed; fresh-download rejection path not executed|

[Exact commands, parent failures and gate history](verification.md). All builds/simulators/benchmarks ran serially; no Codex simulator/emulator/build workload remains running at this checkpoint. Screenshots are not performance or physical-device proof. The machine reservation has not been reassigned to another agent.

Real M3Pro Mac was available/tested. One paired iPhone19,7 was available but not installed/verified with a new team; another iPhone17,2 unavailable. No Android/Harmony physical target attached at baseline. Dedicated simulator/emulator results remain separately labeled. No lower-spec/Intel/oldest-OS, physical LAN, lock-screen privacy, battery/thermal, actual notification/widget freshness, provider/remote ACL, OEM/OS cloud backup or power-loss evidence. App signing remains unchanged/unset where noted. Credentials/keystores and transitive dependency/mirror verification require separate work. [Application review boundaries](application-security-review.md).

## 7. Decisions and reviewer attack list

Already approved and implemented: legacy LAN temporary disablement; narrow schema2 preservation/additive Room4→5. No repeated approval requested for them.

Owner decisions remain: select/review the concrete replacement protocol and exact maintained crypto dependency before re-enablement; approve any new permission/entitlement/SDK; authorize signing/team/deployment changes if real-device installation requires them; approve visual implementation/direction; separately own credential remediation, OS-backup/privacy policy and final acceptance. Merge/tag/release remains prohibited without approval. Manual Mac unlock is an environmental prerequisite for remaining screenshot work, not authorization to change credentials.

Claude should challenge: hidden production LAN reachability/fixture packaging; zero payload preparation before disabled actions; strict schema1/2/type/unknown-field negatives; migration failure/reopen/read-state and binary rollback limits; old/native time-zone alias history and DST; cancelled/superseded/double confirmation and overwrite races; read-state IO rollback at every transaction step; permissions before first plaintext and provider ACLs; raw benchmark reproducibility/RSS; and complete screenshot/accessibility/real-device gaps. Findings return to the owner for fix assignment. This checkpoint does not grant acceptance.
