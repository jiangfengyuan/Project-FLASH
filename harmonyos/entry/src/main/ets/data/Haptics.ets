// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import { vibrator } from '@kit.SensorServiceKit';
import { isReduceMotionEnabled } from '../state/FeatureStates';

export enum HapticEvent {
  SUCCESS = 'success',
  SELECTION = 'selection',
  LIGHT = 'light'
}

const EFFECTS: Map<HapticEvent, string> = new Map<HapticEvent, string>([
  [HapticEvent.SUCCESS, 'haptic.effect.soft'],
  [HapticEvent.SELECTION, 'haptic.effect.sharp'],
  [HapticEvent.LIGHT, 'haptic.effect.sharp']
]);

/** 触感反馈（与 iOS 同一组事件）。不支持的设备静默跳过，绝不影响主流程。 */
export function playHaptic(event: HapticEvent): void {
  if (isReduceMotionEnabled()) return;
  try {
    if (!canIUse('SystemCapability.Sensors.MiscDevice')) return;
    const effect = EFFECTS.get(event) ?? 'haptic.effect.sharp';
    if (!vibrator.isSupportEffectSync(effect)) return;
    vibrator.startVibration({ type: 'preset', effectId: effect, count: 1 },
      { usage: 'touch' }).catch(() => {});
  } catch (_) {
    // 无振动能力时不做事。
  }
}
