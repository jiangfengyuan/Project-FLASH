// HarmonyCapabilities：fake canIUse 与受限 kit 探测，验证能力存在/缺失与抛错时的降级。
const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');

const SYSCAPS = {
  agentFrameworkSupported: 'SystemCapability.AI.Agent.AgentKit',
  agentRuntimeSupported: 'SystemCapability.Ability.AgentRuntime.Core',
  fileSandboxShareSupported: 'SystemCapability.FileManagement.AppFileService',
  notificationSettingsSupported: 'SystemCapability.Notification.NotificationSettings',
  systemShareSupported: 'SystemCapability.Collaboration.SystemShare'
};

// null 覆盖绕过 ets-loader 的默认 mock，加载真实 data/HarmonyCapabilities.ets。
function loadCapabilities(kits = {}) {
  const load = createLoader({
    'data/HarmonyCapabilities': null,
    '@kit.ArkUI': { floatingBall: { isFloatingBallEnabled:
      kits.floatingBall ?? (() => { throw new Error('no floating ball'); }) } },
    '@kit.LiveViewKit': { liveViewManager: { isLiveViewEnabled:
      kits.liveView ?? (async () => { throw new Error('no live view'); }) } },
    '@kit.NearLinkKit': { manager: { isNearLinkSupported:
      kits.nearLink ?? (() => { throw new Error('no near link'); }) } }
  });
  return load('data/HarmonyCapabilities').HarmonyCapabilities;
}

function withCanIUse(impl, fn) {
  const previous = globalThis.canIUse;
  if (impl === undefined) delete globalThis.canIUse;
  else globalThis.canIUse = impl;
  return Promise.resolve()
    .then(fn)
    .finally(() => {
      if (previous === undefined) delete globalThis.canIUse;
      else globalThis.canIUse = previous;
    });
}

test('all capabilities present yields a fully supported snapshot', async () => {
  const Capabilities = loadCapabilities({
    floatingBall: () => true,
    liveView: async () => true,
    nearLink: () => true
  });
  await withCanIUse(() => true, async () => {
    const snapshot = await Capabilities.inspect();
    assert.deepEqual(snapshot, {
      nearLinkSupported: true,
      floatingBallSupported: true,
      liveViewEnabled: true,
      agentFrameworkSupported: true,
      agentRuntimeSupported: true,
      fileSandboxShareSupported: true,
      notificationSettingsSupported: true,
      systemShareSupported: true
    });
  });
});

test('a host without canIUse reports every syscap as unsupported', async () => {
  const Capabilities = loadCapabilities({
    floatingBall: () => true,
    liveView: async () => true,
    nearLink: () => true
  });
  await withCanIUse(undefined, async () => {
    const snapshot = await Capabilities.inspect();
    for (const field of Object.keys(SYSCAPS)) {
      assert.equal(snapshot[field], false, `${field} degrades without canIUse`);
    }
    assert.equal(snapshot.nearLinkSupported, true, 'kit probes do not depend on canIUse');
    assert.equal(snapshot.floatingBallSupported, true);
    assert.equal(snapshot.liveViewEnabled, true);
  });
});

test('a throwing canIUse degrades every syscap to unsupported', async () => {
  const Capabilities = loadCapabilities();
  await withCanIUse(() => { throw new Error('canIUse unavailable'); }, async () => {
    const snapshot = await Capabilities.inspect();
    for (const field of Object.keys(SYSCAPS)) {
      assert.equal(snapshot[field], false, `${field} degrades on canIUse failure`);
    }
  });
});

test('each syscap string feeds exactly its own snapshot field', async () => {
  const Capabilities = loadCapabilities();
  for (const [field, syscap] of Object.entries(SYSCAPS)) {
    const seen = [];
    await withCanIUse(queried => { seen.push(queried); return queried === syscap; }, async () => {
      const snapshot = await Capabilities.inspect();
      for (const other of Object.keys(SYSCAPS)) {
        assert.equal(snapshot[other], other === field,
          `${syscap} only lights up ${field}`);
      }
    });
    assert.deepEqual(new Set(seen), new Set(Object.values(SYSCAPS)),
      'every probe asks canIUse for a known syscap');
  }
});

test('kit probes that throw degrade to false without affecting syscap fields', async () => {
  const Capabilities = loadCapabilities({
    floatingBall: () => { throw new Error('denied'); },
    liveView: async () => { throw new Error('denied'); },
    nearLink: () => { throw new Error('denied'); }
  });
  await withCanIUse(() => true, async () => {
    const snapshot = await Capabilities.inspect();
    assert.equal(snapshot.nearLinkSupported, false);
    assert.equal(snapshot.floatingBallSupported, false);
    assert.equal(snapshot.liveViewEnabled, false);
    assert.equal(snapshot.systemShareSupported, true, 'syscap probes stay independent');
  });
});

test('a rejected liveView promise resolves to disabled', async () => {
  const Capabilities = loadCapabilities({
    floatingBall: () => false,
    liveView: async () => Promise.reject(new Error('not ready')),
    nearLink: () => true
  });
  await withCanIUse(() => false, async () => {
    const snapshot = await Capabilities.inspect();
    assert.equal(snapshot.liveViewEnabled, false);
    assert.equal(snapshot.nearLinkSupported, true, 'other kit probes are unaffected');
  });
});
