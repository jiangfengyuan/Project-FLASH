// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.calendar

import android.app.DatePickerDialog
import android.app.TimePickerDialog
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.flash.app.data.Backup
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.TaskDueKind
import com.flash.app.data.model.TaskItem
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private enum class ReminderOption(val label: String, val minutesBefore: Long?) {
    NONE("不提醒", null),
    AT_TIME("到期时", 0),
    FIFTEEN_MINUTES("提前 15 分钟", 15),
    ONE_HOUR("提前 1 小时", 60),
    ONE_DAY("提前 1 天", 24 * 60),
}

private val IMPORTANCE_OPTIONS = listOf(0 to "无", 2 to "!!", 3 to "!!!", 4 to "!!!!")

@Composable
fun TaskEditorDialog(
    selectedDate: LocalDate,
    existing: TaskItem?,
    onDismiss: () -> Unit,
    onSave: (TaskDraft) -> Unit,
) {
    val context = LocalContext.current
    val initialZone = existing?.timeZone?.let { runCatching { ZoneId.of(it) }.getOrNull() }
        ?: ZoneId.systemDefault()
    val initialDate = existing?.let { runCatching { LocalDate.parse(it.calendarDate) }.getOrNull() }
        ?: selectedDate
    val initialTime = existing?.dueAt?.let { due ->
        runCatching { Instant.parse(due).atZone(initialZone).toLocalTime() }.getOrNull()
    } ?: LocalTime.of(9, 0)

    var title by remember(existing?.id) { mutableStateOf(existing?.title.orEmpty()) }
    var notes by remember(existing?.id) { mutableStateOf(existing?.notes.orEmpty()) }
    var tag by remember(existing?.id) { mutableStateOf(existing?.colorTag ?: ColorTag.MEMO) }
    var importance by remember(existing?.id) { mutableIntStateOf(existing?.importance ?: 0) }
    var allDay by remember(existing?.id) {
        mutableStateOf(existing?.dueKind != TaskDueKind.DATE_TIME)
    }
    var dueDate by remember(existing?.id) { mutableStateOf(initialDate) }
    var dueTime by remember(existing?.id) { mutableStateOf(initialTime) }
    var reminder by remember(existing?.id) {
        mutableStateOf(inferReminder(existing, initialDate, initialTime, initialZone))
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (existing == null) "新建任务" else "编辑任务") },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it.take(200) },
                    label = { Text("任务") },
                    supportingText = { Text("${title.length}/200") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it.take(Backup.MAX_FIELD_LENGTH) },
                    label = { Text("备注（可选）") },
                    minLines = 2,
                    maxLines = 4,
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    ColorTag.entries.forEach { option ->
                        FilterChip(
                            selected = tag == option,
                            onClick = { tag = option },
                            label = { Text(option.displayName) },
                        )
                    }
                }
                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    IMPORTANCE_OPTIONS.forEach { (value, label) ->
                        FilterChip(
                            selected = importance == value,
                            onClick = { importance = value },
                            label = { Text(label) },
                        )
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("全天任务", modifier = Modifier.weight(1f))
                    Switch(checked = allDay, onCheckedChange = { allDay = it })
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(
                        onClick = {
                            DatePickerDialog(
                                context,
                                { _, year, month, day -> dueDate = LocalDate.of(year, month + 1, day) },
                                dueDate.year,
                                dueDate.monthValue - 1,
                                dueDate.dayOfMonth,
                            ).show()
                        },
                        modifier = Modifier.weight(1f),
                    ) { Text(dueDate.toString()) }
                    if (!allDay) {
                        OutlinedButton(
                            onClick = {
                                TimePickerDialog(
                                    context,
                                    { _, hour, minute -> dueTime = LocalTime.of(hour, minute) },
                                    dueTime.hour,
                                    dueTime.minute,
                                    true,
                                ).show()
                            },
                            modifier = Modifier.weight(1f),
                        ) { Text(dueTime.format(DateTimeFormatter.ofPattern("HH:mm"))) }
                    }
                }
                Text("本地提醒")
                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    ReminderOption.entries.forEach { option ->
                        FilterChip(
                            selected = reminder == option,
                            onClick = { reminder = option },
                            label = { Text(option.label) },
                        )
                    }
                }
                Text("提醒由系统后台调度，省电模式下可能略有延迟。")
            }
        },
        confirmButton = {
            TextButton(
                enabled = title.isNotBlank(),
                onClick = {
                    // 编辑时保留原任务时区；新任务的 initialZone 才是当前系统时区。
                    val zone = initialZone
                    val anchor = dueDate.atTime(if (allDay) LocalTime.of(9, 0) else dueTime)
                        .atZone(zone)
                        .toInstant()
                    val reminderAt = reminder.minutesBefore?.let { anchor.minusSeconds(it * 60).toString() }
                    onSave(
                        TaskDraft(
                            title = title.trim(),
                            notes = notes.trim().ifEmpty { null },
                            colorTag = tag,
                            importance = importance,
                            dueKind = if (allDay) TaskDueKind.ALL_DAY else TaskDueKind.DATE_TIME,
                            dueDate = if (allDay) dueDate.toString() else null,
                            dueAt = if (allDay) null else anchor.toString(),
                            timeZone = if (allDay) null else zone.id,
                            reminderAt = reminderAt,
                        )
                    )
                },
            ) { Text("保存") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("取消") } },
    )
}

private fun inferReminder(
    task: TaskItem?,
    date: LocalDate,
    time: LocalTime,
    zone: ZoneId,
): ReminderOption {
    val reminderAt = task?.reminderAt ?: return ReminderOption.NONE
    val anchor = when (task.dueKind) {
        TaskDueKind.ALL_DAY -> date.atTime(9, 0).atZone(zone).toInstant()
        TaskDueKind.DATE_TIME -> date.atTime(time).atZone(zone).toInstant()
    }
    val minutes = runCatching {
        Duration.between(Instant.parse(reminderAt), anchor).toMinutes()
    }.getOrNull() ?: return ReminderOption.NONE
    return ReminderOption.entries.firstOrNull { it.minutesBefore == minutes } ?: ReminderOption.AT_TIME
}
