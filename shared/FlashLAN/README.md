# FLASH-LAN/2 shared native core

Status: candidate application adapters are wired; **production remains disabled**.
Physical devices, minimum-OS/permission/background/large-file acceptance and the
12 cross-platform directions remain mandatory. Never restore the legacy wire or
silently fall back. The owner requested Codex self-review; this is not an external
independent audit. See [protocol](../../docs/contracts/lan-v2-review-draft.md) and
[self-review](../../docs/hardening/lan-v2-self-review-20261101.md).

Rust owns the commit/reveal handshake, vodozemac SAS/MAC/key derivation, bounded
record parsing, directional XChaCha20-Poly1305 keys/counters, deadlines, finish
and receipt. Platform code owns discovery, one active socket, the opening/failure
budget, lifecycle, explicit user confirmation and the existing strict backup
parser/preview. No protocol API writes the database. The snapshot callback runs
only after both authenticated confirmations. EOF is never a receipt.

## Pinned build inputs

- Rust **1.99.1**, vodozemac **0.11.1**, libsodium **1.0.22**.
- Cargo.lock pins all 79 registry archives (including target/test dependencies).
  `THIRD_PARTY_NOTICES.md` records checksums and declared licenses. Generated
  artifacts include full upstream notices, Rust runtime notices and project MPL.
- libsodium archive SHA-256:
  `adbdd8f16149e81ac6078a03aca6fc03b592b89ef7b5ed83841c086191be3349`.
  Obtained from official HTTPS; downloaded detached signature was not verified.
- Xcode-beta; Android NDK **r29 / 29.0.14206865**, API26 compiler;
  DevEco native SDK **26.0.0.105**. Android NDK archive SHA-256:
  `ce5e4b100ec5fe5be4eb3edcb2c02528824ff9cda3860f5304619be6c3da34d3`.
  The official Google repository SHA-1 was also checked. Builds disable sodium
  assembly and PIE and require PIC. Never substitute cryptographic primitives.

## Reproduce locally

Run from the app repository root. Install the pinned Rust toolchain and these
standard-library targets before `cargo fetch --locked --manifest-path shared/FlashLAN/Cargo.toml`:

```
aarch64-apple-darwin x86_64-apple-darwin aarch64-apple-ios
 aarch64-apple-ios-sim x86_64-apple-ios aarch64-linux-android
 armv7-linux-androideabi i686-linux-android x86_64-linux-android
 aarch64-unknown-linux-ohos x86_64-unknown-linux-ohos
```

Set `FLASH_LAN_BUILD_ROOT`, `FLASH_LAN_SODIUM_ARCHIVE`, `FLASH_LAN_NDK` to dedicated
local paths. Python3.12+, make and the SDKs are required. The builder validates
source checksums, uses `--locked --offline`, performs **final native links**,
runs the macOS Swift smoke, and records source/library hashes. A cross-link is
not device execution. Re-run after any core/bridge/builder change:

```sh
for target in macos-arm64 macos-x86_64 ios-arm64 ios-sim-arm64 ios-sim-x86_64 \
  android-arm64 android-armv7 android-x86 android-x86_64 harmony-arm64 harmony-x86_64; do
  python3 tools/lan-v2-probe/build.py --core --target "$target" \
    --sodium-archive "$FLASH_LAN_SODIUM_ARCHIVE" --android-ndk "$FLASH_LAN_NDK" \
    --output "$FLASH_LAN_BUILD_ROOT" || exit 1
done
python3 tools/lan-v2-licenses.py --cargo-home "${CARGO_HOME:-$HOME/.cargo}" \
  --sodium-archive "$FLASH_LAN_SODIUM_ARCHIVE" \
  --rust-doc "$(rustc --print sysroot)/share/doc/rust" \
  --output "$FLASH_LAN_BUILD_ROOT/notices"
python3 tools/package-lan-v2.py --build-root "$FLASH_LAN_BUILD_ROOT" \
  --licenses "$FLASH_LAN_BUILD_ROOT/notices" --install-harmony
```

Use a new notices output directory on subsequent collections. Matrix-pickle's
published crate omits its workspace license: `licenses/matrix-pickle-LICENSE`
was retrieved at the exact `.cargo_vcs_info.json` upstream commit
`3eb007eae1ca87e3a3683c99a58fd19289abae52`:
<https://raw.githubusercontent.com/matrix-org/matrix-pickle/3eb007eae1ca87e3a3683c99a58fd19289abae52/LICENSE>.
Its SHA-256 is verified by the collector. All other notices come directly from
checksum-verified source archives and the installed pinned Rust distribution.

Generated `artifacts/` and Harmony `entry/libs/*/libflash_lan.so` stay out of git.
Apple SwiftPM links the XCFramework when present; an absent binary leaves its
LAN API unavailable. Android packages four ABI libraries and retains exact JNI
names under R8. Harmony uses the local locked N-API type package; run `ohpm install`
in `harmonyos` after packaging. Its hvigor plugin rejects missing/mismatched
native libraries because a static ArkTS import must never ship without its `.so`.
No step signs a release or changes the disabled production switches.

## Android instrumentation CI

The `android-database` job builds the real x86_64 JNI library with the pinned
Rust toolchain, NDK and checksum-verified sodium source before starting the
API 35 emulator. The builder supports Linux and macOS NDK host directories.
CI places this one-ABI library in `android/app/src/debug/jniLibs/x86_64` and
checks its presence in the debug APK before executing instrumentation tests.
This is a disposable debug-only payload, not a complete licensed release
artifact set produced by `tools/package-lan-v2.py`. Production remains disabled;
other ABIs, release packaging and physical devices still require acceptance.

## Verification boundaries

- `cargo test --locked --offline`: requires `FLASH_SODIUM_LIB_DIR` from the host
  build. Fixed RFC7748/Python/libsodium vectors independently check wire/KDF/MAC;
  randomized real vodozemac sessions check the full protocol. The public upstream
  SAS constructor has no deterministic key input; no production RNG is patched.
- `vectors/generate.py --sodium-library <host-libsodium.dylib> --check` reproduces
  the public test-key fixture. Never use real keys/backups with this generator.
- `platforms/android/test-host.py`: actual JNI on a host JVM; Android native
  instrumentation tests exercise the application socket adapter separately.
- `platforms/harmony/test-host.py`: actual C N-API bridge and actual ArkTS adapter
  on host Node, using synthetic fragmented sockets. It is **not HarmonyOS device
  execution**. Default host tests skip these native cases without the addon.
- `fuzz/transport.cpp`: real libFuzzer harness checks pre-auth bounds and mutates
  authenticated records; build with the NDK fuzzer runtime. Coverage-guided
  testing has finite limits and is not a proof of cryptographic security.

Application production gates are constants, not settings or stored preferences.
Internal candidate test constructors do not bypass cryptography or auto-confirm.
Keep import preview, commit-time revalidation and transaction rollback unchanged.
