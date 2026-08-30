import { floatingBall } from '@kit.ArkUI';
import { liveViewManager } from '@kit.LiveViewKit';
import { manager } from '@kit.NearLinkKit';

export interface HarmonyCapabilitySnapshot {
  nearLinkSupported: boolean;
  floatingBallSupported: boolean;
  liveViewEnabled: boolean;
}

/**
 * Read-only system capability probes. Restricted capabilities are never started
 * here: availability does not imply that the application has passed scenario
 * review or received the corresponding permission.
 */
export class HarmonyCapabilities {
  static async inspect(): Promise<HarmonyCapabilitySnapshot> {
    let nearLinkSupported = false;
    let floatingBallSupported = false;
    let liveViewEnabled = false;

    try {
      nearLinkSupported = manager.isNearLinkSupported();
    } catch (_) {
      nearLinkSupported = false;
    }

    try {
      floatingBallSupported = floatingBall.isFloatingBallEnabled();
    } catch (_) {
      floatingBallSupported = false;
    }

    try {
      liveViewEnabled = await liveViewManager.isLiveViewEnabled();
    } catch (_) {
      liveViewEnabled = false;
    }

    return { nearLinkSupported, floatingBallSupported, liveViewEnabled };
  }
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
