# Compatibility findings F-02 / F-03 and actual-export evidence

Candidate fixes are implemented; independent acceptance and the full installed-app/device matrix remain pending. Keystore/credential remediation is outside this branch. No backup-schema rewrite, store move, App Group migration or field stripping.

## F-02: modern IANA names and older OS aliases

At e9a0aa6, the frozen420-name list accepted Europe/Kiev and Asia/Calcutta but rejected Europe/Kyiv and Asia/Kolkata even though native macOS Foundation, host JDK and host Intl accepted them. `backup-compatibility-probe.cjs`, `FlashBackupProbe` and `AndroidBackupProbe` reproduced the production-codec rejection with fictional timed tasks. Host Intl canonical spelling differs from Foundation/JDK; its enumeration is not a modern IANA authority.

The candidate uses generated pinned IANA naming/Link facts and each platform's native rules, preserving all previously accepted names and the original wire spelling. Validation, calendar/editor/card calculations and Harmony forms share alias resolution. An OS with no safe supported alias rejects the entire import, including recovery, with an update-system message before preview/write. Unknown values/case/offsets and existing excluded abbreviations remain invalid. See [exact policy, provenance and regeneration](../contracts/time-zones.md). No task timestamps/zones are migrated.

Modern/legacy parse→export tests and simulated old-OS fallback pass in host gates; physical devices and oldest supported OS remain unverified. Existing strict/recovery/DST gates remain. The pinned facts describe names/aliases, not replacement time-zone rule data; do not promise equal future/historical offsets across OS tzdb versions.

## F-03: actual Apple schema2 export was rejected

Apple already wrote the contract's schema2 fields; Android/Harmony formerly accepted only schema1 and lacked typed metadata support. Actual Apple production exporter output,2,639bytes, SHA256 `cc9718e96f86ce50df4c028a673cfcd2d37ce385e0235c3e1d1764889f6fffa2`, was fed unchanged to both production parsers and rejected. This was not a hand-relabelled fixture.

Owner approval on2026-10-24 authorized nullable metadata support and additive Room4→5. Commits `4a1eef0` and `6914f04` preserve favorites (including false), emotion intensity and task source links through parsing, persistence/editing, merge and export. Section1/2 are accepted independently; schema1 cannot carry schema2 fields, future versions/fields/types remain rejected. Android adds five nullable columns without table replacement or destructive fallback; Harmony retains its existing payload-backed table. See [migration, failure and rollback boundary](schema2-migration-plan.md).

### Actual-export component matrix

Each pass compares incoming new metadata directly against re-exported JSON, plus full model equality. Counts alone are insufficient. Inputs contain fictional2logs/2emotions/2tasks. No fixture-only result is entered as an actual export.

| Sender production export / receiver | Executed tier | Result |
| --- | --- | --- |
| Apple→Apple | Native macOS FlashCore exporter/parser | Pass; original2639byte output and re-export |
| Apple→Android | API36/Android16 native production parser/Room, separate write/read invocations with force-stop | Pass; fields/read-state retained; native Android output2564bytes, SHA256 `4fe48730cbbc3a14f15c2aa584b70a34442adc95b2de31173b6347e375b5951e` |
| Apple→Harmony | Actual ArkTS parser/exporter via Node loader | Pass; SHA256 `cab6922ea6a3ea92f3d5642748cd0bcf4e4bf47076785e63123006947f6a893b`; not native RDB |
| Android native output→Apple | Native macOS FlashCore parser/exporter | Pass; metadata and model equality |
| Android native output→Harmony | Actual ArkTS parser/exporter on Node | Pass; metadata and model equality |
| Harmony output→Apple | Native macOS FlashCore parser/exporter | Pass; metadata and model equality |
| Harmony output→Android | Gradle-built production Kotlin codec on host JDK | Pass on host JDK and API36 native production Room: separate write/force-stop/read invocations,1test passed in each phase |

Raw [compatibility evidence](evidence/compatibility/manifest.json) records input/output/source hashes. Harmony→Android native re-export SHA256 `db02cd6df7a5e2446401987be4087e072a72ca27a450c0a23c848ea819aa3c6d` also passed Apple native parse/export and separate-process SwiftData/read-state save/reopen. Synthetic seed models entered the real exporter, whose exact output entered each parser. This establishes component interoperability; it does not imply file-picker UI, reminders, physical devices or Harmony native RDB passed.

### Installed-app and physical-device matrix

| Actual app sender ↓ / app receiver → | iOS | macOS | Android | HarmonyOS |
| --- | --- | --- | --- | --- |
| iOS UI export | not verified | not verified | not verified | not verified |
| macOS UI export | not verified | not verified | not verified | not verified |
| Android UI export | not verified | not verified | not verified | not verified |
| HarmonyOS UI export | not verified | not verified | not verified | not verified |

Shared Apple native codec results are not two installed app results. Android instrumentation invokes production repositories directly, not the file picker. No Android/Harmony physical target was attached; paired iPhone installation requires existing approved signing, which remains unset. Legacy LAN is intentionally disabled in every ordered old/new combination, independent of file format. New apps show an actionable file-export/share explanation; old apps may time out because there is no listener/advertisement. No secure replacement protocol is claimed.

## Exact outstanding acceptance procedure

1. In dedicated fictional app containers, export true/false/null favorites, intensity1/5/null, linked/dangling/null source IDs, timed/all-day tasks, modern/legacy zones and schema1 controls. Record app/OS/commit/build, exact bytes and SHA256. Never strip/relabel fields to make a case pass.
2. For all12 ordered app directions and four same-app cases, import into a sentinel store through the actual file/share flow. Exercise merge, overwrite, cancel, malformed/oversize and unsupported-version rejection. Verify no rejected/cancelled import changes sentinel data; terminate/relaunch and re-export every supported model field plus read-state/reminders.
3. Keep native host codec, simulator/emulator and real-device rows separate. Run real LAN tests only for a subsequently approved replacement; the disabled legacy candidate must open no network surface. Record unavailable hardware/signing explicitly.
4. Roll back UI independently while retaining schema2/v5-compatible data and LAN disablement. Old Android v4 binaries may not open v5; old Harmony binaries can silently discard metadata despite unchanged SQL. Use a compatible binary/forward fix, never destructive downgrade or plaintext rollback.
