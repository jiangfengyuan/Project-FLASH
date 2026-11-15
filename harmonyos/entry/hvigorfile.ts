import { hapTasks } from '@ohos/hvigor-ohos-plugin';
import { HvigorNode, HvigorPlugin } from '@ohos/hvigor';
// Hvigor's configuration compiler does not expose @types/node. These are Node
// built-ins in the build process, never application ArkTS or network imports.
declare function require(name: string): any;
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const verifiedNativeLibraries: HvigorPlugin = {
  pluginId: 'flash-lan-native-artifacts',
  apply(node: HvigorNode) {
    const entry = node.getNodePath();
    const artifacts = path.resolve(entry, '../../shared/FlashLAN/artifacts');
    const manifestPath = path.join(artifacts, 'manifest.json');
    if (!fs.existsSync(manifestPath)) throw new Error('LAN native artifacts missing: run tools/package-lan-v2.py --install-harmony');
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    for (const abi of ['arm64-v8a', 'x86_64']) {
      const library = path.join(entry, 'libs', abi, 'libflash_lan.so');
      const expected = manifest.files[`harmony/${abi}/libflash_lan.so`];
      if (!expected || !fs.existsSync(library) || crypto.createHash('sha256').update(fs.readFileSync(library)).digest('hex') !== expected) {
        throw new Error(`Missing/stale LAN native library for ${abi}; regenerate verified artifacts`);
      }
    }
  }
};
export default {
  system: hapTasks,
  plugins: [verifiedNativeLibraries]
}
