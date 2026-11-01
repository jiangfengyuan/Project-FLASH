# Release performance evidence — limited to the measured host workload

Status: measured shared FlashCore on macOS; mobile app/real-device performance **not verified**. This is not evidence of four-platform performance completion.

## Reproduction and conditions

Baseline `4e67c13` versus candidate `d6ce569` (includes `0b84ec2`). MacBook Pro Mac15,6, M3 Pro11 CPU cores,36GB, macOS27.2 (26B5101f), Xcode-beta27.2/Swift6.4; Release `tools/performance` executable. AC80%, no recorded thermal/performance warning, Gradle daemon stopped, no running emulator/simulator/build. Serial runs on the owner-reserved machine. The candidate had unrelated Android/documentation changes; the shared FlashCore tree and executable hashes are in the conditions files. No native source edits/builds occurred during measurement.

Dataset: fixed reference2026-10-24, fictional deterministic1k/10k/100k logs, half as many emotions, one fifth as many tasks over1/5/10years. The100k workload represents long-term use and stays below the unchanged50MiB compact backup cap. Two warmups and seven measured samples per metric/dataset. Exact raw samples, dataset fingerprints, byte sizes, OS/locale and whole-process resource logs are retained in [evidence/performance](evidence/performance). Before/after model fingerprints and byte sizes match.

```sh
# In separate clean baseline/candidate checkouts, serially, with no other workload:
cd tools/performance
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build -c release
/usr/bin/time -l .build/release/FlashBench 1000
/usr/bin/time -l .build/release/FlashBench 10000
/usr/bin/time -l .build/release/FlashBench 100000
```

Generation, export preparation and warmup are excluded from the individual metric timer. Compact strict parsing includes validation/model construction, not disk IO, SwiftData commit, preview/diff, pretty export, LAN or UI rendering. The whole-process memory peak includes all phases and repeated operations; it must not be labeled per-import peak.

## macOS host before/after

Strict parsing: milliseconds, median [minimum–maximum].

| Logs / emotions / tasks | Compact bytes | Before | After | Median ratio |
| --- | ---: | ---: | ---: | ---: |
| 1,000 / 500 / 200 | 395438 | 140.597 [139.839–147.626] | 33.746 [32.814–34.061] | 4.17× |
| 10,000 / 5,000 / 2,000 | 3960132 | 1472.487 [1423.151–1485.697] | 322.284 [320.911–333.975] | 4.57× |
| 100,000 / 50,000 / 20,000 | 39727047 | 14893.932 [14762.504–14961.820] | 3301.493 [3262.519–3349.243] | 4.51× |

Whole-process maximum RSS (`time -l`, bytes):

| Logs | Before | After | Interpretation |
| --- | ---: | ---: | --- |
| 1,000 | 36,913,152 | 36,569,088 | Similar process peak |
| 10,000 | 223,199,232 | 222,822,400 | Similar process peak |
| 100,000 | 2,059,321,344 | 2,065,793,024 | About+0.3%; large-memory workload remains |

An intermediate candidate increased peak memory to2,338,848,768 bytes at100k; it was not accepted as the final measurement. `d6ce569` uses `rangeOfFirstMatch` to avoid creating checking-result objects. The final table includes this correction.

Native `/usr/bin/sample` captured repeated `normalizeISODate`/Foundation formatter calls in export preparation. An attempted15s xctrace Time Profiler trace had no usable exported CPU attribution and killed its synthetic target at the time limit; it is excluded from timing results. Do not infer that its trace proves parse-specific CPU percentages.

Correctness:432 canonical UTC/date/fraction cases and invalid/offset/year boundaries passed before/after; full FlashKit suite201 passed. The UTC-Z fast path retains full date/time/syntax checks and exact millisecond truncation; offsets retain the old conversion/bounds. No caches or UI/widget/query changes. Later cumulative shared/app gates are recorded in verification.md. Later schema/time-zone hardening has not been benchmarked; these measurements remain tied to the stated commits. Tasks in this harness are all-day, so results do not characterize named-zone workloads.

Other100k host medians (ms): common global search391.067→392.692; absent search348.234→344.529; calendar day aggregation38.119→38.441. No search/calendar improvement is claimed from these variations, and no optimization was applied there. All dataset samples remain available.

## Per-platform app comparison and remaining work

| Platform | App Release before | App Release after | Status / next measurement |
| --- | --- | --- | --- |
| macOS | not verified | not verified | Host parser result above only; cold/warm usable frame, scrolling/hitches, SwiftData queries, charts/navigation, backup persistence, LAN, widgets/energy remain |
| iOS | not verified | not verified | No app Release timing, physical LAN, energy/thermal, notifications or widget evidence this pass |
| Android | not verified | not verified | Debug/Release JVM unit gates are not a Release app benchmark. Release signing guard must remain; use existing authorized signing only |
| HarmonyOS | not verified | not verified | Unsigned Debug HAP builds/host tests are not Release/device profiling |

Reproduction for outstanding app measurements:

1. Use the same fictional dataset manifests/small-medium-large model projection in dedicated app containers. Keep daily-use stores untouched. Record the exact exporter/importer schemas; old Android/Harmony baseline codecs reject schema2; the candidate supports it. Do not silently strip fields to seed them.
2. Build baseline/candidate using each README's Release configuration and existing signing. Apple simulator: `xcodebuild -configuration Release -destination <isolated simulator or macOS> ... CODE_SIGNING_ALLOWED=NO` where supported; real iPhone requires existing approved signing/team. Android: `./gradlew :app:assembleRelease` only when existing release-signing prerequisites are available. Harmony: hvigor `assembleHap --mode module -p product=default -p module=entry@default -p buildMode=release` with installed SDK and existing authorized signing for installation.
3. Stop other builds/emulators/profilers. Record model/OS/commit/tree/binary hashes, power/thermal state, locale/timezone, counts/bytes/fingerprint and cache state. Warmup twice; measure seven repetitions (at least five costly launches). Keep all raw samples; report median/range.
4. Apple Instruments: Time Profiler, Allocations, SwiftUI/Hitches and signposts; Android Perfetto/Android Studio; Harmony DevEco Profiler/SmartPerf. Define cold/warm launch endpoint as usable first frame, not process start. Exercise fixed scroll/search/filter/batch/navigation sequences and count actual DB fetches/rows/main-thread time. Record chart/navigation, import/export/LAN throughput and memory separately.
5. Test state correctness, cancellation/rollback and save→terminate→relaunch after every import. Verify read-state, reminders and widget freshness. Collect real-device energy/thermal/background/widget/notification evidence on lower-spec supported devices when available; simulator/emulator results stay separately labeled. No physical Android/Harmony targets were attached at baseline; a paired iPhone is available but unverified without changing signing.

An earlier native-test approval review hit account usage limits; the owner restored execution access and native gates resumed through the approved path. No blocked command was bypassed. The outstanding app/device performance metrics remain unverified; screenshot coverage is tracked separately and is not performance evidence.
