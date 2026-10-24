/** PRD 6.3 / Android domain/IdeaReminder.kt：至少积压三条从未查看的灵感才显示提醒。 */
export const IDEA_REMINDER_THRESHOLD = 3;

export function shouldShowIdeaReminder(unviewedCount: number): boolean {
  return unviewedCount >= IDEA_REMINDER_THRESHOLD;
}
// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
