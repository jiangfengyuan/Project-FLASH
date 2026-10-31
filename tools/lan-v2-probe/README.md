# LAN v2 dependency/ABI feasibility probe

This directory is isolated from all application build graphs. It does **not**
implement `FLASH-LAN/2`, authenticate a user, transmit a backup, restore network
permissions, or enable production LAN. Do not promote its bare SAS API smoke test
into a pairing implementation: commitment/reveal and transcript binding are absent
by design. The protocol candidate lives separately in `shared/FlashLAN/`
(`build.py --core`).

## Pinned inputs

| Input | Version | Source SHA-256 | License |
| --- | --- | --- | --- |
| vodozemac | 0.11.1 | `9e322119358132f5fa8e529de9ed9af4cd67ae71ffc6f12c133f75d5c4ec9637` | Apache-2.0 |
| libsodium | 1.0.22 | `adbdd8f16149e81ac6078a03aca6fc03b592b89ef7b5ed83841c086191be3349` | ISC |

vodozemac source: <https://crates.io/api/v1/crates/vodozemac/0.11.1/download>;
checksum independently matched the official sparse index at
<https://index.crates.io/vo/do/vodozemac>. Its packaged VCS commit is
`3e11ae87d157da6bcac3cbf7825d37c8f5ed60af`. Minimum upstream Rust is 1.89;
this probe pins Rust 1.99.1, separate from application tools.

libsodium source:
<https://download.libsodium.org/libsodium/releases/libsodium-1.0.22.tar.gz>.
The hash above records the archive obtained over official HTTPS, **not** a verified
release signature. A `.sig` was downloaded but no signing-key verification was
performed. Preserve upstream license notices when distributing dependencies.

## Reproduce the native dependency build

Requires Python 3.12+, make and Xcode-beta (Apple) or the DevEco native SDK
(HarmonyOS). Android additionally requires an installed NDK with an API 26 clang.
Use an output directory outside this probe, and supply the official archive above:

```sh
python3 build.py --target macos-arm64 --sodium-archive /absolute/libsodium-1.0.22.tar.gz --output /absolute/output --sodium-only
```

Run the same command for `ios-arm64`, `ios-sim-arm64`, `harmony-arm64`,
`macos-x86_64`, `android-arm64` or `android-x86_64`. Android requires
`--android-ndk /absolute/ndk`. Apple defaults to Xcode-beta; HarmonyOS defaults to
DevEco's bundled SDK. No SDK is installed automatically and no app project is edited.

The script rejects an archive hash mismatch, builds PIC static libsodium without
assembly, then forces a final native dynamic-library link. On arm64 macOS it also
executes a synthetic test of version, RNG API, AEAD round-trip, tamper rejection
and explicit key wiping. Cross-built code is never run as host code. Reports
distinguish archive build, dependency link, host execution, application link and
device execution; a successful dependency build is not application acceptance.

## Resume the Rust probe after network/toolchain recovery

Install the pinned Rust toolchain into a dedicated `CARGO_HOME`/`RUSTUP_HOME` if
desired. `Cargo.lock` is committed; run `cargo fetch --locked` and install the
required Rust targets. Do not regenerate the lockfile or substitute a different library.

Run `build.py` without `--sodium-only` (optionally `--cargo /absolute/cargo`). Rust
builds require the reviewed lockfile and use `--locked --offline`. For a host
primitive/ABI test, set `FLASH_SODIUM_LIB_DIR` to the built target's `sodium/lib`
and run `cargo test --locked --offline`. After Rust builds, `apple/main.swift`
and `include/` provide a Swift-to-C smoke-test entry, still requiring final linking
and execution. `android/` and `harmony/` hold minimal JNI and N-API wrappers that
`build.py` links into the native dynamic library; they are not wired into any app.

`flash_lan_probe_run()` returns 0 on success; 1 init, 2 wrong sodium version,
3 DH rejection, 4 differing SAS, 5 MAC verification, 6 altered MAC accepted,
7 encryption, 8 decryption, 9 tamper accepted, 10 wipe failed, 100 caught Rust panic.
It returns no secret or SAS values. This does not certify entropy quality, complete
memory erasure, process-abort recovery, or protocol security.

## Current checkpoint

See [checkpoint and evidence](../../docs/hardening/lan-v2-checkpoint-20261101.md).
Rust toolchain and Android NDK were later recovered locally; Rust host tests,
cross-target static builds and bridge links are recorded under
`outputs/lan-v2-continuation-20261101/` (outside git). The isolated
`shared/FlashLAN/` state machine is a candidate only, with a Codex self-review
(`docs/hardening/lan-v2-self-review-20261101.md`), not an independent audit. No
network adapter, application link, device execution, 12-direction physical-device
matrix or formal enablement has been delivered.
