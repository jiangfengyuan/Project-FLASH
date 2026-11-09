const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');

const load = createLoader();
const {
  ONBOARDING_STEPS, ONBOARDING_STEP_COUNT, clampStep, nextStep, previousStep, isFirstStep, isLastStep,
  stepAnnouncement, openOnboarding, closeOnboarding, onboardingBack
} = load('state/Onboarding');
const { SettingsState } = load('state/FeatureStates');

test('onboarding has the four cross-platform steps in order', () => {
  assert.deepEqual(ONBOARDING_STEPS.map(step => step.key), ['welcome', 'features', 'privacy', 'preferences']);
  assert.equal(ONBOARDING_STEP_COUNT, 4);
  for (const step of ONBOARDING_STEPS) {
    assert.ok(step.title.length > 0, `${step.key} has a title`);
    assert.ok(step.subtitle.length > 0, `${step.key} has a subtitle`);
    for (const row of step.rows) {
      assert.ok(row.title && row.detail, `${step.key} rows have title and detail`);
    }
  }
});

test('step navigation clamps to the first and last step', () => {
  assert.equal(nextStep(0), 1);
  assert.equal(nextStep(3), 3);
  assert.equal(previousStep(0), 0);
  assert.equal(previousStep(2), 1);
  assert.equal(clampStep(-5), 0);
  assert.equal(clampStep(99), 3);
  assert.equal(clampStep(Number.NaN), 0);
  assert.ok(isFirstStep(0) && !isFirstStep(1));
  assert.ok(isLastStep(3) && !isLastStep(2));
});

test('step announcement reads position for screen readers', () => {
  assert.equal(stepAnnouncement(0), '第 1 步，共 4 步');
  assert.equal(stepAnnouncement(3), '第 4 步，共 4 步');
});

test('opening always starts from the first step', () => {
  const settings = new SettingsState();
  settings.welcomeStep = 2;
  openOnboarding(settings, true);
  assert.equal(settings.showWelcome, true);
  assert.equal(settings.welcomeStep, 0);
  assert.equal(settings.welcomeReplay, true);
  closeOnboarding(settings);
  assert.equal(settings.showWelcome, false);
  assert.equal(settings.welcomeReplay, false);
});

test('back key steps backwards, closes a replay, and leaves first install to the system', () => {
  const settings = new SettingsState();
  assert.equal(onboardingBack(settings), false, 'not consumed when onboarding is hidden');

  openOnboarding(settings, false);
  settings.welcomeStep = 2;
  assert.equal(onboardingBack(settings), true);
  assert.equal(settings.welcomeStep, 1);
  assert.equal(onboardingBack(settings), true);
  assert.equal(settings.welcomeStep, 0);
  assert.equal(onboardingBack(settings), false, 'first install: first step defers to the system');
  assert.equal(settings.showWelcome, true);

  openOnboarding(settings, true);
  assert.equal(onboardingBack(settings), true, 'replay: first step closes the onboarding');
  assert.equal(settings.showWelcome, false);
});
