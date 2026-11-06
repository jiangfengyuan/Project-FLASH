#!/usr/bin/env python3
"""Check declarations and production-source quarantine; optional built manifests.

This is a static regression gate, not proof of device network behavior.
"""
import argparse
import json
from pathlib import Path
import plistlib
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--ios-app', type=Path)
parser.add_argument('--macos-app', type=Path)
parser.add_argument('--android-manifest', type=Path)
parser.add_argument('--harmony-module', type=Path)
args = parser.parse_args()
checked = []

def apple(path):
    data = plistlib.loads(path.read_bytes())
    for key in ('NSBonjourServices', 'NSLocalNetworkUsageDescription',
                'com.apple.security.network.client', 'com.apple.security.network.server'):
        assert key not in data, (str(path), key)
    checked.append(str(path))

def android(path):
    names = {p.attrib.get('{http://schemas.android.com/apk/res/android}name')
             for p in ET.parse(path).getroot().iter('uses-permission')}
    # ACCESS_NETWORK_STATE is merged by WorkManager for its network tracker;
    # retain that dependency capability rather than disabling reminder internals.
    for name in ('INTERNET', 'CHANGE_WIFI_MULTICAST_STATE', 'NEARBY_WIFI_DEVICES'):
        assert 'android.permission.' + name not in names, (str(path), name)
    checked.append(str(path))

def harmony(path):
    assert 'ohos.permission.INTERNET' not in path.read_text(), str(path)
    checked.append(str(path))

for name in ('ios/FlashInfo.plist', 'macos/FlashInfo.plist', 'macos/Flash.entitlements',
             'ios/Flash.entitlements', 'ios/FlashWidget.entitlements'):
    apple(ROOT / name)
android(ROOT / 'android/app/src/main/AndroidManifest.xml')
harmony(ROOT / 'harmonyos/entry/src/main/module.json5')

for name in ('ios/Flash', 'ios/FlashWidget', 'macos/Flash',
             'macos/FlashWidget', 'shared/FlashKit/Sources', 'android/app/src/main',
             'harmonyos/entry/src/main/ets'):
    for path in (ROOT / name).rglob('*'):
        if path.suffix not in ('.swift', '.kt', '.ets'): continue
        text = path.read_text()
        assert not re.search(r'\b(?:NWListener|NWBrowser|NWConnection|NsdManager|MulticastLock)\b', text), str(path)
        assert not re.search(r'\b(?:LocalBackupSender|LocalBackupReceiver|LanHandshake)\b', text), str(path)
    checked.append(name)

if args.ios_app:
    apple(args.ios_app / 'Info.plist')
    for extension in (args.ios_app / 'PlugIns').glob('*.appex'): apple(extension / 'Info.plist')
if args.macos_app: apple(args.macos_app / 'Contents/Info.plist')
if args.android_manifest: android(args.android_manifest)
if args.harmony_module: harmony(args.harmony_module)
print(json.dumps({'passed': True, 'kind': 'static declarations and production-source checks',
                  'checked': checked}, ensure_ascii=False, indent=2))
