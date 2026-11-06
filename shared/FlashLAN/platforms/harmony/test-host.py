#!/usr/bin/env python3
"""Run the actual N-API C bridge in Node on macOS, not a HarmonyOS device."""
import argparse
import os
from pathlib import Path
import re
import shlex
import subprocess
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--rust-lib', type=Path, required=True)
p.add_argument('--sodium-prefix', type=Path, required=True)
p.add_argument('--link-log', type=Path, required=True)
p.add_argument('--node-headers', type=Path, default=Path('/usr/local/include/node'))
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
core = Path(__file__).resolve().parents[2]
root = core.parents[1]
a.output.mkdir(parents=True, exist_ok=True)
shim = a.output / 'napi'; shim.mkdir(exist_ok=True)
(shim / 'native_api.h').write_text('#include <node_api.h>\n')
flags = shlex.split(re.findall(r'native-static-libs: (.+)', a.link_log.read_text())[-1])
addon = a.output / 'flash_lan.node'
env = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode-beta.app/Contents/Developer')
command = ['/usr/bin/xcrun', 'clang', '-dynamiclib', '-arch', 'arm64', '-undefined', 'dynamic_lookup',
           '-I', str(a.output), '-I', str(a.node_headers), '-I', str(core/'include'),
           '-I', str(a.sodium_prefix/'include'), str(core/'platforms/harmony/flash_lan_napi.c'),
           str(a.rust_lib), *flags, '-o', str(addon)]
with (a.output/'run.log').open('w') as log:
    log.write(shlex.join(command)+'\n'); log.flush()
    subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
    env['FLASH_LAN_NATIVE_NODE'] = str(addon.resolve())
    subprocess.run(['node', '--test', 'tests/lan-v2-native.test.cjs'], cwd=root/'harmonyos', env=env,
                   stdout=log, stderr=subprocess.STDOUT, check=True)
print('Host Node actual N-API/ArkTS transport tests: PASS (not HarmonyOS device acceptance)')
