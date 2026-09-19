// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.data

import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.LogItem
import com.flash.app.data.model.TaskItem

data class DifferenceSummary(val added: Int, val changed: Int, val unchanged: Int, val localOnly: Int)
data class BackupDifference(
    val logs: DifferenceSummary,
    val emotions: DifferenceSummary,
    val tasks: DifferenceSummary,
)

object BackupDiff {
    fun analyze(
        localLogs: List<LogItem>,
        localEmotions: List<EmotionRecord>,
        incomingLogs: List<LogItem>,
        incomingEmotions: List<EmotionRecord>,
        localTasks: List<TaskItem> = emptyList(),
        incomingTasks: List<TaskItem> = emptyList(),
    ): BackupDifference = BackupDifference(
        summarize(localLogs, incomingLogs, LogItem::id),
        summarize(localEmotions, incomingEmotions, EmotionRecord::id),
        summarize(localTasks, incomingTasks, TaskItem::id),
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

    /**
     * 覆盖导入前的 TOCTOU 重校验：预览时的本地快照与当前快照逐项结构比较。
     * 预览后若有任何写入（新增/编辑/删除），覆盖必须先重新出预览，否则
     * 预览与确认之间产生的本机独有记录会被静默删除。对应 HarmonyOS
     * BackupController.applyBackup 的 pendingSnapshot + sameData 模式。
     */
    fun sameData(left: FlashSnapshot, right: FlashSnapshot): Boolean =
        left.logs == right.logs && left.emotions == right.emotions && left.tasks == right.tasks
}
