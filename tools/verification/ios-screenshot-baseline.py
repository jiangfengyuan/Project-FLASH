#!/usr/bin/env python3
"""Read-only simulator screenshot recorder; navigation stays in native UI automation.

Only the named disposable simulator is allowed. Does not seed/reset stores, set
appearance, synthesize input, or modify original PNGs. Never a device benchmark.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import struct
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--screen', required=True)
parser.add_argument('--theme', choices=['light', 'dark'], required=True)
parser.add_argument('--text-size', required=True)
parser.add_argument('--state', required=True)
parser.add_argument('--data-phase', choices=['initial-empty','operator-one-idea','fictional-draft','reinstalled-empty'], required=True)
args = parser.parse_args()
assert re.fullmatch(r'[a-z0-9-]+', args.screen)
repo = Path(__file__).resolve().parents[2]
device_id = 'CC4C60DA-A92D-44A6-A90D-F47AEA86341D'
app_id = 'com.flash.app.ios'
env = {**os.environ, 'DEVELOPER_DIR': '/Applications/Xcode-beta.app/Contents/Developer'}

def sdk(*parts):
    return subprocess.run(['xcrun', 'simctl', *parts], check=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, env=env, timeout=40).stdout.decode().strip()

inventory = json.loads(sdk('list', 'devices', '--json'))
runtime, device = next((runtime, device) for runtime, devices in inventory['devices'].items()
                       for device in devices if device['udid'] == device_id)
assert device['name'] == 'CodexFlashHardening' and device['state'] == 'Booted'
theme, size = sdk('ui', device_id, 'appearance'), sdk('ui', device_id, 'content_size')
assert theme == args.theme and size == args.text_size, (theme, size)
args.output.mkdir(parents=True, exist_ok=True)
manifest_path = args.output / 'manifest.json'
manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else None
bundle = Path(sdk('get_app_container', device_id, app_id, 'app'))
if manifest is not None:
    actual = {p.relative_to(bundle).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in bundle.rglob('*') if p.is_file()}
    expected = {p['path']: p['sha256'] for p in manifest['installedBundleFiles']}
    assert actual == expected, 'Installed bundle changed; start a separate baseline manifest'
if manifest is None:
    app_info = plistlib.loads((bundle / 'Info.plist').read_bytes())
    bundle_files = [{'path': p.relative_to(bundle).as_posix(), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                    for p in sorted(bundle.rglob('*')) if p.is_file()]
    runtime_info = next(row for row in json.loads(sdk('list', 'runtimes', '--json'))['runtimes']
                        if row['identifier'] == runtime)
    preferences = Path(device['dataPath']) / 'Library/Preferences/.GlobalPreferences.plist'
    global_preferences = plistlib.loads(preferences.read_bytes()) if preferences.is_file() else {}
    manifest = {'kind': 'existing iOS UI screenshots; dedicated test simulator, no daily-use store',
        'sourceCommit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip(),
        'realDevice': False, 'device': device['name'], 'udid': device_id,
        'deviceTypeIdentifier': device.get('deviceTypeIdentifier'), 'runtime': runtime_info['name'],
        'osVersion': runtime_info['version'], 'osBuild': runtime_info['buildversion'],
        'appIdentifier': app_id, 'appVersion': app_info['CFBundleShortVersionString'],
        'appBuild': app_info['CFBundleVersion'],
        'xcodeBuild': app_info.get('DTXcodeBuild'), 'sdkName': app_info.get('DTSDKName'), 'configuration': 'Debug; CODE_SIGNING_ALLOWED=NO',
        'locale': global_preferences.get('AppleLocale', 'not available in global preferences'),
        'languages': global_preferences.get('AppleLanguages', []),
        'timezone': 'record separately from simulator settings; not inferred from host',
        'installedBundleFiles': bundle_files, 'captures': [],
        'notVerified': ['physical devices, thermal, battery, notification/widget behavior',
                        'VoiceOver traversal, contrast and minimum touch bounds',
                        'other representative screen sizes and uncaptured states']}
stem = f'{args.screen}-{theme}-{size}'
target = args.output / (stem + '.png')
assert not target.exists(), 'Refuse to overwrite a baseline'
sdk('io', device_id, 'screenshot', '--type=png', str(target.resolve()))
raw = target.read_bytes()
assert raw[:8] == b'\x89PNG\r\n\x1a\n'
width, height = struct.unpack('>II', raw[16:24])
manifest['captures'].append({'screen': args.screen, 'state': args.state,
    'theme': theme, 'textSize': size, 'dataPhase': args.data_phase,
    'width': width, 'height': height,
    'png': target.name, 'sha256': hashlib.sha256(raw).hexdigest(),
    'capturedAtUTC': datetime.datetime.now(datetime.timezone.utc).isoformat()})
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'file': str(target), 'theme': theme, 'textSize': size,
                  'dimensions': [width, height]}, ensure_ascii=False))
