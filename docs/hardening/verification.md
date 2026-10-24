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
