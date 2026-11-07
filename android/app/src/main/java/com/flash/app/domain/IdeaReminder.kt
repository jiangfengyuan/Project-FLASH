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

/** 距上次提醒是否已满频率间隔（从未提醒过视为到期）。 */
fun ideaReminderDue(lastFired: java.time.LocalDate?, today: java.time.LocalDate, intervalDays: Long): Boolean =
    lastFired == null || java.time.temporal.ChronoUnit.DAYS.between(lastFired, today) >= intervalDays
