// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.domain

import java.time.LocalDate
import java.time.LocalDateTime
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test

class TodayTest {

    @Test
    fun `millisUntilNextMidnight covers rest of day plus safety margin`() {
        val noon = LocalDateTime.of(2026, 9, 5, 12, 0, 0)

        // 12 小时到午夜 + 默认 1 秒安全余量
        assertEquals(12 * 3600_000L + 1_000, millisUntilNextMidnight(noon))
    }

    @Test
    fun `millisUntilNextMidnight at start of day is a full day plus margin`() {
        val startOfDay = LocalDateTime.of(2026, 9, 5, 0, 0, 0)

        assertEquals(24 * 3600_000L + 1_000, millisUntilNextMidnight(startOfDay))
    }

    @Test
    fun `millisUntilNextMidnight just before midnight stays positive`() {
        val almostMidnight = LocalDateTime.of(2026, 9, 5, 23, 59, 59)

        assertEquals(1_000L + 1_000, millisUntilNextMidnight(almostMidnight))
    }

    @Test
    fun `todayFlow emits current date immediately`() = runBlocking {
        val now = LocalDateTime.of(2026, 9, 5, 23, 59, 59)

        val first = todayFlow { now }.first()

        assertEquals(LocalDate.of(2026, 9, 5), first)
    }
}
