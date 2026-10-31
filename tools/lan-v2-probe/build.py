#!/usr/bin/env python3
"""Build the isolated LAN dependency probe; never edits application projects.

Inputs are a pinned upstream archive and an installed Rust/SDK toolchain.
All generated files and logs go to --output, outside this source directory.
"""
import argparse
import hashlib
import json
import os
import platform
import re
from pathlib import Path
import shlex
import shutil
import subprocess
import tarfile

SODIUM_SHA256 = "adbdd8f16149e81ac6078a03aca6fc03b592b89ef7b5ed83841c086191be3349"
ROOT = Path(__file__).resolve().parent
TARGETS = {
    "macos-arm64": ("aarch64-apple-darwin", "macosx", "arm64", "-mmacosx-version-min=15.0"),
    "macos-x86_64": ("x86_64-apple-darwin", "macosx", "x86_64", "-mmacosx-version-min=15.0"),
    "ios-arm64": ("aarch64-apple-ios", "iphoneos", "arm64", "-miphoneos-version-min=18.0"),
    "ios-sim-arm64": ("aarch64-apple-ios-sim", "iphonesimulator", "arm64", "-mios-simulator-version-min=18.0"),
    "harmony-arm64": ("aarch64-unknown-linux-ohos", None, "aarch64", None),
    "android-arm64": ("aarch64-linux-android", None, "aarch64", None),
    "android-x86_64": ("x86_64-linux-android", None, "x86_64", None),
}


def run(command, env, cwd, log):
    with log.open("w") as stream:
        stream.write(shlex.join([str(x) for x in command]) + "\n")
        stream.flush()
        subprocess.run(command, env=env, cwd=cwd, stdout=stream,
                       stderr=subprocess.STDOUT, check=True)


def build(args, report):
    crate_root = ROOT.parents[1] / "shared/FlashLAN" if args.core else ROOT
    library_name = "flash_lan" if args.core else "flash_lan_probe"
    archive = args.sodium_archive.resolve()
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    if digest != SODIUM_SHA256:
        raise ValueError("libsodium archive SHA-256 mismatch")
    report["sodium_archive_sha256"] = digest
    target, sdk, arch, minimum = TARGETS[args.target]
    out = args.output.resolve() / args.target
    out.mkdir(parents=True, exist_ok=True)
    report["rust_target"] = target
    env = dict(os.environ)
    if sdk:
        env["DEVELOPER_DIR"] = str(args.developer_dir)
        def xcrun(*command):
            return subprocess.check_output(["/usr/bin/xcrun", "--sdk", sdk, *command],
                                           env=env, text=True).strip()
        compiler = xcrun("--find", "clang")
        env["CC"] = shlex.quote(compiler)
        env["CFLAGS"] = shlex.join(["-arch", arch, "-isysroot", xcrun("--show-sdk-path"), minimum, "-fPIC"])
        env["LDFLAGS"] = env["CFLAGS"]
        env["AR"] = xcrun("--find", "ar")
        env["RANLIB"] = xcrun("--find", "ranlib")
        host = f"{arch}-apple-darwin"
    elif args.target.startswith("harmony"):
        native = args.harmony_native.resolve()
        compiler = str(native / "llvm/bin/aarch64-unknown-linux-ohos-clang")
        if not Path(compiler).is_file():
            raise ValueError("HarmonyOS native compiler missing; set --harmony-native")
        env["CC"] = shlex.quote(compiler)
        env["AR"] = str(native / "llvm/bin/llvm-ar")
        env["RANLIB"] = str(native / "llvm/bin/llvm-ranlib")
        env["CFLAGS"] = "-fPIC"
        host = target
    else:
        if not args.android_ndk:
            raise ValueError("Android NDK missing; set --android-ndk (API 26)")
        binaries = args.android_ndk.resolve() / "toolchains/llvm/prebuilt/darwin-x86_64/bin"
        compiler = str(binaries / f"{target}26-clang")
        if not Path(compiler).is_file():
            raise ValueError("Android NDK API 26 compiler missing")
        env["CC"] = shlex.quote(compiler)
        env["AR"] = str(binaries / "llvm-ar")
        env["RANLIB"] = str(binaries / "llvm-ranlib")
        env["CFLAGS"] = "-fPIC"
        host = target
    source = out / "source"
    source.mkdir(exist_ok=True)
    with tarfile.open(archive) as tar:
        tar.extractall(source, filter="data")
    sodium = source / "libsodium-1.0.22"
    prefix = out / "sodium"
    work = out / "build"
    work.mkdir(exist_ok=True)
    run([str(sodium / "configure"), f"--prefix={prefix}", f"--host={host}",
         "--disable-shared", "--enable-static", "--disable-asm"], env, work, out / "configure.log")
    run(["make", "-j4"], env, work, out / "make.log")
    run(["make", "install"], env, work, out / "install.log")
    report["sodium_built"] = True
    library = prefix / "lib/libsodium.a"
    report["sodium_library_sha256"] = hashlib.sha256(library.read_bytes()).hexdigest()
    # Force a final target link as well as an archive build. Cross targets are
    # never executed on the host or represented as installed-app evidence.
    flags = shlex.split(env.get("CFLAGS", ""))
    native_source = ROOT / "native/sodium_probe.c"
    link_kind = "-dynamiclib" if sdk else "-shared"
    native_probe = out / ("libsodium_probe.dylib" if sdk else "libsodium_probe.so")
    run([compiler, *flags, link_kind, str(native_source), "-I", str(prefix / "include"),
         str(library), "-o", str(native_probe)], env, work, out / "native-link.log")
    report["native_dependency_linked"] = True
    if args.target == "macos-arm64" and platform.machine() == "arm64":
        executable = out / "sodium-probe"
        run([compiler, *flags, "-DFLASH_PROBE_MAIN", str(native_source),
             "-I", str(prefix / "include"), str(library), "-o", str(executable)],
            env, work, out / "native-host-link.log")
        run([str(executable)], env, work, out / "native-host-run.log")
        report["native_host_probe_passed"] = True
    if args.sodium_only:
        return
    cargo = args.cargo or shutil.which("cargo")
    if not cargo:
        raise ValueError("Rust cargo missing; install pinned toolchain, resolve Cargo.lock, then fetch dependencies")
    if not (crate_root / "Cargo.lock").is_file():
        raise ValueError("Cargo.lock missing; dependency resolution has not passed, cannot claim a reproducible Rust build")
    env["FLASH_SODIUM_LIB_DIR"] = str(prefix / "lib")
    env["CARGO_TARGET_DIR"] = str(out / "rust")
    env[f"CARGO_TARGET_{target.upper().replace('-', '_')}_LINKER"] = compiler
    run([cargo, "rustc", "--locked", "--offline", "--release", "--target", target,
         "--lib", "--", "--print=native-static-libs"],
        env, crate_root, out / "cargo.log")
    report["rust_staticlib_built"] = True
    notes = re.findall(r"native-static-libs: (.+)", (out / "cargo.log").read_text())
    if not notes:
        raise ValueError("Rust did not report native link requirements")
    native_libraries = shlex.split(notes[-1])
    rust_library = out / "rust" / target / f"release/lib{library_name}.a"
    report["rust_library_sha256"] = hashlib.sha256(rust_library.read_bytes()).hexdigest()
    bridge = []
    if args.target.startswith("android"):
        bridge = [str(crate_root / ("platforms/android/flash_lan_jni.c" if args.core else "android/probe_jni.c"))]
    elif args.target.startswith("harmony"):
        bridge = [str(crate_root / ("platforms/harmony/flash_lan_napi.c" if args.core else "harmony/probe_napi.c"))]
        native_libraries += ["-lace_napi.z"]
    rust_dynamic = out / (f"lib{library_name}.dylib" if sdk else f"lib{library_name}.so")
    symbol = "_flash_lan_new" if args.core else "_flash_lan_probe_run"
    strict_link = [f"-Wl,-u,{symbol}"] if sdk else ["-Wl,--no-undefined"]
    run([compiler, *flags, link_kind, *strict_link, "-I", str(crate_root / "include"),
         "-I", str(prefix / "include"),
         "-L", str(prefix / "lib"), *bridge, str(rust_library), *native_libraries,
         "-o", str(rust_dynamic)],
        env, work, out / "rust-native-link.log")
    report["rust_bridge_linked"] = True
    if args.target == "macos-arm64" and platform.machine() == "arm64":
        swift = xcrun("--find", "swiftc")
        executable = out / "swift-rust-probe"
        run([swift, "-target", "arm64-apple-macosx15.0", "-sdk", xcrun("--show-sdk-path"),
             "-module-cache-path", str(out / "swift-module-cache"), "-I", str(crate_root / "include"),
             "-L", str(prefix / "lib"), str(crate_root / ("platforms/apple/main.swift" if args.core else "apple/main.swift")),
             str(rust_library), *native_libraries,
             "-o", str(executable)], env, work, out / "swift-rust-link.log")
        run([str(executable)], env, work, out / "swift-rust-run.log")
        report["swift_rust_probe_passed"] = True


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--target", choices=TARGETS, required=True)
    p.add_argument("--sodium-archive", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--sodium-only", action="store_true")
    p.add_argument("--cargo")
    p.add_argument("--core", action="store_true", help="build shared/FlashLAN instead of the primitive probe")
    p.add_argument("--developer-dir", type=Path, default=Path("/Applications/Xcode-beta.app/Contents/Developer"))
    p.add_argument("--harmony-native", type=Path, default=Path("/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/native"))
    p.add_argument("--android-ndk", type=Path)
    args = p.parse_args()
    output = args.output.resolve()
    if output == ROOT or ROOT in output.parents:
        p.error("--output must be outside the probe source directory")
    output.mkdir(parents=True, exist_ok=True)
    report = {"target": args.target, "component": "core" if args.core else "probe", "production_enabled": False,
              "sodium_built": False, "rust_staticlib_built": False,
              "native_dependency_linked": False, "native_host_probe_passed": False,
              "rust_bridge_linked": False, "swift_rust_probe_passed": False,
              "native_app_linked": False, "device_executed": False}
    try:
        build(args, report)
    except (OSError, ValueError, subprocess.CalledProcessError, tarfile.TarError) as error:
        report["error"] = str(error)
    (output / f"{args.target}.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return 1 if "error" in report else 0


if __name__ == "__main__":
    raise SystemExit(main())
