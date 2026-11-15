#!/usr/bin/env python3
"""Package verified local core builds for native app integration. No enablement.

Requires all compatibility targets from tools/lan-v2-probe/build.py --core.
Never downloads code, signs, publishes, changes permissions or enables LAN.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / 'shared/FlashLAN'
spec = importlib.util.spec_from_file_location('lan_builder', ROOT / 'tools/lan-v2-probe/build.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)
APPLE = ['macos-arm64', 'macos-x86_64', 'ios-arm64', 'ios-sim-arm64', 'ios-sim-x86_64']
ANDROID = {'android-arm64': 'arm64-v8a', 'android-armv7': 'armeabi-v7a',
           'android-x86': 'x86', 'android-x86_64': 'x86_64'}
HARMONY = {'harmony-arm64': 'arm64-v8a', 'harmony-x86_64': 'x86_64'}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--build-root', type=Path, required=True)
    p.add_argument('--output', type=Path, default=CORE / 'artifacts')
    p.add_argument('--licenses', type=Path, required=True, help='verified output of tools/lan-v2-licenses.py')
    p.add_argument('--install-harmony', action='store_true', help='copy generated libraries into ignored entry/libs')
    args = p.parse_args()
    notices = json.loads((args.licenses / 'manifest.json').read_text())
    if notices['cargo_lock_sha256'] != digest(CORE / 'Cargo.lock'):
        raise SystemExit('License inventory belongs to a different Cargo.lock')
    actual = {str(f.relative_to(args.licenses)) for f in args.licenses.rglob('*') if f.is_file()}
    if actual != set(notices['files']) | {'manifest.json'} or any(f.is_symlink() for f in args.licenses.rglob('*')):
        raise SystemExit('License directory contains unlisted files or symlinks')
    for relative, checksum in notices['files'].items():
        item = args.licenses / relative
        if item.is_symlink() or not item.resolve().is_relative_to(args.licenses.resolve()) or digest(item) != checksum:
            raise SystemExit(f'License input mismatch: {relative}')
    source = builder.source_digest(CORE)
    reports = {}
    libraries = {}
    for target in [*APPLE, *ANDROID, *HARMONY]:
        report = json.loads((args.build_root / f'{target}.json').read_text())
        if report.get('component') != 'core' or report.get('error') or not report.get('rust_bridge_linked'):
            raise SystemExit(f'{target}: native build/link gate did not pass')
        if report.get('source_sha256') != source:
            raise SystemExit(f'{target}: source drift; rebuild before packaging')
        triple = builder.TARGETS[target][0]
        library = args.build_root / target / 'rust' / triple / 'release/libflash_lan.a'
        if digest(library) != report['rust_library_sha256']:
            raise SystemExit(f'{target}: archive hash mismatch')
        bridge = args.build_root / target / ('libflash_lan.dylib' if target in APPLE else 'libflash_lan.so')
        if digest(bridge) != report.get('native_bridge_sha256'):
            raise SystemExit(f'{target}: native bridge hash mismatch')
        reports[target], libraries[target] = report, library
    output = args.output.resolve()
    if output == ROOT or output == CORE or output in CORE.parents:
        raise SystemExit('Output must be a dedicated generated-artifact directory')
    if output.exists():
        manifest_path = output / 'manifest.json'
        if not manifest_path.is_file() or json.loads(manifest_path.read_text()).get('wire_protocol') != 'FLASH-LAN/2':
            raise SystemExit('Existing output is not an owned LAN artifact directory; refusing to replace it')
    output.parent.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode-beta.app/Contents/Developer')
    with tempfile.TemporaryDirectory(prefix='flash-lan-package-', dir=output.parent) as tmp:
        stage = Path(tmp) / 'payload'; stage.mkdir()
        shutil.copytree(args.licenses, stage / 'NOTICES')
        apple = stage / 'apple'; apple.mkdir()
        mac = apple / 'macos/libflash_lan.a'; mac.parent.mkdir()
        sim = apple / 'simulator/libflash_lan.a'; sim.parent.mkdir()
        for result, targets in [(mac, ['macos-arm64', 'macos-x86_64']),
                                (sim, ['ios-sim-arm64', 'ios-sim-x86_64'])]:
            subprocess.run(['/usr/bin/xcrun', 'lipo', '-create', *[str(libraries[t]) for t in targets],
                            '-output', str(result)], env=env, check=True)
        framework = apple / 'CFlashLAN.xcframework'
        subprocess.run(['/Applications/Xcode-beta.app/Contents/Developer/usr/bin/xcodebuild', '-create-xcframework',
                        '-library', str(mac), '-headers', str(CORE / 'include'),
                        '-library', str(libraries['ios-arm64']), '-headers', str(CORE / 'include'),
                        '-library', str(sim), '-headers', str(CORE / 'include'),
                        '-output', str(framework)], env=env, check=True)
        for platform, targets in [('android', ANDROID), ('harmony', HARMONY)]:
            for target, abi in targets.items():
                origin = args.build_root / target / 'libflash_lan.so'
                dest = stage / platform / abi / origin.name
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(origin, dest)
        manifest = {
            'source_sha256': source, 'production_enabled': False,
            'wire_protocol': 'FLASH-LAN/2', 'rust': '1.99.1',
            'sodium_archive_sha256': builder.SODIUM_SHA256,
            'files': {str(f.relative_to(stage)): digest(f) for f in sorted(stage.rglob('*')) if f.is_file()},
            'targets': list(reports),
        }
        (stage / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
        # Recheck after packaging; do not install artifacts from a moving source.
        if builder.source_digest(CORE) != source:
            raise SystemExit('Source changed during packaging; no artifacts installed')
        if output.exists():
            previous = output.with_name(output.name + '.previous-' + uuid.uuid4().hex[:8])
            output.rename(previous)
        stage.rename(output)
    if args.install_harmony:
        for abi in HARMONY.values():
            origin = output / 'harmony' / abi / 'libflash_lan.so'
            destination = ROOT / 'harmonyos/entry/libs' / abi / origin.name
            destination.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as temp:
                temp.write(origin.read_bytes())
                staged = Path(temp.name)
            os.replace(staged, destination)
    print(f'Packaged native artifacts at {output}; LAN remains disabled')


if __name__ == '__main__':
    main()
