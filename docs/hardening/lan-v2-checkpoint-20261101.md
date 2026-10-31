# LAN v2 implementation checkpoint · 2026-11-01

Status: **incomplete; production LAN remains disabled**. Owner selected all four
platforms, two-device SAS confirmation, and formal enablement only after review
and physical-device acceptance. Baseline is `codex/ios-integrated-candidate`
`13ad77b`; pre-existing screenshot changes have been preserved.

## Delivered

- `tools/lan-v2-probe/`: isolated source-pinned libsodium cross-build/link runner,
  C native primitive probe, and an uncompiled Rust/vodozemac C ABI probe with Swift
  import header. No application build graph references these files.
- Official vodozemac 0.11.1 archive SHA-256 matched crates.io's official sparse
  index. libsodium 1.0.22 official HTTPS archive hash recorded and enforced by the
  runner; detached signature verification remains outstanding.
- arm64 macOS libsodium build and native executable passed. Synthetic checks:
  expected version, RNG API, AEAD round-trip, tamper rejection, explicit key wipe.
- iOS arm64, iOS simulator arm64 and HarmonyOS arm64 libsodium static builds and
  final native dynamic-library links passed. These are cross-links, not installed
  app or device tests. No Rust/SAS runtime result is claimed.
- Separately, upstream libsodium host `make check`: **101/101 passed, 0 failed**.
- Legacy LAN static quarantine check still passes; manifests and application
  source remain unchanged. Application regression suites were not rerun because
  application code and build dependencies were not changed.

## Blocking evidence

1. No Rust toolchain was installed initially. Official rustup installer was
   completed and verified against its official SHA-256. Isolated Rust 1.99.1
   installation subsequently failed with `component download failed for
   cargo-aarch64-apple-darwin` / `error reading a body from connection: timed out`;
   rustup reported rollback. Direct official cargo archive retry also timed out
   after a partial download. Consequently no dependency lock, Rust compilation,
   upstream SAS vector execution, C ABI execution or four-platform Rust link has
   passed. Temporary toolchain state is under `/private/tmp/flash-lan-bootstrap`;
   no global PATH or application toolchain was modified.
2. Android NDK is absent. Fetching Google's official repository metadata failed:
   `Failed to connect to dl.google.com port 443 ... Timeout was reached`.
   The Android probe exits nonzero with `Android NDK missing; set --android-ndk
   (API 26)`. No alternative source, library, SDK or cryptographic implementation
   was substituted.
3. Outside-sandbox `adb devices` returned an empty device list and `hdc list
   targets` returned `[Empty]`. Android/HarmonyOS physical-device gates cannot
   run now. Apple physical-device acceptance was not attempted at this stage.
4. Flash's composed SAS/record protocol has not received the required independent
   review. The rebuild proposal remains a proposal; a dependency smoke test must
   not be treated as a protocol implementation or security review.

## Evidence and continuation

Compact native build reports are in `evidence/lan-v2-20261101/`. Full logs,
native archives and synthetic probe binaries are retained outside git at
`outputs/lan-v2-20261101/` in the workspace root. Those outputs contain no user
backup data. Output library hashes may differ across builds; reproducible binary
equality has not been established.

Resume using the commands in the probe README after official Rust/NDK access is
available. Complete four-platform Rust linkage and ABI/entropy/error/cleanup
checks first. Then finalize the byte specification and independently reviewed
vectors before production protocol/adapters, minimum permission restoration and
the 12 ordered physical-device directions. Do not restore the legacy protocol,
weaken gates, claim completion or enable LAN from this checkpoint.
