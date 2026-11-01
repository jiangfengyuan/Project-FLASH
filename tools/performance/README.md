# Release host measurement harness

Developer-only local Swift package; not linked into any app. Uses the existing FlashCore product and platform SDKs, with no external package additions. `DEBUG` builds fail compilation deliberately.

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  swift build -c release --package-path tools/performance
tools/performance/.build/release/FlashBench 1000
tools/performance/.build/release/FlashBench 10000
tools/performance/.build/release/FlashBench 100000
```

Run only with the machine reserved and other builds/simulators/profilers stopped. Build first, then time the binary directly. Record commit/tree state, binary hash, OS/model/locale, AC/thermal conditions and command externally. Each output JSON line has all7 samples, median/range, deterministic model fingerprint, counts, time span and result-consumption sink;2 untimed warmups precede each metric. The sink prevents eliminating the result.

Fixtures are fictional, fixed to2026-10-24 with deterministic IDs/dates and Chinese/Latin/emoji/long-text clusters. Counts are1k/500/200,10k/5k/2k,100k/50k/20k over1/5/10 years. Compact existing-schema JSON is used for strict parse within50MiB; this is **not a measurement of the pretty-print export pipeline**, which may exceed the cap at the largest dataset. No existing app database is opened.

Metrics are macOS host microbenchmarks for shared search, calendar aggregation and strict backup parsing. They do not establish iOS/Android/Harmony device speed, app launch/frames, database query behavior, LAN throughput, widget freshness, battery or thermal behavior. Native Apple profiling can attach Instruments/xctrace Time Profiler to this Release executable; profiling samples are separate from uninstrumented raw timing runs. The `com.flash.benchmark` signpost interval identifies timed pipelines.
