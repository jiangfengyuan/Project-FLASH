// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.LogItem

data class DifferenceSummary(val added: Int, val changed: Int, val unchanged: Int, val localOnly: Int)
data class BackupDifference(val logs: DifferenceSummary, val emotions: DifferenceSummary)

object BackupDiff {
    fun analyze(
        localLogs: List<LogItem>,
        localEmotions: List<EmotionRecord>,
        incomingLogs: List<LogItem>,
        incomingEmotions: List<EmotionRecord>,
    ): BackupDifference = BackupDifference(
        summarize(localLogs, incomingLogs, LogItem::id),
        summarize(localEmotions, incomingEmotions, EmotionRecord::id),
    )

    private fun <T> summarize(local: List<T>, incoming: List<T>, id: (T) -> String): DifferenceSummary {
        val localById = local.associateBy(id)
        val incomingById = incoming.associateBy(id)
        var added = 0
        var changed = 0
        var unchanged = 0
        incomingById.forEach { (key, value) ->
            val current = localById[key]
            when {
                current == null -> added++
                current == value -> unchanged++
                else -> changed++
            }
        }
        return DifferenceSummary(added, changed, unchanged, localById.keys.count { it !in incomingById })
    }
}
