// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.domain

/** PRD 6.3：至少积压三条从未打开的 Idea 时才显示提醒。 */
const val IDEA_REMINDER_THRESHOLD = 3

fun shouldShowIdeaReminder(unviewedCount: Int): Boolean =
    unviewedCount >= IDEA_REMINDER_THRESHOLD
