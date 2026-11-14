// 应用锁：状态机（宽限期、自动弹出一次、无密码放行）+ 运行时（冷启动读设置、认证结果映射、开关拒绝）
// + 页面接线（锁定层盖住编辑浮层、快速记录在锁定层之上、权限声明）。
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createLoader } = require('./ets-loader.cjs');

const ets = path.resolve(__dirname, '../entry/src/main/ets');

function env(overrides = {}) {
  const state = { enabled: true, available: true, now: 1_800_000_000_000, ...overrides };
  const { AppLockController, AppLockPolicy, AppLockAuthResult, AppLockToggleStart, AppLockToggleOutcome } =
    createLoader()('data/AppLock');
  const lock = new AppLockController(() => state.enabled, () => state.available, new AppLockPolicy(60000), () => state.now);
  return { state, lock, AppLockPolicy, AppLockAuthResult, AppLockToggleStart, AppLockToggleOutcome };
}

test('policy honours grace period and clock rollback', () => {
  const { AppLockPolicy } = env();
  const policy = new AppLockPolicy(60000);
  const t = 1_800_000_000_000;
  assert.equal(policy.shouldLockOnReturn(false, t, t + 3_600_000), false);
  assert.equal(policy.shouldLockOnReturn(true, undefined, t), false);
  assert.equal(policy.shouldLockOnReturn(true, t, t + 59_999), false);
  assert.equal(policy.shouldLockOnReturn(true, t, t + 60_000), true);
  assert.equal(policy.shouldLockOnReturn(true, t, t - 1), true);
  assert.equal(new AppLockPolicy(-1).gracePeriodMs, 0);
});

test('cold start locks only when enabled and the device has a lock screen', () => {
  assert.equal(env().lock.isLocked(), true);
  assert.equal(env({ enabled: false }).lock.isLocked(), false);
  assert.equal(env({ available: false }).lock.isLocked(), false);
});

test('unlock, cancel, failure and grace period', () => {
  const { state, lock, AppLockAuthResult } = env();
  const seen = [];
  lock.setListener(snapshot => seen.push(snapshot));
  assert.equal(lock.beginUnlock(), true);
  assert.equal(lock.beginUnlock(), false, 'second tap while the widget is up is ignored');
  lock.finishUnlock(AppLockAuthResult.CANCELLED);
  assert.deepEqual(lock.snapshot(), { locked: true, lastAttemptFailed: false, authenticating: false });
  lock.beginUnlock();
  lock.finishUnlock(AppLockAuthResult.FAILED);
  assert.equal(lock.snapshot().lastAttemptFailed, true);
  lock.beginUnlock();
  lock.finishUnlock(AppLockAuthResult.SUCCESS);
  assert.equal(lock.isLocked(), false);
  assert.ok(seen.length >= 6, 'every transition is mirrored to the listener');

  lock.onBackground(); state.now += 30_000; lock.onForeground();
  assert.equal(lock.isLocked(), false);
  lock.onBackground(); state.now += 61_000; lock.onForeground();
  assert.equal(lock.isLocked(), true);
});

test('auth widget backgrounding the ability does not relock', () => {
  const { state, lock, AppLockAuthResult } = env();
  assert.equal(lock.beginUnlock(), true);
  lock.onBackground();
  state.now += 120_000;
  lock.onForeground();
  lock.finishUnlock(AppLockAuthResult.SUCCESS);
  lock.onForeground();
  assert.equal(lock.isLocked(), false);
});

test('auto prompt fires once per lock and never loops', () => {
  const { lock, AppLockAuthResult } = env();
  assert.equal(lock.consumeAutoPrompt(), true);
  assert.equal(lock.consumeAutoPrompt(), false);
  lock.beginUnlock(); lock.finishUnlock(AppLockAuthResult.SUCCESS);
  lock.lockNow();
  assert.equal(lock.consumeAutoPrompt(), true);
});

test('lock screen password removed while locked lets the user in', () => {
  const { state, lock } = env();
  state.available = false;
  assert.equal(lock.beginUnlock(), false);
  assert.equal(lock.isLocked(), false);
});

test('toggle rules', () => {
  const { state, lock, AppLockAuthResult, AppLockToggleStart, AppLockToggleOutcome } = env({ enabled: false });
  assert.equal(lock.beginToggle(true), AppLockToggleStart.VERIFY);
  assert.equal(lock.beginToggle(true), AppLockToggleStart.BUSY);
  assert.equal(lock.finishToggle(true, AppLockAuthResult.SUCCESS), AppLockToggleOutcome.APPLY);
  lock.beginToggle(true);
  assert.equal(lock.finishToggle(true, AppLockAuthResult.CANCELLED), AppLockToggleOutcome.NONE);
  lock.beginToggle(false);
  assert.equal(lock.finishToggle(false, AppLockAuthResult.FAILED), AppLockToggleOutcome.REFUSE_FAILED);
  state.available = false;
  assert.equal(lock.beginToggle(true), AppLockToggleStart.REFUSE_UNAVAILABLE);
  assert.equal(lock.beginToggle(false), AppLockToggleStart.APPLY);
});

function runtimeHarness({ stored = false, available = true, resultCode = 12500000 } = {}) {
  const storage = new Map();
  globalThis.AppStorage = { setOrCreate: (key, value) => storage.set(key, value) };
  const prefs = { appLockEnabled: stored };
  const titles = [];
  const authKit = {
    userAuth: {
      UserAuthType: { PIN: 1, FACE: 2, FINGERPRINT: 4 },
      AuthTrustLevel: { ATL1: 10000 },
      UserAuthResultCode: { SUCCESS: 12500000, CANCELED: 12500003, TIMEOUT: 12500004, NOT_ENROLLED: 12500010, CANCELED_FROM_WIDGET: 12500011 },
      getAvailableStatus: () => { if (!available) throw new Error('12500010'); },
      getUserAuthInstance: (authParam, widgetParam) => {
        titles.push(widgetParam.title);
        assert.ok(authParam.authType.includes(1), 'PIN is always offered as fallback');
        let callback;
        return {
          on: (_type, cb) => { callback = cb; },
          off: () => {},
          start: () => queueMicrotask(() => callback.onResult({ result: harness.resultCode })),
        };
      },
    },
  };
  const load = createLoader({
    '@kit.UserAuthenticationKit': authKit,
    '@kit.CryptoArchitectureKit': { cryptoFramework: { createRandom: () => ({ generateRandomSync: n => ({ data: new Uint8Array(n) }) }) } },
    '@kit.ArkData': { preferences: { getPreferencesSync: () => ({
      getSync: (key, fallback) => (key in prefs ? prefs[key] : fallback),
      putSync: (key, value) => { prefs[key] = value; },
      flush: async () => {},
    }) } },
  });
  const harness = { storage, prefs, titles, resultCode, setAvailable: v => { available = v; } };
  const { appLockRuntime } = load('state/AppLockRuntime');
  appLockRuntime.install({});
  harness.runtime = appLockRuntime;
  return harness;
}

const tick = () => new Promise(resolve => setTimeout(resolve, 0));

test('runtime: cold start with the setting on is locked before the page loads', async () => {
  const h = runtimeHarness({ stored: true });
  assert.equal(h.storage.get('flashAppLocked'), true);
  assert.equal(h.storage.get('flashAppLockEnabled'), true);
  h.runtime.autoPromptIfNeeded();
  await tick();
  assert.equal(h.storage.get('flashAppLocked'), false);
  assert.equal(h.titles.length, 1);
  h.runtime.autoPromptIfNeeded();
  assert.equal(h.titles.length, 1, 'no second automatic prompt');
});

test('runtime: default off, enabling verifies first and persists', async () => {
  const h = runtimeHarness();
  assert.equal(h.storage.get('flashAppLocked'), false);
  const messages = [];
  h.runtime.toggle(true, m => messages.push(m));
  await tick();
  assert.deepEqual(messages, []);
  assert.equal(h.prefs.appLockEnabled, true);
  assert.equal(h.storage.get('flashAppLockEnabled'), true);
});

test('runtime: cancelled or failed verification keeps the switch where it was', async () => {
  const h = runtimeHarness({ resultCode: 12500003 });
  h.runtime.toggle(true, () => {});
  await tick();
  assert.equal(h.prefs.appLockEnabled, false);
  assert.equal(h.storage.get('flashAppLockEnabled'), false);
  h.resultCode = 12500001;
  const messages = [];
  h.runtime.toggle(true, m => messages.push(m));
  await tick();
  assert.equal(messages.length, 1);
  assert.equal(h.prefs.appLockEnabled, false);
});

test('runtime: refuses to enable without a lock screen password, always allows disabling', async () => {
  const h = runtimeHarness({ stored: true, available: false });
  assert.equal(h.storage.get('flashAppLocked'), false, 'never locks the user out');
  const messages = [];
  h.runtime.toggle(false, m => messages.push(m));
  await tick();
  assert.equal(h.prefs.appLockEnabled, false);
  h.runtime.toggle(true, m => messages.push(m));
  await tick();
  assert.equal(messages.length, 1);
  assert.equal(h.prefs.appLockEnabled, false);
});

test('runtime: NOT_ENROLLED only unlocks when there is no lock screen password at all', async () => {
  const h = runtimeHarness({ stored: true, resultCode: 12500010 });
  h.runtime.requestUnlock();
  await tick();
  assert.equal(h.storage.get('flashAppLocked'), true);
  assert.equal(h.storage.get('flashAppLockFailed'), true);
});

test('wiring: lock layer covers edit dialogs, quick capture stays above it, permission declared', () => {
  const index = fs.readFileSync(path.join(ets, 'pages/Index.ets'), 'utf8');
  const build = index.slice(index.indexOf('  build() {'));
  const lockAt = build.indexOf('this.appLockOverlay()');
  assert.ok(lockAt > build.indexOf('EditLogDialog({'));
  assert.ok(lockAt > build.indexOf('TaskEditorDialog({'));
  assert.ok(lockAt > build.indexOf('DestructiveConfirmDialog({'));
  assert.ok(build.indexOf('QuickInputDialog({', lockAt) > lockAt, 'quick capture is rendered above the lock layer');
  assert.match(build, /!this\.appLocked && this\.logs\.quickCategory !== ''/);
  const ability = fs.readFileSync(path.join(ets, 'entryability/EntryAbility.ets'), 'utf8');
  assert.ok(ability.indexOf('appLockRuntime.install') < ability.indexOf('this.deliverEntry(want)'));
  assert.match(ability, /onBackground\(\): void \{\s*appLockRuntime\.controller\.onBackground\(\)/);
  const moduleJson = fs.readFileSync(path.resolve(ets, '../module.json5'), 'utf8');
  assert.match(moduleJson, /ohos\.permission\.ACCESS_BIOMETRIC/);
  const profile = fs.readFileSync(path.join(ets, 'pages/ProfilePage.ets'), 'utf8');
  assert.match(profile, /this\.privacyGroup\(\)/);
});
