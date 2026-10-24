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
