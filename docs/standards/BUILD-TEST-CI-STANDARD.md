# Build, test and CI/CD standard

> **Status: Proposed — not ratified.** See [README.md](README.md) for rule levels and labels.

> **中文摘要**：当前只有一个工作流（四个作业），在所有分支上内容完全相同。它覆盖契约校验、HarmonyOS 主机测试、Android 单元与模拟器测试，以及 macOS 应用的 13 个测试；FlashKit 的 194 个测试、iOS、Android Release 构建、HarmonyOS 原生构建、本地化与图标生成检查均未覆盖，也没有任何签名校验。本文给出目标 CI 结构，按运行条件分三层：GitHub 托管 Linux、GitHub 托管 macOS、需要授权工具链/签名/真机的环节。没有真实构建或测试结果，不得声称某平台“已验证”。

## 1. Current state

### 1.1 Workflow audit (Verified)

`.github/workflows/backup-contract.yml` is the only workflow and is byte-identical on `main`, `feat/paper-writing`, `fix/pr3-review-followups`, PR #5 and `codex/ios-integrated-candidate`. Triggers: `pull_request`, `push` to `main`/`master`, `workflow_dispatch`. Permissions: `contents: read`. Actions pinned by SHA.

| Job | Runner | What it runs | What it proves |
| --- | --- | --- | --- |
| `schema-and-harmony-host` | `ubuntu-latest` | `generate-cases.cjs --check`; `node --test` on the contract tests and `harmonyos/tests/*.test.cjs` | Schema, fixtures, reference validator; HarmonyOS business logic transpiled from `.ets` with fakes for every platform API |
| `android` | `ubuntu-latest` | `:app:testDebugUnitTest :app:assembleDebugAndroidTest` | JVM unit tests; that the instrumentation APK compiles |
| `android-database` | `ubuntu-latest` + KVM, API 35 emulator | `:app:connectedDebugAndroidTest` | Room migrations, transactional import, fixtures on the device JSON implementation |
| `macos` | label `xcode-27` | `xcodebuild test -scheme Flash` in `macos/` | The macOS app builds; `FlashTests` (13 tests) pass |

The last run on `main` (run 42608755294, 2026-11-09) shows all four jobs succeeding; the `macos` job ran on a GitHub-hosted runner under the `xcode-27` label.

### 1.2 Gaps (Verified against workflow, schemes and tree)

| Gap | Detail |
| --- | --- |
| FlashKit tests not run | 194 `@Test` on `main` (backup contract, repository, schema migration, LAN, domain). The macOS scheme's only testable is `FlashTests`; no job calls `swift test`. On `feat/paper-writing` the package reports 244 (Inherited). |
| No iOS job | Neither build nor test. `ios/FlashTests` has 14 tests on `main`. |
| No Android release build | `isMinifyEnabled = true` for release; R8 output is never produced in CI. No Android Lint run. |
| No HarmonyOS native build | hvigor is never invoked; ArkTS compiler errors, ArkUI wiring and release obfuscation are unchecked. |
| Generators not checked | `tools/i18n/generate.py --check`, `generate-timezones.py --check`, `generate_app_icons.py --check`, `check-lan-quarantine.py` exist on branches and run nowhere. |
| No signing verification | No job inspects a signed artefact. No release workflow exists. |
| No static analysis | No formatter or linter in CI on any platform; no secret scan; no dependency review. |
| Workflow name | "Backup contract" no longer describes what it gates. |
| Branch protection | `docs/contracts/acceptance.md` says the checks are required on `main`. The branches API returns `protected: false` for `main`. Whether a ruleset exists could not be determined from here. |

### 1.3 Test inventory on `main` (Verified by counting declarations; not run except where stated)

| Suite | Count | In CI | Run for this work |
| --- | ---: | --- | --- |
| Contract + HarmonyOS host (Node) | 265 at runtime | Yes | Yes, 265 pass |
| Android JVM | 75 `@Test` | Yes | No (no Android SDK here) |
| Android instrumented | 8 `@Test` | Yes | No |
| FlashKit | 194 `@Test` | **No** | No (no Swift toolchain here) |
| macOS app | 13 `@Test` | Yes | No |
| iOS app | 14 `@Test` | **No** | No |

## 2. Principles

| ID | Level | Rule | Enforcement |
| --- | --- | --- | --- |
| FS-CI-01 | MUST | A platform is described as built, tested or validated only for the tier a recorded run actually reached: host, native build, simulator/emulator, device, signed artefact. | Manual |
| FS-CI-02 | MUST | Every test target in the repository is run by some CI job, or is listed in this document with the reason it is not. | Planned |
| FS-CI-03 | MUST | A test is never skipped, disabled or deleted to make CI pass. A quarantined flaky test is tracked with an owner and a date. | Manual |
| FS-CI-04 | MUST | CI commands are the same commands a contributor runs locally, documented in one place. | Manual |
| FS-CI-05 | MUST | Workflows declare least-privilege `permissions`, pin actions by SHA, and do not expose secrets to `pull_request` runs from forks. | Partly Enforced (present in the existing workflow) |
| FS-CI-06 | SHOULD | Jobs are path-filtered so that a docs-only change does not consume macOS minutes, while required checks still report a result. | Planned |

## 3. Target job graph

### Tier A — GitHub-hosted Linux (no licence, no secrets)

| Job | Purpose | Status |
| --- | --- | --- |
| `contract` | Schema, fixtures, reference validator, `generate-cases --check` | Exists |
| `harmony-host` | HarmonyOS logic on Node with fakes | Exists (same job today; SHOULD be split for clearer failures) |
| `generated-check` | `generate.py --check` (i18n), `generate-timezones.py --check`, `generate_app_icons.py --check`, token check | Planned; scripts exist on branches. Icon check needs Pillow, a new CI dependency (FS-PLAT-10) |
| `static-gates` | LAN quarantine gate; manifest and entitlement snapshot; minimum-version and bundle-ID assertions; MPL header check; unrouted-literal scan; Markdown link check | Planned |
| `secret-scan` | Scan tree and PR diff for credentials and key material; deny-listed keystore hash | Planned; tool choice needs approval |
| `android-unit` | `:app:testDebugUnitTest` | Exists |
| `android-lint` | `:app:lintDebug` with `NewApi`, `MissingTranslation` as errors | Planned |
| `android-release` | `:app:assembleRelease` signed with a throwaway keystore generated inside the job; then inspect the APK: not debuggable, `allowBackup=false`, expected permissions, R8 mapping produced; run a release-variant round trip of the backup fixtures | Planned |
| `android-emulator` | `:app:connectedDebugAndroidTest`, API 35/36; SHOULD add API 26 | Exists (one API level) |
| `dependency-review` | Flag new or changed dependencies and actions in a PR | Planned |

### Tier B — GitHub-hosted macOS (Xcode image; billed at a higher rate)

| Job | Purpose | Status |
| --- | --- | --- |
| `flashkit` | `swift test` in `shared/FlashKit`; `xcodebuild -scheme FlashKit-Package` for iOS Simulator | Planned — highest-value missing job |
| `macos-app` | `xcodebuild test -scheme Flash` (app + widget) | Exists |
| `ios-app` | `build-for-testing` for app, widget and extensions, then `test` on a simulator | Planned |
| `apple-static` | Formatter/linter if adopted (FS-CI-10) | Planned |

Dependency: these jobs rely on the `xcode-27` runner label continuing to provide the toolchain the code needs. It worked on 2026-11-09. It is a beta image; FS-PLAT-04 and FS-PLAT-05 apply.

### Tier C — needs something GitHub-hosted runners do not provide

| Check | Needs | Proposed handling |
| --- | --- | --- |
| HarmonyOS debug and release HAP (`hvigorw assembleHap`), ArkTS lint (`code-linter.json5`) | DevEco command-line tools and HarmonyOS SDK. Whether these can be installed and licensed on a hosted Linux runner was **not verified**. | Self-hosted runner, or a recorded manual gate run by the owner before merge of HarmonyOS changes and before release (OD-13) |
| HarmonyOS release-export validation (FS-DATA-17) | A release HAP plus a device or emulator | Recorded manual gate |
| Signed Android bundle; `apksigner verify --print-certs`; fingerprint not deny-listed | Upload key in a protected environment | Release workflow, manual dispatch, owner approval |
| Signed and notarised macOS app; `codesign --verify --deep --strict`, `spctl -a`, stapler check | Developer ID certificate, notary credentials | Release workflow |
| Signed iOS archive; provisioning with App Group | Apple team, distribution certificate | Release workflow |
| Signed HAP; signature verification with the HarmonyOS signing tool | Huawei certificate and profile | Manual gate until a runner exists |
| Device matrix ([ENGINEERING-STANDARDS.md §4.3](ENGINEERING-STANDARDS.md#43-compatibility-test-matrix-required-before-a-release)), accessibility passes, installed-app transfer matrix, reminder timing | Physical devices and a person | Manual, recorded as evidence |
| UI smoke tests | Android: emulator (Tier A capable). iOS: simulator (Tier B capable). macOS, HarmonyOS: not available hosted | Planned for Android and iOS; Manual elsewhere |

## 4. Rules by area

| ID | Level | Rule | Enforcement |
| --- | --- | --- | --- |
| FS-CI-07 | MUST | FlashKit's package tests run on every PR that touches `shared/`, `ios/` or `macos/`. | Planned |
| FS-CI-08 | MUST | iOS builds for testing and runs its unit tests on a simulator on every PR that touches `shared/` or `ios/`. | Planned |
| FS-CI-09 | MUST | Android builds the release variant with minification on every PR that touches `android/`, and the built artefact is inspected (FS-SEC-11). | Planned |
| FS-CI-10 | SHOULD | Formatting and lint are adopted one platform at a time, each as its own PR that includes the one-off reformat: Android Lint first (bundled), then ktlint or detekt, SwiftFormat or SwiftLint, and the existing HarmonyOS `code-linter.json5`. Each tool is a new dependency (FS-PLAT-10). Until adopted, style is review-only. | Planned |
| FS-CI-11 | MUST | Every generator's `--check` runs in CI (FS-GEN-09). | Planned |
| FS-CI-12 | MUST | Contract fixtures are consumed by all four codecs in CI (FS-DATA-18). | Three of four today |
| FS-CI-13 | MUST | Database migration tests from every released schema run in CI for Android and Apple. | Android: Enforced. Apple: Planned (comes with FS-CI-07) |
| FS-CI-14 | MUST | A HarmonyOS change is not merged without a native build result, from a runner or from a recorded manual run with commit hash and tool version. | Manual |
| FS-CI-15 | SHOULD | UI smoke tests cover launch, create a record, edit, export, strict import, on Android (emulator) and iOS (simulator). | Planned |
| FS-CI-16 | MUST | Release artefacts are produced only by the release workflow from a tagged commit, with SHA-256 for each artefact, the signing certificate fingerprint, and the toolchain versions written to the release record. Locally built artefacts are not released. | Planned |
| FS-CI-17 | SHOULD | Release artefacts carry build provenance attestation where the platform supports it. | Planned |
| FS-CI-18 | MUST | Dependency and action changes are surfaced on every PR; known-vulnerable dependencies block merge. | Planned |
| FS-CI-19 | MUST | CI logs never print secrets, backup contents or real user data; test data is synthetic (FS-NAME-35). | Manual |
| FS-CI-20 | SHOULD | Flaky tests are fixed at the cause. Time-dependent tests take an injected clock; ordering-dependent fixtures are made deterministic (precedent: `0aee15a`). | Manual |

**Rationale.** The failures the audits found on Apple platforms (F-02, F-03, F-09) sit in code whose tests exist and are simply not executed remotely. Adding `flashkit` and `ios-app` costs two short jobs and turns 208 existing tests into gates.

## 5. Evidence records

| ID | Level | Rule |
| --- | --- | --- |
| FS-CI-21 | MUST | A manual gate leaves a record committed under `docs/evidence/<yyyy-mm-dd>-<topic>/manifest.json`: commit, who ran it, tool and OS versions, device model, commands, result per item, SHA-256 of any artefact or screenshot stored outside Git. |
| FS-CI-22 | MUST | Test counts quoted in documents state the commit and the counting method (declarations versus executed cases). |
| FS-CI-23 | MUST | "Not run" and "not verified" are written out. A blank cell is not allowed in an acceptance table. |

Enforcement for this section: Manual.

## 6. Required checks and branch rules

Proposed for `main` and any long-lived integration branch (OD-12):

| Setting | Value |
| --- | --- |
| Direct pushes | Blocked for everyone, including the owner's automation and all agents |
| Pull request required | Yes; at least one approving review from someone other than the author (for an agent-authored PR, a human) |
| Required checks, stage 1 (exist today) | `schema-and-harmony-host`, `android`, `android-database`, `macos` |
| Required checks, stage 2 (after P1) | add `flashkit`, `ios-app`, `android-release`, `generated-check`, `static-gates`, `secret-scan` |
| Branch must be up to date | Yes |
| Force push, deletion | Blocked |
| Linear history | SHOULD; merge commits are acceptable where they preserve reviewed milestones |
| Tags `v*` | Protected; created only by the release workflow |
| Release environment | Requires owner approval; holds signing secrets |

| ID | Level | Rule | Enforcement |
| --- | --- | --- | --- |
| FS-CI-24 | MUST | `main` is protected by a ruleset with the settings above. | Undecided (OD-12); current state unverified |
| FS-CI-25 | MUST | A required check that is path-filtered still reports success when skipped, so that it cannot block or be bypassed by accident. | Planned |
| FS-CI-26 | MUST | The list of required checks in repository settings matches this section; a change to one changes the other in the same PR. | Manual |

## 7. Release readiness gate

A release candidate is ready when all of these are recorded for the tagged commit:

1. All required checks green.
2. Every `RB-nn` item in [SECURITY-AND-DATA-CONTRACT.md §6](SECURITY-AND-DATA-CONTRACT.md#6-release-blocking-criteria) is "pass" with its evidence tier, or carries an owner waiver.
3. Tier C checks for each shipping platform have records (FS-CI-21).
4. The compatibility matrix has a result or "not verified" in every cell, and the owner has accepted the "not verified" cells in writing.
5. The installed-app backup matrix (FS-DATA-22) is recorded for the shipping platforms.
6. Shipping languages meet FS-L10N-32.
7. Version numbers satisfy FS-PLAT-18/19; README, ROADMAP, CHANGELOG and release notes match the artefacts.
8. Artefact hashes, signing fingerprints and toolchain versions are in the release record.

## 8. Platform considerations

- **Android.** The emulator job already works with KVM on hosted runners. The release job needs no real key: generate one in the job and discard it. The Aliyun mirror is skipped when `CI` is set.
- **Apple.** `CODE_SIGNING_ALLOWED=NO` is sufficient for build and unit tests. App Group behaviour (widgets) cannot be tested unsigned on device; simulator ad-hoc signing works locally (iOS README).
- **HarmonyOS.** Host tests are valuable and fast but every kit API is a fake; they have already needed corrections for BOM handling and `mtime` units. They are Tier A logic tests, never a substitute for hvigor or a device.
- **Docs.** A link checker and the generator checks are cheap and belong in Tier A.

## 9. Testable criteria

- The workflow file lists a job for every row of §3 marked required.
- `gh api repos/{owner}/{repo}/rulesets` (or the settings page) shows the §6 configuration.
- For any release tag, a release record exists and each of the eight gate items has an entry.
- No test target exists without a CI job or a documented reason.

## 10. Migration impact

Stage 1 (two macOS jobs, generator checks, static gates) changes only `.github/workflows/` and needs no source change. Whether the newly included suites pass on a given ref is unknown until they run there: they have only ever been run on the owner's machine. The generator and LAN gates depend on scripts that exist only on the candidate lines, so those jobs are introduced on the integration base. macOS runner minutes increase. Stage 2 adds the release job and secret scan. Tier C is organisational, not code.

## 11. Verification

The Actions run list and job list for a commit; the ruleset export; the release record.

## 12. Exceptions

A required check may be bypassed only by the owner, for a named commit, with the reason in the merge commit. Tier C manual gates may be deferred for a pre-release build that is not distributed outside the owner's own devices.
