#!/usr/bin/env python3
"""Run the real JNI bridge on a host JVM; not Android device acceptance."""
import argparse
import os
from pathlib import Path
import re
import shlex
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--rust-lib', type=Path, required=True)
p.add_argument('--sodium-prefix', type=Path, required=True)
p.add_argument('--ndk', type=Path, required=True)
p.add_argument('--link-log', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--java-root', type=Path, default=Path('/Applications/Android Studio.app/Contents/jbr/Contents/Home'))
args = p.parse_args()
root = Path(__file__).resolve().parents[2]
out = args.output.resolve()
out.mkdir(parents=True, exist_ok=True)
flags = shlex.split(re.findall(r'native-static-libs: (.+)', args.link_log.read_text())[-1])
env = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode-beta.app/Contents/Developer')
# NDK jni.h is explicitly VM-neutral. -idirafter keeps host libc headers first.
headers = args.ndk / 'toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/include'
commands = [
    ['/usr/bin/xcrun', 'clang', '-dynamiclib', '-arch', 'arm64', '-I', str(root/'include'),
     '-idirafter', str(headers), '-I', str(args.sodium_prefix/'include'),
     str(root/'platforms/android/flash_lan_jni.c'), str(args.rust_lib), *flags,
     '-o', str(out/'libflash_lan.dylib')],
    [str(args.java_root/'bin/javac'), '--release', '17', '-d', str(out),
     str(root/'platforms/android/src/com/flash/app/data/LanNative.java'),
     str(root/'platforms/android/tests/com/flash/app/data/LanNativeSmoke.java')],
    [str(args.java_root/'bin/java'), '-Djava.library.path='+str(out), '-cp', str(out),
     'com.flash.app.data.LanNativeSmoke'],
]
with (out/'run.log').open('w') as log:
    for command in commands:
        log.write(shlex.join(command)+'\n'); log.flush()
        subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, check=True)
print('Host JVM JNI round-trip: PASS (not Android device acceptance)')
