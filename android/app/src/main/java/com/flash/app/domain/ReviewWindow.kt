// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.domain

import java.time.LocalDate
import com.flash.app.data.model.LogItem
import com.flash.app.data.model.EmotionRecord

enum class ReviewWindow(val label: String, val currentName: String, val previousName: String) {
    WEEK("本周", "这周", "上周"),
    MONTH("本月", "这个月", "上个月"),
    DAYS_30("近30天", "近30天", "前30天"),
    DAYS_90("近90天", "近90天", "前90天");

    fun days(today: LocalDate): Int = when (this) {
        WEEK -> today.dayOfWeek.value
        MONTH -> today.dayOfMonth
        DAYS_30 -> 30
        DAYS_90 -> 90
    }

    fun start(today: LocalDate): LocalDate = today.minusDays(days(today).toLong() - 1)
}

data class DailyActivity(val date: LocalDate, val records: Int, val emotions: Int) {
    val total: Int get() = records + emotions
}

/** Calendar-day counts, including zero days. Tasks do not count as written records. */
fun dailyActivity(logs: List<LogItem>, emotions: List<EmotionRecord>,
                  start: LocalDate, end: LocalDate): List<DailyActivity> {
    if (end < start) return emptyList()
    val recordsByDay = logs.groupingBy { it.recordDate }.eachCount()
    val emotionsByDay = emotions.groupingBy { it.recordDate }.eachCount()
    return generateSequence(start) { it.plusDays(1) }.takeWhile { it <= end }.map {
        DailyActivity(it, recordsByDay[it.toString()] ?: 0, emotionsByDay[it.toString()] ?: 0)
    }.toList()
}
