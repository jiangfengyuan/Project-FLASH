// Runs the actual controller/store sources on Node with explicit platform fakes.
// This covers business behavior, not ArkUI rendering or native RDB behavior.
const fs = require('node:fs');
const path = require('node:path');
const { randomUUID } = require('node:crypto');

function compiler() {
  if (process.env.FLASH_TYPESCRIPT_PATH) return require(process.env.FLASH_TYPESCRIPT_PATH);
  try { return require('typescript'); } catch (_) {}
  const bundled = '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript';
  if (fs.existsSync(bundled)) return require(bundled);
  throw new Error('Install TypeScript or set FLASH_TYPESCRIPT_PATH to its module directory.');
}

const ts = compiler();
const root = path.resolve(__dirname, '../entry/src/main/ets');

// Node-fs-backed fileIo fake so quarantine files land on the real filesystem
// under whatever filesDir the test context provides. Override per test to
// inject write failures.
function nodeFileIo() {
  const C = fs.constants;
  return {
    OpenMode: { READ_ONLY: C.O_RDONLY, READ_WRITE: C.O_RDWR, CREATE: C.O_CREAT, TRUNC: C.O_TRUNC },
    accessSync: p => fs.existsSync(p),
    mkdirSync: (p, recursive) => fs.mkdirSync(p, { recursive: !!recursive }),
    unlinkSync: p => fs.unlinkSync(p),
    openSync: (p, mode = C.O_RDONLY) => ({ fd: fs.openSync(p, mode) }),
    writeSync: (fd, data, options) => fs.writeSync(fd, data, null, options?.encoding ?? 'utf-8'),
    readSync: (fd, buffer, options) =>
      fs.readSync(fd, Buffer.from(buffer), 0, options?.length ?? buffer.byteLength, 0),
    statSync: fd => ({ size: fs.fstatSync(fd).size }),
    closeSync: file => fs.closeSync(typeof file === 'object' ? file.fd : file)
  };
}

class NodeTextDecoder extends require('node:util').TextDecoder {
  static create() { return new NodeTextDecoder('utf-8'); }
  decodeToString(bytes) { return this.decode(bytes); }
}

function createLoader(overrides = {}) {
  const cache = new Map();
  const defaults = {
    '@kit.AbilityKit': { bundleManager: {
      BundleFlag: { GET_BUNDLE_INFO_WITH_APPLICATION: 1 },
      getBundleInfoForSelf: async () => ({ versionName: '0.1.0' }) } },
    '@kit.ArkTS': { util: { generateRandomUUID: () => randomUUID(),
      TextDecoder: NodeTextDecoder,
      TextEncoder: class { encodeInto(value) { return new TextEncoder().encode(value); } } } },
    '@kit.ArkData': { relationalStore: { ConflictResolution: { ON_CONFLICT_REPLACE: 1 } } },
    '@kit.CoreFileKit': { fileIo: nodeFileIo() },
    '@kit.LocalizationKit': { i18n: { getTimeZone: () => ({ getID: () => 'UTC', getOffset: () => 0 }) } },
    'data/BackupFiles': { BackupFiles: {
      exportJSON: async () => {},
      importJSON: async () => { throw new Error('Configure the file picker fake for this test'); }
    } },
    'data/LocalBackupTransfer': {},
    'data/TaskReminderScheduler': { TaskReminderScheduler: { rebuild: async () => {} } },
    'data/HarmonyCapabilities': { HarmonyCapabilities: { inspect: async () => ({
      nearLinkSupported: false, floatingBallSupported: false, liveViewEnabled: false
    }) } }
  };
  const mocks = { ...defaults, ...overrides };
  function load(name) {
    // A null override loads the real module, bypassing the default mock.
    if (Object.hasOwn(mocks, name) && mocks[name] !== null) return mocks[name];
    if (cache.has(name)) return cache.get(name).exports;
    if (name.startsWith('@')) throw new Error(`Missing explicit platform fake: ${name}`);
    const filename = path.join(root, name + '.ets');
    const source = fs.readFileSync(filename, 'utf8').replace(/^@Observed\s*$/gm, '');
    const compiled = ts.transpileModule(source, {
      compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS },
      fileName: filename.replace(/\.ets$/, '.ts'), reportDiagnostics: true
    });
    const errors = (compiled.diagnostics ?? []).filter(d => d.category === ts.DiagnosticCategory.Error);
    if (errors.length) throw new Error(ts.formatDiagnosticsWithColorAndContext(errors, {
      getCanonicalFileName: f => f, getCurrentDirectory: () => root, getNewLine: () => '\n'
    }));
    const module = { exports: {} };
    cache.set(name, module);
    const localRequire = specifier => load(specifier.startsWith('.') ?
      path.posix.normalize(path.posix.join(path.posix.dirname(name), specifier)) : specifier);
    new Function('require', 'module', 'exports', compiled.outputText)(localRequire, module, module.exports);
    return module.exports;
  }
  return load;
}

module.exports = { createLoader };
