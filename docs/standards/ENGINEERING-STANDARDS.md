# Engineering standards — principles, compatibility and versioning

> **Status: Proposed — not ratified.** See [README.md](README.md) for rule levels and labels.

> **中文摘要**：本文是总纲。规定工程原则与“事实来源”的优先级，核实并固定四端最低系统版本（Android API 26、iOS 18、macOS 15、HarmonyOS 5.0/API 12，未经所有者批准不得更改），规定工具链、API 可用性保护、依赖与锁文件、版本号与发布策略，并汇总所有需要所有者决定的事项（OD-01 至 OD-16）。

## 1. Current state

| Observation | Evidence |
| --- | --- |
| `main` is behind three unmerged lines that conflict with each other in 39–53 files. Security fixes, schema 2 interop and all localization are not on `main`. | Verified ([2026-11-11 review §0](../review/2026-11-11-architecture-debt-risk.md)) |
| No `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING`, `CODEOWNERS`, `SECURITY.md` or `CHANGELOG` exists on any branch. ROADMAP refers to a root `CHANGELOG` that is kept outside the repository. | Verified (`git ls-tree` on six refs) |
| The only lint configuration is `harmonyos/code-linter.json5`. No SwiftLint, SwiftFormat, ktlint, detekt or `.editorconfig`. | Verified |
| Lockfiles: `scripts/backup-contract/package-lock.json` only. No Gradle lockfile or verification metadata. FlashKit and HarmonyOS have no third-party dependencies, so nothing to lock. | Verified |
| Android has a version catalog (`android/gradle/libs.versions.toml`). The Gradle wrapper checksum is pinned on `feat/paper-writing` and not on `main`. | Verified |
| CI actions are pinned to commit SHAs. | Verified (`.github/workflows/backup-contract.yml`) |
| Engineering principles are stated in `ROADMAP.md` ("工程原则") and the September plan §4.1 and §10. These standards keep them. | Verified |
| Xcode requirement is stated three ways: README "Xcode 26", the workflow comment "Xcode 27 (Swift 6.2)", and the hardening handoff "Xcode-beta 27.2 / Swift 6.4". | Verified |

## 2. Principles

| ID | Level | Rule | Enforcement |
| --- | --- | --- | --- |
| FS-GEN-01 | MUST | Flash is local-first. No change may introduce an account, a server dependency, analytics or telemetry without an owner decision. | Manual |
| FS-GEN-02 | MUST | Behaviour that must be identical on all platforms is defined once, in a language-neutral artefact (schema, fixture, catalog, token file), and each platform proves conformance with tests. See [CROSS-PLATFORM-ARCHITECTURE.md](CROSS-PLATFORM-ARCHITECTURE.md). | Partly Enforced (backup contract) |
| FS-GEN-03 | MUST | A claim of "passes", "verified" or "supported" names the evidence tier it was observed at: static reading, host test, native build, simulator or emulator, physical device. A lower tier never stands in for a higher one. | Manual |
| FS-GEN-04 | MUST | Data is never silently dropped, truncated or rewritten. A record the app cannot represent is rejected with a visible reason or preserved in quarantine. | Partly Enforced (contract fixtures) |
| FS-GEN-05 | MUST | One change does one kind of thing. A database migration, a UI redesign and a protocol change do not share a commit. (September plan §10.) | Manual |
| FS-GEN-06 | SHOULD | Prefer the platform's native framework and idiom over a cross-platform abstraction, unless the behaviour falls under FS-GEN-02. | Manual |
| FS-GEN-07 | MUST | Documentation that states current behaviour is updated in the same PR as the behaviour. A status line carries a date and a commit. | Manual |
| FS-GEN-08 | MUST | Every source file keeps the MPL-2.0 header used across the repository. | Planned (header check) |

**Rationale.** FS-GEN-02 to -04 are the existing strengths of the project (contract fixtures, evidence tiers, strict import). The failures found by the audits (F-02, F-03, F-09, F-23) all occurred where one of them was not applied.

## 3. Sources of truth

When two artefacts disagree, the higher row wins and the lower one is a defect.

| Rank | Artefact | Governs |
| --- | --- | --- |
| 1 | `docs/contracts/flash-backup-v2.schema.json` and `docs/contracts/fixtures/` | Backup wire format and accept/reject behaviour |
| 2 | `docs/contracts/README.md`, `time-zones.md` (candidate), LAN specification | Semantics not expressible in JSON Schema |
| 3 | Generated-constant sources: `scripts/backup-contract/canonical-timezones.json`, `docs/i18n/` (candidate), `docs/design/paper-tokens.json` (candidate), `assets/brand/flash-standard-icon.png` | Values copied into more than one platform |
| 4 | `docs/standards/` | Engineering rules |
| 5 | Platform READMEs, ROADMAP | Description of state |
| 6 | Agent instruction files | Tool mechanics only; never override ranks 1–4 |

| ID | Level | Rule | Enforcement |
| --- | --- | --- | --- |
| FS-GEN-09 | MUST | A file generated from a rank 1–3 source carries a "generated, do not edit" header naming its generator, and the generator has a `--check` mode that fails when output is stale. | Enforced for `generate-cases.cjs`; Enforced-candidate elsewhere; see [BUILD-TEST-CI-STANDARD.md](BUILD-TEST-CI-STANDARD.md) |
| FS-GEN-10 | MUST | Evidence that a document relies on is either committed (small text: manifests, hashes, logs) or referenced by a content hash. Paths on a developer's machine are not evidence. | Manual |

## 4. Platform and toolchain compatibility

### 4.1 Verified baseline

| Platform | Minimum | Target / compile | Declared in | Evidence |
| --- | --- | --- | --- | --- |
| Android | API 26 | compile 36, target 36 | `android/app/build.gradle.kts` | Verified |
| iOS | 18.0 | built with Xcode 27 beta SDK | `ios/Flash.xcodeproj` (`IPHONEOS_DEPLOYMENT_TARGET`) | Verified |
| macOS | 15.0 | built with Xcode 27 beta SDK | `macos/Flash.xcodeproj` (`MACOSX_DEPLOYMENT_TARGET`) | Verified |
| FlashKit | macOS 15, iOS 18 | swift-tools 6.0, Swift 6 language mode | `shared/FlashKit/Package.swift` | Verified |
| HarmonyOS | 5.0.0 (API 12) | target 26.0.0 | `harmonyos/build-profile.json5` | Verified |

Toolchain in use (Verified from manifests unless noted): JDK 17, Gradle 8.14.3, AGP 8.11.1, Kotlin 2.2.0, KSP 2.2.0-2.0.2, Compose BOM 2025.06.01, Room 2.7.2; Node 22 in CI; DevEco Studio 6.0.2 (README); Xcode version inconsistent (see §1).

### 4.2 Rules

| ID | Level | Rule | Enforcement |
| --- | --- | --- | --- |
| FS-PLAT-01 | MUST | The minimum versions in §4.1 do not change without an owner decision recorded in the PR, a README update and a release note. | Planned (CI asserts the declared values) |
| FS-PLAT-02 | MUST | Every use of an API newer than the platform minimum is guarded: `Build.VERSION.SDK_INT` on Android, `#available` / `@available` on Apple, `canIUse` or a runtime capability check on HarmonyOS. The fallback path is a designed behaviour, not a crash or an empty view. | Android: Planned (lint `NewApi` as error). Apple: compiler. HarmonyOS: Manual |
| FS-PLAT-03 | MUST | A capability that needs store review, special entitlement or hardware (HarmonyOS Live View, tap-to-share, intents; Apple App Groups) has no visible entry point until it works end to end. Probes are allowed. (Existing HarmonyOS practice.) | Manual |
| FS-PLAT-04 | MUST | One file, `docs/standards/TOOLCHAIN.md` or a machine-readable equivalent, states the exact supported Xcode, Swift, JDK, Gradle, AGP, Kotlin, Node and DevEco versions. READMEs and CI refer to it instead of restating versions. | Planned |
| FS-PLAT-05 | MUST | A release is built with a released (non-beta) toolchain, or the release notes state the beta toolchain and build number. | Manual |
| FS-PLAT-06 | SHOULD | The project builds with one toolchain version at a time. A toolchain bump is its own PR and re-runs every CI tier. | Manual |
| FS-PLAT-07 | MUST | Swift code compiles in Swift 6 language mode with strict concurrency. New `nonisolated(unsafe)`, `@unchecked Sendable` or `@preconcurrency` needs a comment stating the invariant that makes it safe. | Compiler; comment Manual |
| FS-PLAT-08 | MUST | HarmonyOS code stays within the state-management generation already in use (V1) inside a module. Mixing V1 and V2 decorators in one component tree is not allowed; a migration is a planned change. | Manual |
| FS-PLAT-09 | MUST | Old-OS fallbacks that exist in code are exercised before release at the lowest supported OS for that platform, at simulator or emulator tier at least. Today none are (I-08, H-08). | Manual; see matrix §4.3 |

**Rationale.** The minimums are already consistent across manifests and READMEs; the risk is silent drift and unexercised fallback branches. HarmonyOS spans API 12 to 26 with every newer call behind `canIUse`, which means each guard is an untested branch on old devices (H-08, Inherited).

### 4.3 Compatibility test matrix (required before a release)

| Platform | Lowest supported OS | Current OS | Form factors | Tier required | Status today |
| --- | --- | --- | --- | --- | --- |
| Android | API 26 emulator | API 36 emulator and one physical phone | phone, ≥ 600 dp | emulator + device | API 36 emulator only (Verified, CI) |
| iOS | iOS 18 simulator | current simulator and one physical iPhone | iPhone | simulator + device | Current simulator only, local (Inherited) |
| macOS | macOS 15 | current macOS | Apple silicon; Intel if the x86_64 slice ships | native run | Apple silicon only (Inherited) |
| HarmonyOS | API 12 device or emulator | API 26 device | phone, foldable, tablet | device | None (Inherited: no device has run the app) |

A cell that cannot be run is recorded as "not verified" in the release record. It is not left blank and not marked passed.

## 5. Dependencies

| ID | Level | Rule | Enforcement |
| --- | --- | --- | --- |
| FS-PLAT-10 | MUST | Adding or upgrading a runtime dependency, SDK, Gradle plugin, GitHub Action or build tool needs owner approval in the PR. Agents never install or add one on their own initiative. | Manual |
| FS-PLAT-11 | MUST | Android versions live only in `libs.versions.toml`. No dynamic versions (`+`, `latest.release`), no snapshot repositories. | Planned (grep check) |
| FS-PLAT-12 | MUST | The Gradle wrapper pins `distributionSha256Sum`. | Enforced-candidate (`feat/paper-writing` `a6b6099`) |
| FS-PLAT-13 | SHOULD | Android adopts Gradle dependency verification metadata or dependency locking, so that the optional local mirror in `settings.gradle.kts` cannot substitute artefacts. | Planned |
| FS-PLAT-14 | MUST | Node tooling installs with `npm ci --ignore-scripts` from a committed lockfile. | Enforced |
| FS-PLAT-15 | MUST | FlashKit and HarmonyOS stay free of third-party runtime dependencies unless an owner decision says otherwise. If one is added, `Package.resolved` or `oh-package-lock.json5` is committed. | Manual |
| FS-PLAT-16 | MUST | GitHub Actions are referenced by full commit SHA with the version in a comment. | Manual (already the practice) |
| FS-PLAT-17 | MUST | Cryptographic code comes from the platform (CryptoKit, `javax.crypto`, `cryptoFramework`) or a reviewed, maintained library approved under FS-PLAT-10. No hand-written primitives or protocols. | Manual |

## 6. Versioning and release

Current state (Verified): marketing version `0.1.0` on all four platforms; build numbers Android `versionCode 1`, HarmonyOS `versionCode 1`, iOS `1`, macOS `2`; Room schema 4 on `main`, 5 on both hardening lines; SwiftData schema V2; backup section schemas 1 (Android, HarmonyOS on `main`) and 2 (Apple).

| ID | Level | Rule | Enforcement |
| --- | --- | --- | --- |
| FS-PLAT-18 | MUST | The four apps share one marketing version `MAJOR.MINOR.PATCH`. It is stored once and propagated; a mismatch fails CI. | Planned |
| FS-PLAT-19 | MUST | Each platform's build number increases with every build that leaves the developer's machine. A build that contains a database migration always has a higher build number than any build without it. | Manual |
| FS-PLAT-20 | MUST | Four version axes are kept separate and never inferred from one another: app marketing version, local database schema version (per platform), backup envelope version (`flash-backup-v2`), backup section schema version (per section). `appVersion` in a backup is informational and is never used to select parsing behaviour. | Partly Enforced (contract tests) |
| FS-PLAT-21 | MUST | A release is cut from a protected branch at a tagged commit, with a release record: commit, toolchain versions, per-artefact SHA-256, signing identity fingerprint, and the compatibility matrix of §4.3 with real results. | Manual; see [BUILD-TEST-CI-STANDARD.md §7](BUILD-TEST-CI-STANDARD.md#7-release-readiness-gate) |
| FS-PLAT-22 | MUST | Binaries are not committed to the repository. Historical binaries are not redistributed as current. | Manual |
| FS-PLAT-23 | SHOULD | A root `CHANGELOG.md` is kept in the repository, one entry per merged PR, so that the record does not depend on a file outside Git. | Manual |

**Migration impact.** FS-PLAT-18/19 need a small version file and a CI assertion; no source change. FS-PLAT-12 lands with the hardening line. FS-PLAT-04 is a new short document that removes three inconsistent statements.

**Verification.** `git grep` for the declared minimums in the four manifests; CI assertion once added; release record review.

**Exceptions.** FS-PLAT-01, -10 and -21 can only be waived by the owner.

## 7. Owner decisions

These are open. The standards do not resolve them; where a recommendation is given it is marked as such.

| ID | Decision | Recommendation (Proposed) | Blocks |
| --- | --- | --- | --- |
| OD-01 | Which line becomes the integration base | `feat/paper-writing`: it is the superset and merges into `main` without conflict | Everything in the roadmap after P1-01 |
| OD-02 | What happens to `fix/pr3-review-followups` and PR #5 | Port the fixes that exist only on the former (at least F-05, F-08, F-09, F-23; compare commit by commit); rebase PR #5 onto the base | P0 |
| OD-03 | Ratify these standards, in whole or by document | — | Enforcement |
| OD-04 | LAN transfer: stay disabled, or approve a replacement protocol and its crypto dependency | Stay disabled until a reviewed PAKE or ephemeral-key-plus-SAS design is approved | Any LAN work |
| OD-05 | Signing identities: Android upload key, Apple team and Developer ID, HarmonyOS certificate and profile | — | Any distribution; device testing on iOS and HarmonyOS |
| OD-06 | Whether macOS is localized, and when | Yes, after the key migration (see [LOCALIZATION-STANDARD.md §8](LOCALIZATION-STANDARD.md#8-migration-path)) | P2 |
| OD-07 | Shipping language set and named native reviewers per language | Ship only languages with a recorded review | P2 release |
| OD-08 | Display digits in Arabic and other locales with native digits | Locale digits in prose, ASCII in data | P2 |
| OD-09 | Behaviour for Traditional Chinese locales (currently resolved by the `zh` table on Android and HarmonyOS) | Explicit decision; do not leave to resolver defaults | P2 |
| OD-10 | App-level encryption at rest on Android and Apple, beyond OS disk encryption | Keep OS protection; set explicit iOS file protection class | Security doc §3 |
| OD-11 | Rewrite history to remove the burned Android keystore, or keep it and rely on the voiding statement | Keep history; add a CI check that no release is ever signed by that fingerprint | P0 |
| OD-12 | Branch protection or ruleset on `main`, and the required-check list | Adopt [BUILD-TEST-CI-STANDARD.md §6](BUILD-TEST-CI-STANDARD.md#6-required-checks-and-branch-rules) | P1 |
| OD-13 | Where HarmonyOS builds run: self-hosted runner, or a recorded manual gate | Recorded manual gate now; runner later | P1 |
| OD-14 | Adopt root `AGENTS.md` / `CLAUDE.md` after comparing the drafts with the workspace-level `AGENTS.md` | — | Agent workflow |
| OD-15 | Whether the x86_64 macOS slice is supported or dropped | Drop unless an Intel machine is available for testing | Release |
| OD-16 | OS-level backup policy on Apple and HarmonyOS (Android already sets `allowBackup=false`) | Explicit statement per platform | Security doc §3 |
