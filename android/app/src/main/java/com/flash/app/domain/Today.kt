// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.domain

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flow

/** 距本地午夜的毫秒数（含安全余量），用于对齐跨天刷新。 */
fun millisUntilNextMidnight(now: LocalDateTime, safetyMillis: Long = 1_000): Long =
    ChronoUnit.MILLIS.between(now, now.toLocalDate().plusDays(1).atStartOfDay()) + safetyMillis

/**
 * 「今日」流：立即发出当前日期，随后对齐午夜重发。
 * 进程挂过夜后设备一唤醒，到期的 delay 立即触发，"今日"口径随之更新；
 * 比 ON_RESUME 钩子更省事，也不需要额外依赖。
 */
fun todayFlow(now: () -> LocalDateTime = { LocalDateTime.now() }): Flow<LocalDate> = flow {
    while (true) {
        val current = now()
        emit(current.toLocalDate())
        delay(millisUntilNextMidnight(current))
    }
}.distinctUntilChanged()
