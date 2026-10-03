// Host tests for notification channel helpers: idempotent slot creation,
// low-version degradation of the semi-modal settings page, and the reminder
// channel binding inside TaskReminderScheduler. Platform kits are faked.
const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');

const SETTINGS_SYSCAP = 'SystemCapability.Notification.NotificationSettings';

function notificationKit(behavior = {}) {
  const calls = { getSlot: 0, addSlot: 0, openSettings: 0 };
  const notificationManager = {
    SlotType: { UNKNOWN_TYPE: 0, SOCIAL_COMMUNICATION: 1, SERVICE_INFORMATION: 2, CONTENT_INFORMATION: 3 },
    getSlot: async () => {
      calls.getSlot++;
      if (behavior.slotExists) return { type: 2 };
      throw Object.assign(new Error('not created'), { code: 1600001 });
    },
    addSlot: async () => {
      calls.addSlot++;
      if (behavior.addSlotFails) throw Object.assign(new Error('no memory'), { code: 1600012 });
    },
    requestEnableNotification: async () => {},
    openNotificationSettings: async () => {
      calls.openSettings++;
      if (behavior.openSettingsFails) throw Object.assign(new Error('already shown'), { code: 1600018 });
    }
  };
  return { calls, kit: { '@kit.NotificationKit': { notificationManager } } };
}

function withCanIUse(supported, fn) {
  const previous = globalThis.canIUse;
  globalThis.canIUse = syscap => supported.includes(syscap);
  return Promise.resolve().then(fn).finally(() => {
    if (previous === undefined) delete globalThis.canIUse;
    else globalThis.canIUse = previous;
  });
}

test('reminder slot type is the service-information channel', () => {
  const { kit } = notificationKit();
  const load = createLoader(kit);
  const { NotificationChannels } = load('data/NotificationChannels');
  assert.equal(NotificationChannels.reminderSlotType(), 2);
});

test('ensureReminderSlot creates the channel exactly once across calls', async () => {
  const { calls, kit } = notificationKit();
  const load = createLoader(kit);
  const { NotificationChannels } = load('data/NotificationChannels');
  await NotificationChannels.ensureReminderSlot({});
  await NotificationChannels.ensureReminderSlot({});
  assert.equal(calls.addSlot, 1, 'second call must reuse the in-flight creation');
});

test('ensureReminderSlot skips creation when the channel already exists', async () => {
  const { calls, kit } = notificationKit({ slotExists: true });
  const load = createLoader(kit);
  const { NotificationChannels } = load('data/NotificationChannels');
  await NotificationChannels.ensureReminderSlot({});
  assert.equal(calls.getSlot, 1);
  assert.equal(calls.addSlot, 0, 'existing channel must not be recreated');
});

test('a failed channel creation resolves quietly and is retried next time', async () => {
  const { calls, kit } = notificationKit({ addSlotFails: true });
  const load = createLoader(kit);
  const { NotificationChannels } = load('data/NotificationChannels');
  await NotificationChannels.ensureReminderSlot({});
  assert.equal(calls.addSlot, 1);
  await NotificationChannels.ensureReminderSlot({});
  assert.equal(calls.addSlot, 2, 'failure clears the cache so rebuild retries');
});

test('openAppNotificationSettings degrades to false without the settings syscap', async () => {
  const { calls, kit } = notificationKit();
  const load = createLoader(kit);
  const { NotificationChannels } = load('data/NotificationChannels');
  delete globalThis.canIUse;
  assert.equal(NotificationChannels.supportsNotificationSettings(), false);
  assert.equal(await NotificationChannels.openAppNotificationSettings({}), false);
  assert.equal(calls.openSettings, 0, 'unsupported devices must not call the API');
});

test('openAppNotificationSettings opens the semi-modal page when supported', async () => {
  const { calls, kit } = notificationKit();
  const load = createLoader(kit);
  const { NotificationChannels } = load('data/NotificationChannels');
  await withCanIUse([SETTINGS_SYSCAP], async () => {
    assert.equal(NotificationChannels.supportsNotificationSettings(), true);
    assert.equal(await NotificationChannels.openAppNotificationSettings({}), true);
    assert.equal(calls.openSettings, 1);
  });
});

test('openAppNotificationSettings reports false when the system refuses', async () => {
  const { kit } = notificationKit({ openSettingsFails: true });
  const load = createLoader(kit);
  const { NotificationChannels } = load('data/NotificationChannels');
  await withCanIUse([SETTINGS_SYSCAP], async () => {
    assert.equal(await NotificationChannels.openAppNotificationSettings({}), false);
  });
});

function reminderKits(notifications) {
  const published = [];
  const memory = new Map();
  const prefs = {
    getPreferences: async () => ({
      getAll: async () => Object.fromEntries(memory),
      put: async (key, value) => { memory.set(key, value); },
      delete: async (key) => { memory.delete(key); },
      flush: async () => {}
    })
  };
  const tasks = {
    reminderAgentManager: {
      ReminderType: { REMINDER_TYPE_CALENDAR: 0 },
      getAllValidReminders: async () => [],
      publishReminder: async (request) => { published.push(request); return published.length; },
      cancelReminder: async () => {}
    }
  };
  return { published, kits: {
    '@kit.ArkData': { preferences: prefs, relationalStore: { ConflictResolution: { ON_CONFLICT_REPLACE: 1 } } },
    '@kit.BackgroundTasksKit': tasks,
    '@kit.NotificationKit': notifications
  } };
}

test('rebuild binds reminders to the service channel and still creates it once', async () => {
  const { calls, kit } = notificationKit();
  const { published, kits } = reminderKits(kit['@kit.NotificationKit']);
  const load = createLoader({ 'data/TaskReminderScheduler': null, ...kits });
  const { TaskReminderScheduler } = load('data/TaskReminderScheduler');
  const task = { id: 't-1', title: '任务', colorTag: 'daily', importance: 1,
    createdAt: '2026-09-05T00:00:00.000Z', updatedAt: '2026-09-05T00:00:00.000Z',
    reminderAt: '2027-01-01T00:00:00.000Z' };

  await TaskReminderScheduler.rebuild({}, [task], false);
  assert.equal(published.length, 1);
  assert.equal(published[0].slotType, 2, 'reminder must target the service-information channel');
  assert.equal(published[0].notificationId, 1, 'id allocation stays unchanged');
  assert.equal(calls.addSlot, 1);

  published.length = 0;
  await TaskReminderScheduler.rebuild({}, [task], false);
  assert.equal(published[0].notificationId, 1, 'ids remain stable across rebuilds');
  assert.equal(calls.addSlot, 1, 'channel creation is idempotent across rebuilds');
});

test('rebuild still works when the platform lacks channel APIs entirely', async () => {
  const legacy = { notificationManager: { requestEnableNotification: async () => {} } };
  const { published, kits } = reminderKits(legacy);
  const load = createLoader({ 'data/TaskReminderScheduler': null, ...kits });
  const { TaskReminderScheduler } = load('data/TaskReminderScheduler');
  const task = { id: 't-2', title: '任务', colorTag: 'daily', importance: 1,
    createdAt: '2026-09-05T00:00:00.000Z', updatedAt: '2026-09-05T00:00:00.000Z',
    reminderAt: '2027-01-01T00:00:00.000Z' };

  await TaskReminderScheduler.rebuild({}, [task], false);
  assert.equal(published.length, 1);
  assert.equal(published[0].slotType, undefined, 'no channel field is sent on legacy platforms');
  assert.equal(published[0].notificationId, 1);
});
