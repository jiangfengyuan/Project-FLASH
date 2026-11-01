#!/usr/bin/env python3
"""Capture existing empty screens on an explicitly named disposable emulator.

No app data seeding, design changes or benchmark claims. Navigation uses the
observed accessibility hierarchy; absent labels fail rather than guessed taps.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser()
parser.add_argument('--adb', required=True)
parser.add_argument('--serial', required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--apk-sha256', required=True)
parser.add_argument('--source-commit', required=True)
args = parser.parse_args()
assert args.serial.startswith('emulator-'), 'This helper must not modify a real device.'
args.output.mkdir(parents=True, exist_ok=False)

def adb(*command):
    return subprocess.run([args.adb, '-s', args.serial, *command], check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=40).stdout

def hierarchy():
    adb('shell', 'uiautomator', 'dump', '/sdcard/flash-hardening-ui.xml')
    data = adb('exec-out', 'cat', '/sdcard/flash-hardening-ui.xml')
    return data, ET.fromstring(data)

rows = []
for theme, night in [('light', 'no'), ('dark', 'yes')]:
    for font in ['1.0', '2.0']:
        adb('shell', 'cmd', 'uimode', 'night', night)
        adb('shell', 'settings', 'put', 'system', 'font_scale', font)
        adb('shell', 'am', 'force-stop', 'com.flash.app.native')
        adb('shell', 'am', 'start', '-W', '-n', 'com.flash.app.native/com.flash.app.MainActivity')
        _, tree = hierarchy()
        for label, screen in [('此刻', 'home'), ('记录', 'records'), ('回顾', 'review'), ('设置', 'settings')]:
            matches = [node for node in tree.iter('node')
                       if (node.get('text') or node.get('content-desc')) == label]
            assert matches, f'Navigation label missing: {theme}/{font}/{label}'
            def bounds(node):
                return [int(value) for value in re.findall(r'\d+', node.attrib['bounds'])]
            node = max(matches, key=lambda item: bounds(item)[3])
            left, top, right, bottom = bounds(node)
            adb('shell', 'input', 'tap', str((left + right) // 2), str((top + bottom) // 2))
            xml, tree = hierarchy()
            stem = f'{screen}-{theme}-font{font}'
            image = adb('exec-out', 'screencap', '-p')
            (args.output / (stem + '.png')).write_bytes(image)
            (args.output / (stem + '.xml')).write_bytes(xml)
            rows.append({'screen': screen, 'theme': theme, 'fontScale': font,
                         'png': stem + '.png', 'sha256': hashlib.sha256(image).hexdigest()})
            print('Captured ' + stem, flush=True)

manifest = {'kind': 'existing UI baseline; empty fictional app container',
            'realDevice': False, 'serial': args.serial, 'apkSHA256': args.apk_sha256,
            'sourceCommit': args.source_commit,
            'buildFingerprint': adb('shell', 'getprop', 'ro.build.fingerprint').decode().strip(),
            'configuration': 'Debug; default GLASS style, system theme',
            'os': adb('shell', 'getprop', 'ro.build.version.release').decode().strip(),
            'api': adb('shell', 'getprop', 'ro.build.version.sdk').decode().strip(),
            'display': adb('shell', 'wm', 'size').decode().strip(),
            'locale': (adb('shell', 'getprop', 'persist.sys.locale').decode().strip() or
                       adb('shell', 'getprop', 'ro.product.locale').decode().strip()),
            'timezone': adb('shell', 'getprop', 'persist.sys.timezone').decode().strip(),
            'captures': rows,
            'notVerified': ['populated records, emotion, calendar, Memory, editor/import states',
                            'Material style, expanded/fold/tablet sizes',
                            'TalkBack, touch bounds and contrast',
                            'real-device performance/energy/thermal/notifications/widgets']}
(args.output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
