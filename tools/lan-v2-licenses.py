#!/usr/bin/env python3
"""Collect pinned crate/upstream/runtime notices from verified local inputs."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tarfile
import tomllib
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--cargo-home', type=Path, required=True)
p.add_argument('--sodium-archive', type=Path, required=True)
p.add_argument('--rust-doc', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
lock = root/'shared/FlashLAN/Cargo.lock'
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
if a.output.exists(): raise SystemExit('Use a new dedicated output directory')
a.output.mkdir(parents=True)
rows = []
for item in tomllib.loads(lock.read_text())['package']:
    if not item.get('source', '').startswith('registry+'): continue
    name = f"{item['name']}-{item['version']}"
    archives = list((a.cargo_home/'registry/cache').glob(f'*/{name}.crate'))
    if len(archives) != 1 or sha(archives[0]) != item['checksum']:
        raise SystemExit(f'{name}: missing or mismatched locked source archive')
    with tarfile.open(archives[0]) as tar:
        metadata = tomllib.loads(tar.extractfile(f'{name}/Cargo.toml').read().decode())['package']
        members = [m for m in tar.getmembers() if m.isfile() and
                   (Path(m.name).name.upper().startswith(('LICENSE', 'LICENCE', 'COPYING', 'NOTICE', 'AUTHORS', 'COPYRIGHT')) or
                    any(part.upper() == 'LICENSES' for part in Path(m.name).parts))]
        declared = metadata.get('license-file')
        if declared:
            member = tar.getmember(f'{name}/{declared}')
            if member not in members: members.append(member)
        if not members:
            if name not in ('matrix-pickle-0.2.3', 'matrix-pickle-derive-0.2.3'):
                raise SystemExit(f'{name}: no packaged license text; review before distribution')
            # Their .cargo_vcs_info.json pins the same upstream repository SHA.
            # Crate archives omit the workspace-root license, so preserve it
            # separately, fetched at that exact commit (no floating branch).
            extra = root/'shared/FlashLAN/licenses/matrix-pickle-LICENSE'
            if sha(extra) != '0d542e0c8804e39aa7f37eb00da5a762149dc682d7829451287e11b938e94594':
                raise SystemExit('matrix-pickle upstream license hash mismatch')
            dest = a.output/'crates'/name/'LICENSE'
            dest.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(extra, dest)
        for member in members:
            relative = Path(member.name)
            if relative.is_absolute() or '..' in relative.parts: raise SystemExit('Unsafe upstream path')
            dest = a.output/'crates'/relative
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(tar.extractfile(member).read())
    rows.append((name, metadata.get('license', 'license-file'), item['checksum']))
if sha(a.sodium_archive) != 'adbdd8f16149e81ac6078a03aca6fc03b592b89ef7b5ed83841c086191be3349':
    raise SystemExit('libsodium checksum mismatch')
with tarfile.open(a.sodium_archive) as tar:
    text = tar.extractfile('libsodium-1.0.22/LICENSE').read()
(a.output/'libsodium-1.0.22-LICENSE').write_bytes(text)
shutil.copytree(a.rust_doc/'licenses', a.output/'rust-1.99.1/licenses')
for f in a.rust_doc.glob('COPYRIGHT*'): shutil.copy2(f, a.output/'rust-1.99.1'/f.name)
shutil.copy2(root/'LICENSE', a.output/'Flash-MPL-2.0')
markdown = '# LAN v2 dependency notices\n\nGenerated from Cargo.lock-verified crate archives. This inventory includes test-only dependencies; full license texts accompany generated native artifacts.\n\n'
markdown += '| Crate | Declared license | Source SHA-256 |\n| --- | --- | --- |\n'
markdown += ''.join(f'| {name} | {license} | `{digest}` |\n' for name,license,digest in rows)
markdown += '\nlibsodium 1.0.22: ISC; Rust 1.99.1 standard library and compiler runtime notices are bundled separately. No upstream audit is represented as an audit of the Flash protocol.\n'
(a.output/'INVENTORY.md').write_text(markdown)
manifest = {'cargo_lock_sha256':sha(lock), 'files':{str(f.relative_to(a.output)):sha(f) for f in sorted(a.output.rglob('*')) if f.is_file()}}
(a.output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'Collected {len(rows)} locked crate notice sets at {a.output}')
