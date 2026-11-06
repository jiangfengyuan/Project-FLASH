#!/usr/bin/env python3
"""Ban legacy LAN and verify the v2 minimum network declarations.

Historical command name retained for CI. Static checks do not constitute
physical-device or protocol acceptance and never enable the production gate.
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
NETWORK_KEYS = ('com.apple.security.network.client', 'com.apple.security.network.server')

def apple(path, main_info=False, mac_entitlements=False):
    data = plistlib.loads(path.read_bytes())
    if main_info:
        assert data.get('NSBonjourServices') == ['_flashbackup2._tcp'], str(path)
        assert data.get('NSLocalNetworkUsageDescription', '').strip(), str(path)
    else:
        assert 'NSBonjourServices' not in data and 'NSLocalNetworkUsageDescription' not in data, str(path)
    for key in NETWORK_KEYS:
        if mac_entitlements: assert data.get(key) is True, (str(path), key)
        else: assert key not in data, (str(path), key)
    checked.append(str(path))

def android(path):
    names = {p.attrib.get('{http://schemas.android.com/apk/res/android}name')
             for p in ET.parse(path).getroot().iter('uses-permission')}
    assert 'android.permission.INTERNET' in names, str(path)
    # NsdManager, min26 / target36: no raw multicast or Wi-Fi scan APIs.
    for name in ('CHANGE_WIFI_MULTICAST_STATE', 'NEARBY_WIFI_DEVICES', 'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION'):
        assert 'android.permission.' + name not in names, (str(path), name)
    checked.append(str(path))

def harmony(path):
    names = {p['name'] for p in json.loads(path.read_text())['module'].get('requestPermissions', [])}
    assert 'ohos.permission.INTERNET' in names, str(path)
    assert not names.intersection({'ohos.permission.GET_WIFI_INFO', 'ohos.permission.LOCATION',
                                   'ohos.permission.DISCOVER_BLUETOOTH', 'ohos.permission.DISTRIBUTED_DATASYNC'}), str(path)
    checked.append(str(path))

for name in ('ios/FlashInfo.plist', 'macos/FlashInfo.plist'): apple(ROOT / name, main_info=True)
for name in ('ios/Flash.entitlements', 'ios/FlashShare.entitlements', 'ios/FlashWidget.entitlements',
             'macos/FlashWidget.entitlements', 'ios/FlashShareInfo.plist', 'ios/FlashWidgetInfo.plist',
             'macos/FlashWidgetInfo.plist'): apple(ROOT / name)
apple(ROOT / 'macos/Flash.entitlements', mac_entitlements=True)
android(ROOT / 'android/app/src/main/AndroidManifest.xml')
harmony(ROOT / 'harmonyos/entry/src/main/module.json5')

network_owners = {
    'shared/FlashKit/Sources/FlashCore/Data/LocalBackupTransfer.swift',
    'shared/FlashKit/Sources/FlashCore/Data/SecureLanConnection.swift',
    'android/app/src/main/java/com/flash/app/data/LocalBackupTransfer.kt',
}
for name in ('ios/Flash', 'ios/FlashShare', 'ios/FlashWidget', 'macos/Flash', 'macos/FlashWidget',
             'shared/FlashKit/Sources', 'shared/FlashLAN/src', 'android/app/src/main', 'harmonyos/entry/src/main/ets'):
    for path in (ROOT / name).rglob('*'):
        if path.suffix not in ('.swift', '.kt', '.ets', '.rs'): continue
        source = path.read_text()
        assert not re.search(r'FLASH-AERO/1|_flashbackup\._tcp|\b(?:LocalBackupSender|LocalBackupReceiver|LanHandshake)\b', source), str(path)
        assert not re.search(r'\b(?:enteredPIN|enteredPin|lanPin|lanEnteredPin|pinSource)\b', source), str(path)
        if re.search(r'\b(?:NWListener|NWBrowser|NWConnection|NsdManager|MulticastLock)\b', source):
            assert str(path.relative_to(ROOT)) in network_owners, str(path)
    checked.append(name)

if args.ios_app:
    apple(args.ios_app / 'Info.plist', main_info=True)
    for extension in (args.ios_app / 'PlugIns').glob('*.appex'): apple(extension / 'Info.plist')
if args.macos_app:
    apple(args.macos_app / 'Contents/Info.plist', main_info=True)
    for extension in (args.macos_app / 'Contents/PlugIns').glob('*.appex'): apple(extension / 'Contents/Info.plist')
if args.android_manifest: android(args.android_manifest)
if args.harmony_module: harmony(args.harmony_module)
print(json.dumps({'passed': True, 'kind': 'legacy protocol ban and v2 minimum declarations',
                  'checked': checked}, ensure_ascii=False, indent=2))
