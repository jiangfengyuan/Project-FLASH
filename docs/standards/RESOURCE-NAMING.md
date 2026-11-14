# Naming and resource conventions

> **Status: Proposed — not ratified.** See [README.md](README.md) for rule levels and labels.

> **中文摘要**：本文区分两类命名规则。第一类是“兼容性约束”（JSON 字段、数据库表与列、迁移编号、Bundle ID、深链 scheme、资源 ID 等），一旦发布就不能随意改名，级别为 MUST。第二类是“风格约定”（文件、类型、函数命名），遵循各平台惯例，级别为 SHOULD/MAY。另外规定了设计令牌、图标（iOS/macOS 资源目录、Android 自适应图标、HarmonyOS 分层图标）以及测试与样例文件的命名。

## 1. Current state

| Observation | Evidence |
| --- | --- |
| Identifiers in use: Android `com.flash.app` (debug suffix `.native`); iOS `com.flash.app.ios` (+ `.widget`); macOS `com.flash.app.macos` (+ `.widget`); HarmonyOS `com.flash.app.harmonyos`; App Group `group.com.flash.app.ios`; mDNS service `_flashbackup._tcp`; deep links `flash://capture`, `flash://today`, `flash://ideas`; Android database `flash-db`. | Verified |
| Tables are named identically on Android and HarmonyOS: `logs`, `emotions`, `tasks`, `idea_view_state`. SwiftData entities: `LogEntity`, `EmotionEntity`, `TaskEntity`, versioned as `FlashSchemaV1`, `FlashSchemaV2`. Room migrations: `MIGRATION_1_2` … `MIGRATION_3_4` (`MIGRATION_4_5` on candidates). | Verified |
| JSON keys are lowerCamelCase (`exportedAt`, `colorTag`, `sourceLogId`, `isFavorite`). | Verified (schema) |
| Fixtures: `valid-*`, `invalid-*`, `merge-*`, `overwrite-*`, `legacy-*`, plus `cases.json`. | Verified |
| Test files: `*Tests.swift` (41), `*Test.kt` (27), `*.test.cjs` (30) on `feat/paper-writing`. | Verified |
| Tokens: FlashKit `Spacing.xxs…xxl`, `Radius.*`, `Metrics.*`; ArkTS `SCREAMING_SNAKE` constants with `_LIGHT` / `_DARK` suffixes; Android `FlashTokens.kt`, `PaperColors.kt`; a neutral `docs/design/paper-tokens.json` exists on `feat/paper-writing`. | Verified |
| Icons on `main`: iOS single 1024; macOS seven sizes; Android adaptive icon whose monochrome layer reuses the colour foreground; HarmonyOS `icon.svg`. PR #5 replaces these with generated assets (iOS dark and tinted, Android dedicated monochrome, HarmonyOS layered icon) from `scripts/brand/generate_app_icons.py`, documented in `docs/brand/APP_ICON.md`. | Verified |
| Localization keys are Chinese source strings; HarmonyOS resource names are `s_<fnv1a32>`. | Verified (`feat/paper-writing`) |
| Tooling lives in both `scripts/` and `tools/` (`tools/` only on `feat/paper-writing`). | Verified |

## 2. Compatibility-required names (MUST)

Changing any of these breaks installed apps, stored data, exported backups or store listings. They are frozen once shipped.

| ID | Level | Rule | Enforcement |
| --- | --- | --- | --- |
| FS-NAME-01 | MUST | Application and extension identifiers listed in §1 do not change. New targets extend the existing prefix (`com.flash.app.<platform>.<target>`). | Planned (CI assertion) |
| FS-NAME-02 | MUST | Backup JSON keys are lowerCamelCase ASCII, defined only in `flash-backup-v2.schema.json`. A key is never renamed or reused with a new meaning; a change of meaning is a new key in a new section schema version. | Enforced (schema + fixtures) |
| FS-NAME-03 | MUST | Enum values on the wire are lowercase ASCII tokens defined in the schema (for example `idea`, `log`). They are never display strings and never localized. | Enforced |
| FS-NAME-04 | MUST | Database table names are lowercase `snake_case` plural nouns and are the same on every platform that uses SQL tables. Column names for portable fields equal the JSON key. | Manual; currently true |
| FS-NAME-05 | MUST | Migration identifiers state both versions: Room `MIGRATION_<from>_<to>`; SwiftData `FlashSchemaV<n>` with `Schema.Version(n, 0, 0)`; HarmonyOS `migrateV<from>ToV<to>` with the RDB `version` field. Versions are consecutive integers; none is skipped or reused. | Manual |
| FS-NAME-06 | MUST | Deep-link scheme `flash://` and its hosts are shared vocabulary: a host means the same destination on every platform that supports it. New hosts are added to one table in this document's successor or the contract directory. | Manual |
| FS-NAME-07 | MUST | Preference and settings keys are lowerCamelCase ASCII, declared as named constants in one file per platform, and never renamed without a migration. | Manual |
| FS-NAME-08 | MUST | Notification channel IDs, reminder group IDs, WorkManager unique names, widget kinds and App Group file names are constants with a `flash` or bundle-ID prefix and are treated as persisted identifiers. | Manual |
| FS-NAME-09 | MUST | Localization key IDs follow [LOCALIZATION-STANDARD.md §4](LOCALIZATION-STANDARD.md#4-keys). Platform resource names are derived from them mechanically. | Planned |
| FS-NAME-10 | MUST | Persisted or exported property names in ArkTS model classes are protected from obfuscation. (F-05.) | Enforced-candidate (`fix/pr3-review-followups` `8123352`) |

**Rationale.** These names are data. The audits found one case where a build setting could silently rename stored keys (F-05) and one where enum raw values doubled as display text (`ReviewWindow.week = "本周"` on `main`).

## 3. Source naming (SHOULD / MAY)

Follow the platform's own convention. These rules exist so that four codebases remain navigable by someone who knows one of them.

| ID | Level | Rule |
| --- | --- | --- |
| FS-NAME-11 | SHOULD | Kotlin: packages lowercase under `com.flash.app.{data,domain,ui.<feature>,i18n}`; one top-level class per file, file named after it; `PascalCase` types, `camelCase` functions; Composables `PascalCase`; screens `<Feature>Screen`, view models `<Feature>ViewModel`. |
| FS-NAME-12 | SHOULD | Swift: one primary type per file, file named after it; `PascalCase` types, `camelCase` members; views `<Feature>View` in FlashDesign, `<Feature>Screen` for shell-level screens; view-modifier helpers prefixed `flash` (`flashPanelWidth`), as today. |
| FS-NAME-13 | SHOULD | ArkTS: files `PascalCase.ets`; pages `<Feature>Page`, controllers `<Feature>Controller`, dialogs `<Purpose>Dialog`; exported constants `SCREAMING_SNAKE_CASE`. |
| FS-NAME-14 | SHOULD | The same concept has the same name on all platforms: `FlashRepository` / `FlashStore`, `BackupService`, `TaskReminderScheduler`, `EmotionStats`, `ReviewWindow`. A new shared concept is named once, in the PR that defines its contract. |
| FS-NAME-15 | SHOULD | Feature directory names use one vocabulary: `home`, `explore`, `logflow`, `emotion`, `calendar`, `stats`, `memory`, `settings`, `backup`, `onboarding`. |
| FS-NAME-16 | MAY | Comments and commit bodies may be Chinese or English. Identifiers, file names, JSON keys, resource names and branch names are ASCII. |
| FS-NAME-17 | SHOULD | Commit subjects use the existing conventional form `type(scope): summary` with scopes `android`, `ios`, `macos`, `harmonyos`, `flashkit`, `backup`, `lan`, `i18n`, `ci`, `docs`. |
| FS-NAME-18 | SHOULD | Repository tooling goes under `scripts/` (run in CI or by contributors) or `tools/` (investigation, benchmarks, probes). One generator per directory, named `generate*.{py,cjs}` with `--check`. The two top-level directories are merged or their split is documented when the integration base is chosen. |

Enforcement for this section: Manual (review). None of these is checked by CI, and existing names are not renamed for style alone.

## 4. Design tokens

| ID | Level | Rule | Enforcement |
| --- | --- | --- | --- |
| FS-NAME-19 | MUST | Colour, spacing, radius, typography and motion values that are meant to match across platforms are defined in one neutral token file and generated or checked into each platform. | Partial: `docs/design/paper-tokens.json` plus `PaperTokensTest.kt` and `design-tokens.test.cjs` on `feat/paper-writing`; not in CI for Apple |
| FS-NAME-20 | MUST | Token names are semantic, not literal: `color.text.primary`, `color.surface.card`, `color.brand`, `space.md`, `radius.card`. A name never contains a hue or a hex value. Light and dark are variants of one token, not two tokens. | Manual |
| FS-NAME-21 | SHOULD | Platform spelling is mechanical: Swift `Spacing.md`, `Radius.card`; Kotlin `FlashTokens.Space.md`; ArkTS `SPACE_MD`, `TEXT_PRIMARY_LIGHT` / `_DARK` (existing forms are kept). | Manual |
| FS-NAME-22 | MUST | UI code uses tokens. A raw colour literal or magic dimension in a screen needs a comment or becomes a token. | Planned (lint/grep) |
| FS-NAME-23 | SHOULD | The spacing scale stays `xxs 4, xs 8, sm 12, md 16, lg 24, xl 32, xxl 48`; minimum touch target 44 pt (Apple) / 48 dp (Android) / 48 vp (HarmonyOS). | Manual |

## 5. Icons and images

`assets/brand/flash-standard-icon.png` is the only master. Derived assets are generated; they are not edited by hand. (Existing rule in `docs/brand/APP_ICON.md`.)

| ID | Level | Platform | Rule | Enforcement |
| --- | --- | --- | --- | --- |
| FS-NAME-24 | MUST | All | Every platform icon is produced by one generator from the master, and the generator's `--check` passes. | Enforced-candidate (PR #5 script); not in CI |
| FS-NAME-25 | MUST | iOS | `Assets.xcassets/AppIcon.appiconset` holds a single-size 1024 × 1024 icon: an opaque default, plus dark and tinted appearance variants. `Contents.json` lists all three. The default has no alpha channel. | PR #5 |
| FS-NAME-26 | MUST | macOS | `AppIcon.appiconset` provides every slot from 16 to 1024 at 1x and 2x. Artwork sits on the standard rounded-rectangle plate with margin, not full-bleed. | PR #5 |
| FS-NAME-27 | MUST | Apple | Colours and images used from code live in an asset catalog with named sets (`AccentColor`, `Brand…`), each with light and dark appearances where they differ. Widget and extension targets carry their own catalog or share one by target membership. | Manual |
| FS-NAME-28 | MUST | Android | `mipmap-anydpi-v26/ic_launcher.xml` is an adaptive icon with `background`, `foreground` and a dedicated `monochrome` layer. Foreground artwork stays inside the 66 dp safe zone. No legacy raster launcher icons are needed at minSdk 26. Resource files are lowercase `snake_case`; launcher layers are named `flash_launcher_<layer>`; vector drawables `ic_<name>`. | PR #5; on `main` the monochrome layer reuses the colour foreground |
| FS-NAME-29 | MUST | HarmonyOS | App and ability icons are layered-image resources: a JSON under `resources/base/media/` naming a transparent 1024 foreground and an opaque 1024 background. `AppScope` and `entry` copies are identical, because AppScope overrides same-named module resources at build time. | PR #5; `main` still uses `icon.svg` |
| FS-NAME-30 | SHOULD | All | In-app glyphs use the platform symbol set (SF Symbols, Material Icons, HarmonyOS system symbols). A custom glyph is a vector (`.svg`, vector drawable, symbol image), named by meaning (`ic_capture`), not by appearance. | Manual |
| FS-NAME-31 | MUST | All | Raster images that are not icons are added only with owner approval, carry a licence note, and are stored once per required density. Screenshots and evidence images do not go under platform source trees. | Manual |
| FS-NAME-32 | MUST | All | Fonts bundled with the app are listed with licence and the locales they cover. A font that covers only some scripts is switched off for others (already done for LXGW WenKai via `usesBundledDisplayFont`). | Manual |

## 6. Tests, fixtures and evidence

| ID | Level | Rule | Enforcement |
| --- | --- | --- | --- |
| FS-NAME-33 | MUST | Test files: `<Subject>Tests.swift`, `<Subject>Test.kt`, `<topic>.test.cjs`. They sit in the test target of the module they test. | Manual; currently true |
| FS-NAME-34 | MUST | Contract fixtures: `valid-<what>.json`, `invalid-<reason>.json`, `merge-<role>.json`, `overwrite-<role>.json`, `legacy-<version>.json`, all registered in `cases.json`. A fixture file that is not registered fails the generator check. | Enforced (`generate-cases.cjs --check`) |
| FS-NAME-35 | MUST | Fixture and test data are fictional. No real journal text, names, device identifiers or credentials. | Manual |
| FS-NAME-36 | SHOULD | Test names state behaviour and expected outcome (`strictImportRejectsUnknownSection`). A regression test cites the finding ID it guards in a comment. | Manual |
| FS-NAME-37 | SHOULD | Screenshot baselines are named `<platform>-<screen>-<theme>-<size>[-<locale>].png` and kept outside the source trees. Large binary evidence is stored outside Git with a committed manifest of SHA-256 hashes. (D-22: 28 MiB of screenshots sit in `docs/hardening` on the candidate.) | Manual |
| FS-NAME-38 | MUST | Dated documents use ISO dates in the file name (`2026-11-11-…md`). | Manual |

## 7. Testable criteria

- The identifiers in §1 appear unchanged in the four manifests.
- Every key in the fixtures matches `^[a-z][A-Za-z0-9]*$`.
- `generate_app_icons.py --check`, `generate.py --check`, `generate-cases.cjs --check` exit 0.
- No file under `res/` contains uppercase letters or hyphens in its name.
- HarmonyOS `AppScope` and `entry` icon files have equal hashes.

## 8. Migration impact

Section 2 mostly records what is already true; it requires no renames. FS-NAME-09 is the localization migration. FS-NAME-24 to -29 are satisfied by PR #5 once it is rebased onto the integration base. FS-NAME-19/20 need the token file extended to Apple and a naming pass; values do not change.

## 9. Verification

Generator checks in CI; a small script asserting bundle identifiers and minimum versions; review for style rules.

## 10. Exceptions

Section 2 rules: owner only, with a data-migration plan. Section 3: reviewer discretion; existing names are not renamed for style alone.
