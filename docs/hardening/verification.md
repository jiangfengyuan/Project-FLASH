# Hardening verification — ongoing

Independent acceptance remains pending. Baseline production revision: `e9a0aa6`; Codex branch `codex/security-performance-hardening`. All runs are serial on the owner-reserved M3 Pro/36GB/macOS27.2 host, Xcode-beta27.2. Times and host test durations are not Release app benchmarks.

## M0/M1 — recovery input boundary

| Gate | Before | After recovery fix | Meaning |
| --- | --- | --- | --- |
| FlashKit `swift test` |191 passed|193 passed|Host/macOS package tests, includes actual loopback/Bonjour regression; no physical-device claim|
| Contract + Harmony host tests |265 passed|268 passed|Actual ArkTS codec/controller sources via existing explicit platform fakes; no native RDB/device claim|
| New Apple recovery regressions on parent production |2 tests failed,3 expectation issues|Included in193 passed|Duplicate/escaped duplicate keys and130-deep skipped-record nesting|
| New Harmony recovery regressions on parent production |2 failed,1 passed|3 passed, included in268|Same attacks; ordinary damaged-record recovery remains supported|
| Harmony native hvigor Debug HAP |not rerun before M1|BUILD SUCCESSFUL; unsigned|Native ArkTS validation/build only; signing configuration untouched|
| iOS/macOS app gates |pending cumulative shared-code gate|pending|Do not infer app gate results from package tests|

Commands, from repository root unless shown:

```sh
# Host dependencies reused read-only from existing installation; no package additions.
export FLASH_AJV_PATH=/Users/haydenjiang/Documents/DEV/flash-Alpha/app/scripts/backup-contract/node_modules/ajv
export FLASH_TYPESCRIPT_PATH=/Users/haydenjiang/Documents/DEV/flash-Alpha/app/scripts/backup-contract/node_modules/typescript
node --test scripts/backup-contract/contract.test.cjs harmonyos/tests/*.test.cjs
node --test harmonyos/tests/recovery-input-hardening.test.cjs
cd shared/FlashKit
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test --filter 'BackupContractTests/recoveryRejects'
```

Native Harmony command is the unchanged `harmonyos/README.md` command. No deployment target, permission, dependency, signing identity/team, wire format or backup schema changed. Recovery still skips ordinary damaged records; malformed syntax/duplicate keys/depth bombs are rejected before object materialization.

Raw execution logs are retained in the chat workspace `work/evidence/`: `m0-flashkit.log`, `m0-contract-harmony.log`, `m1-apple-parent-regression.log`, `m1-harmony-parent-regression.log`, `m1-flashkit.log`, `m1-contract-harmony.log`, `m1-harmony-native.log`. Parent regressions were run after adding tests while the corresponding production files still matched the parent; then the fix was applied and the full gates rerun. Test counts are executed results, not test declaration counts.

## M2 — private export staging and replacement

Observed a second permissions defect during runtime reproduction: replacing an existing0644 destination with Foundation's default replacement options restores the old broad permissions. `replacingReadableDestinationDoesNotRestoreItsOldPermissions` failed against the parent writer, then passed with `.usingNewMetadataOnly` and the private writer.

The writer now uses exclusive/no-follow creation with0600 before any plaintext, enforces local-volume mode before writing, removes partial files after write/close failure, and preserves atomic replacement. New descriptor-level tests inspect mode before the first write, inject a partial write/failure and verify deletion, and ensure an existing symlink is neither followed nor removed. The new internal test seam does not exist on the parent, so those two tests are **post-fix guarantees**, not claimed as executable failing-parent regressions. File protection flags and read-state persistence were untouched.

Full FlashKit gate: **196 passed**. Reproduction: `swift test --filter BackupTransferTests` (substring also selects the LAN suites; parent31 executed with1 failure), then full `swift test`. Logs: `m2-export-parent-regression.log`, `m2-flashkit.log`. Local host filesystem results do not verify SMB/NFS/Files-provider ACLs or iOS device protection. Network-volume permissions remain controlled by that volume's ACL; no stronger promise is made.

## M3 — Android sender cancellation and expiry

The two cancellation regressions failed against unchanged Android parent production code:20 LAN tests executed,2 timed out (accepted incomplete handshake and a receiver that leaves an8MiB payload unread). The tests explicitly synchronize acceptance and constrain socket buffers; their finally blocks close sockets/workers.

The sender now owns the accepted socket inside the session and runs one daemon watchdog per active session. A monotonic lifetime, explicit stop flag, closed listener or coroutine cancellation closes both listener and accepted socket, interrupting blocking reads/writes. Every exit cancels the watchdog and releases socket ownership. The normal60s session deadline now actually bounds active I/O; successful protocol bytes/roles and framing remain v1.1. A new300ms injected lifetime verifies active-handshake expiry and peer EOF without waiting60s.

Executed serially:

```sh
cd android
ANDROID_HOME=/Users/haydenjiang/Library/Android/sdk \
JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home \
./gradlew --offline :app:testDebugUnitTest --tests com.flash.app.data.LocalBackupTransferTest --console=plain
# After fix:
ANDROID_HOME=/Users/haydenjiang/Library/Android/sdk \
JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home \
./gradlew --offline test assembleDebug :app:assembleDebugAndroidTest --console=plain
```

After: BUILD SUCCESSFUL;78 JVM tests passed in each Debug/Release variant, Debug APK and instrumentation APK built. Release unit tests are not Release app/profile measurements and do not bypass the release-signing guard. Logs: `m3-android-parent-regression.log`, `m3-android-gates.log`; counts read from JUnit XML. Connected Room/device gates still pending. The no-PIN-download, plaintext transport and offline PIN-verifier design flaws remain unresolved pending protocol approval.

## M4 — discovery metadata minimization

All senders now advertise a neutral `Flash Aero-<8hex>` label newly generated per sender/session, rather than personal Mac host name, Android model or a stable platform label. This changes display metadata only; service type, TCP bytes, PIN handling and NetService main-thread resolution stay unchanged. The suffix is a convenience label, not a secret or authenticated identity. mDNS host/address metadata remains observable.

Gates: FlashKit197 passed (includes actual Bonjour discovery), combined host suite269 passed, Harmony native unsigned HAP build successful, Android Debug/Release JVM79 each plus Debug app/test-APK builds successful. Added generated-label shape/rotation checks; these introduce helper/property test seams, so no failing-parent execution is claimed for label tests. Logs: `m4-flashkit.log`, `m4-contract-harmony.log`, `m4-harmony-native.log`, `m4-android-gates.log`.

Fresh macOS baseline app gate was separately run from a disposable `git archive e9a0aa6` copy: **13 app tests passed**, `** TEST SUCCEEDED **`, `m0-macos.xcresult`. The original PR checkout was not built or edited. A cumulative candidate app comparison remains pending until shared fixes settle.

## M5 — Apple import cancellation

An already-cancelled merge/overwrite task previously committed records and rebuilt reminders. The parent production regression executed both modes and failed with6 expectations (no cancellation error, changed snapshot, reminder rebuild). The coordinator now checks cancellation before the synchronous main-actor transaction. Detached preview/export work propagates cancellation to its worker and discards cancelled results. JSONSerialization has no internal interruption hook; the bounded synchronous parse may finish before its result is discarded. No postcommit rollback is promised.

After fix: **199 FlashKit tests passed**, including cancelled preview and unchanged-data/no-reminder guarantees in both import modes. Logs: `m5-cancel-parent.log`, `m5-flashkit.log`. `cancelledPreviewDoesNotProduceAnImportableResult` is additional post-fix coverage; only the two-mode apply regression was run against parent production. macOS/iOS cumulative app gates still pending.

## M6 — preallocation budgets and deterministic mutation coverage

Android/Harmony raw scanners now cap JSON values at10,000,000, matching FlashCore's existing budget before full object-tree allocation. This is separate from128-deep nesting,50MiB and100k-record section limits. Legal schema/record semantics and recovery skip reporting remain unchanged. The contract documentation records the input policy; the backup schema itself was not changed.

Parent regressions failed for both the Android raw scanner and Harmony recovery dense-input case (about20MiB, under file cap). Android's scanner-only test avoids org.json materialization on the unfixed code; Harmony's parent case returned instead of rejecting the budget. No crash/OOM threshold is claimed.

After: Android Debug/Release JVM80 each, app/test APK builds pass; combined contract/Harmony host271 tests pass; native unsigned Harmony HAP builds. The added host mutation test evaluates256 deterministic insert/replace mutations of the shared valid fixture against the existing reference validator. Apple framing test mutates each header position with10 character classes and checks canonical parsing, foreign-nonce rejection and protocol0/2 rejection; FlashKit full suite **200 passed**. This is deterministic parser mutation coverage, not coverage-guided fuzzing or a network appliance stress test.

Logs: `m6-android-budget-parent.log`, `m6-harmony-budget-parent.log`, `m6-android-gates.log`, `m6-contract-harmony.log`, `m6-harmony-native.log`, `m6-flashkit-fuzz.log`.

The cumulative macOS candidate app gate after M5 passed13 app tests, equal to the freshly executed13-test baseline (`m5-macos.log`, `m5-macos.xcresult`). Subsequent shared changes still require a final cumulative gate.

## P1 — profiled UTC normalization candidate

Release baseline at `4e67c13` is retained as JSONL samples/conditions/resources for1k/10k/100k logs. Native `/usr/bin/sample` successfully captured the100k developer workload: the sampled export phase repeatedly enters `BackupService.normalizeISODate` and `NSISO8601DateFormatter.dateFromString`. The attempted xctrace Time Profiler bundle saved but its exported CPU table contains only blocked launch rows; do not claim useful Time Profiler CPU attribution from that trace. The trace hit its15s limit and terminated its synthetic target (exit54/SIGKILL); instrumented runs are excluded from timing tables.

Candidate: compile the same instant regex once; after validating full ASCII syntax, real Gregorian date/year, hour/minute/second ranges and fraction syntax, normalize `Z` timestamps by exact millisecond truncation without redundant Foundation UTC parse/format. Offset timestamps retain the established conversion and UTC year-bound checks. No cache, schema change or validation relaxation was introduced.432 canonical UTC cases plus upper/lower bounds, invalid dates/times, unknown offset, trailing input and offset overflow pass **before and after** the change. Full FlashKit: **201 passed**. Before/after performance and cumulative native gates remain pending at this commit.

## M7 — Android import ownership and atomic overwrite

One generation owns the pending import job and input stream. Cancel/supersession closes the stream, cancels the job and suppresses late results/attachments. Confirmation consumes the preview once, matching Apple's dismissal at confirmation; duplicate taps cannot enqueue the same import. Comparison and replacement now share one Room transaction, returning a stale snapshot for reconfirmation. Committed imports finish reminder rebuilding in a protected postcommit section; an import mutex prevents overlapping import/rebuild sequences. No cancellation promise undoes a completed commit.

Four JVM contracts cover a suspended queued write, stale result/attachment, input-stream closure, and superseded preview ownership. These test a new lifecycle helper; no claim that the new helper API compiles on the parent. Existing transactions/contract tests remain. A native Room regression exercises a local write after preview and subsequent reconfirmation; its APK compiled, execution still pending at this milestone.

Gradle full gate: Debug/Release JVM **84 each passed**, Debug app and instrumentation APK build successful (`m7-android-gates.log`). New helper has no dependencies beyond existing coroutines/JDK and persists no state. Actual malicious provider shutdown and real-device cancellation remain unverified.

## M8 — canonical framing, rejected-answer budgets and receiver lifecycle

Android/Harmony receivers now reject noncanonical zero/leading-zero payload lengths and enforce the unchanged50MiB cap even while draining a rejected answer. Leading-zero regressions failed against parent production on both platforms. Android now has a monotonic total receiver deadline spanning connect/proof/OK/payload/backoff; a daemon timer closes blocked IO, and stop/expiry wakes the backoff latch immediately. Header/deadline tests passed in the first86-test gate; the cumulative gate including backoff cancellation now passes **87 JVM tests each in Debug/Release**, plus Debug app/test APK builds. Combined contract/Harmony host **272 passed**; unsigned native Harmony HAP build succeeded. Logs: `m8-final-android-gates.log`, `m8-host-gates.log`, `m8-harmony-native.log`.

These changes preserve legitimate v1.1 bytes and do not repair F-01 or unauthenticated ERR PIN. The user has now approved temporary legacy LAN disablement, to be implemented in a separate milestone. F-02/F-03 remain compatibility blockers; lossless schema2/additive migration approval is separately recorded, not implemented by M8.

After execution access was restored, cumulative FlashKit **201 passed**, including real host Bonjour discovery, persistence and strict-backup tests. Cumulative macOS native app gate succeeded; the test-count comparison is being extracted from xcresult. The earlier approval-review usage-limit failure did not execute the blocked command and was not bypassed.

## M9 — owner-approved temporary legacy LAN disablement

Owner approved temporary disablement and separately approved scoped schema2/additive migration on2026-10-24. M9 implements only LAN disablement. The three historical transports move unchanged into SwiftPM Tests, Android src/test and Harmony tests/fixtures; none is linked from production application sources. Production facades retain display/state/message data only. Send/receive/direct-connect actions remain idle, clear stale transfer state and explain file export/share. Apple wrappers no longer generate a backup first; Android buttons no longer request nearby-device permission first. No runtime enable switch, listener, discovery, connector or insecure fallback ships. New↔new/new↔old LAN combinations intentionally transfer nothing; no secure v2 implementation is claimed.

Regressions: the new three-action Apple controller test failed on parent production with13 issues; Harmony's two production/controller checks failed on e9a0aa6. After: FlashKit **202 passed**, including unchanged `browserResolvesAdvertisingSender` and its main-RunLoop resolver in the archived fixture; contract/Harmony host **273 passed**. Android Debug/Release JVM **87 each**, Debug app/test APK builds, unsigned Harmony HAP, macOS app tests and iOS generic simulator build-for-testing succeeded. Native Mac remains13 tests (same baseline). Android instrumentation negative/Room and iOS simulator execution are pending at this checkpoint.

APK check: the pre-disable artifact contains `flash-aero-handshake:`/`_flashbackup._tcp` in DEX; both are absent in the candidate APK (`m9-android-artifact-check.json` with hashes). Source/build-boundary inspection and a fresh read-only candidate review found no concrete surviving production LAN route or file-flow regression; that review ran no tests and does not grant independent acceptance. Historical loopback tests now test fixtures, not an exposed transport. Physical-device absence of LAN activity and app UI message delivery remain unverified until the device gates.

Logs: `m9-disable-parent-swift.log`, `m9-disable-parent-harmony.log`, `m9-flashkit.log`, `m9-host-gates.log`, `m9-android-gates.log`, `m9-harmony-native.log`, `m9-macos.log`/xcresult, `m9-ios-build.log`. No permissions/entitlements/signing/deployment/store/schema/credential change is in M9.

### M9 native follow-up

The retained pre-disable APK failed the new Android application-action regression (1test/1failure). With the same instrumentation APK, the candidate passed all10 native tests on the dedicated API36/Android16 emulator. iOS passed14 app tests on the task-owned iPhone18 Pro/iOS27.0 simulator; macOS remains13 passed. These are simulator/emulator results. The native Android settings UI displayed the disabled explanation and file-export guidance without a nearby-device prompt. Its screenshot exposed stale trusted-LAN wording in the settings summary/footer; the follow-up corrects those strings on Android/Harmony and the shared Apple footer. The archived Swift fixture's extra EOF blank line is removed without algorithm changes.

## M10 — approved Android schema2 / additive Room4→5

Models/entities/mappers now preserve nullable favorites, emotion intensity and soft task source links. Readers accept section1/2 independently and keep unknown versions/fields/type/range/UUID rejection; section1 cannot smuggle schema2 fields. Writers emit the existing schema2. The five nullable columns are added without replacing tables, indexes, read-state, store location or credentials; production registers the existing1→2→3→4 chain plus4→5. Old exported Room schemas3/4 remain alongside generated5. No destructive downgrade.

Before: new compatibility tests ran against the unchanged old codec (3tests,2failures); an actual Apple exporter artifact was rejected. After: Debug/Release JVM **91 each passed**, app/test APK builds passed. The old writer test's schema1 expectation was updated to the owner-approved schema2 output; other contract assertions remain.

Native API36/Android16: **12pass,1intentional manual-probe assumption skip** in the13-test suite. Populated4→5 retains content/read timestamps and NULL defaults; new true/false/intensity/dangling-link values survive save/close/reopen/re-export. Injecting failure after all additive DDL rolls back the schema columns, version4 and original records/read-state. Existing1/2→current migration chains and historical3→4 gate pass. Physical power-loss behavior is not verified.

An explicit write invocation consumed the actual2,639-byte Apple production export into a separate fictional Room store. After `am force-stop`, a second read invocation verified every model field plus read-state, then exported schema2 through the production Android writer. Both phases passed1test each. Output2,564bytes, SHA256 `4fe48730cbbc3a14f15c2aa584b70a34442adc95b2de31173b6347e375b5951e`. This verifies a real emulator process boundary, not a physical-device or file-picker UI import.

Logs: `m10-schema2-parent-android.log`/XML, `m10-android-gates.log`, `m10-android-instrumentation.log`, `m10-android-process-write.log`, `m10-android-process-read.log`. The initial unchanged Apple artifact and provenance are checked into androidTest assets; they are fictional production-exporter output, not real user data.

## M11 — Harmony schema2 payload preservation

Harmony models/strict+recovery codec accept section1/2 independently and preserve the same optional metadata. The existing id/sort_key/payload RDB schema is unchanged; no SQL migration or credential change. Normalizers preserve false distinctly from missing/null. Ordinary body/category/tag/batch edits and task editor/completion now carry imported metadata forward. Future versions, unknown fields, malformed types/ranges/links and schema1-with-schema2-fields still reject.

Parent focused host gate:4tests,3failures/1pass. Candidate: **278 contract/Harmony host tests passed**, including actual Apple-export bytes, payload reload through a new store instance with explicit RDB fakes, ordinary edits and retained read-state. Unsigned native HAP build passed. These fakes are not native RDB/save-relaunch proof; no Harmony device is attached.

Actual-export component checks now pass Apple→Android emulator (above), Android emulator export→Apple native macOS codec, Apple export→Harmony codec on Node, Harmony exporter→Apple codec, and Android export→Harmony codec. Each consumer compares incoming schema2 metadata directly against re-exported bytes, plus model round-trip equality, rather than counts alone. All preserve2logs/2emotions/2tasks. Raw `interop-*.json` records input/output hashes. Native iOS app file-picker, installed Harmony imports, physical devices and remaining matrix tiers stay unverified; LAN combinations intentionally remain disabled.

## M12 — native timezone validation and IANA rename aliases

The baseline actual-codec probes rejected modern Kyiv/Kolkata while each available native host database accepted them. The candidate generates naming/alias facts from pinned public-domain IANA sources, preserving all420 previously accepted identifiers (439 total), then requires native rules. It preserves the wire spelling while resolving safe aliases for validation/calendar/editor/card/forms. Historical Zone distinctions use backzone; unknown/case/offset/abbreviation rejection stays. A known-but-unsupported zone fails strict/recovery before preview/write with an update-system message. No stored zone/timestamp/schema migration or library addition.

Gates: generator `--check` passed; FlashKit **204 passed**; contract/Harmony **282 passed**; Android Debug/Release JVM **93 each passed**, app/test APK builds passed; unsigned Harmony native HAP passed; macOS behavior gate **13 passed**, unchanged count. iOS generic test build passed; the first native14-test run had an unrelated equal-timestamp fixture failure, corrected in test-only `0aee15a` with all assertions retained, then **14 passed**. See test-determinism.md; no production reminder changes.

Dedicated API36/Android16 emulator native suite: **13 passed,1 intentional manual-process assumption skip**,14 reported. New timezone test exercises native rules at1900, spring/autumn DST boundaries2026 and2050 for modern/legacy pairs, and actual Apple input→parse→export spelling. Both named-zone variants retain metadata/models. Simulated old-OS helper tests verify fallback/no-GMT/no-neighbor-city substitution; these are not actual oldest-OS/device runs. Raw logs: `m12-flashkit.log`, `m12-host-final.log`, `m12-android.log`, `m12-harmony-native.log`, `m12-macos-final.log`, `m12-ios-build.log`, `m12-ios-tests.log`, `t1-ios-tests.log`, `m12-android-native.log`.

The original implementation worktree became read-only after the workspace changed. Continuation is the separate `codex/hardening-continuation` worktree, append-only from `4d28844`; the approved e9a0aa6 base and all earlier commits remain ancestors. No amend/rebase/force-push, original checkout change, merge or release.

## M13 — actual Harmony→Android native and chained Apple persistence

The explicit process probe now selects only the recorded Apple/Harmony assets and separates their fictional stores. Actual Harmony exporter bytes (`cab692...893b`) passed native API36 production parser/Room write, force-stop, independent read, all model/read-state checks and re-export. Both phases passed1test; output SHA256 `db02cd6df7a5e2446401987be4087e072a72ca27a450c0a23c848ea819aa3c6d`. That exact output then passed the current Release-built native Apple production codec and separate SwiftData/repository/read-state write/read processes in a new scratch store. Native Android tzdata2025a was recorded, distinct from the pinned2026e naming facts and host Intl2026b rules.

Current Gradle Release-built Kotlin codec on host JDK also accepts modern zones and actual Harmony bytes; direct incoming metadata and full model round-trip equality pass. The earlier `interop-harmony-to-android-jvm.json` is pre-timezone historical evidence and correctly reports modern-name rejection there; `m13-current-android-jvm-probe.json` is the new candidate result. [Committed inputs, receipts and hashes](evidence/compatibility/manifest.json) and [reproduction tools](../../tools/verification/README.md) distinguish each tier. No installed-app file picker, physical device or Harmony native RDB acceptance is claimed.
