// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.calendar

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.flash.app.data.FlashRepository
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.LogItem
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.TaskDueKind
import com.flash.app.data.model.TaskItem
import com.flash.app.data.reminder.TaskReminderScheduler
import com.flash.app.domain.todayFlow
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.YearMonth

data class DayAggregate(
    val date: String,
    val logs: List<LogItem>,
    val emotions: List<EmotionRecord>,
    val tasks: List<TaskItem>,
)

internal fun aggregateByDate(
    logs: List<LogItem>,
    emotions: List<EmotionRecord>,
    tasks: List<TaskItem> = emptyList(),
): Map<String, DayAggregate> {
    val logsByDate = logs.groupBy { it.recordDate }
    val emotionsByDate = emotions.groupBy { it.recordDate }
    val tasksByDate = tasks.groupBy { it.calendarDate }
    return (logsByDate.keys + emotionsByDate.keys + tasksByDate.keys).sorted().associateWith { date ->
        DayAggregate(
            date = date,
            logs = logsByDate[date].orEmpty(),
            emotions = emotionsByDate[date].orEmpty(),
            tasks = tasksByDate[date].orEmpty(),
        )
    }
}

internal fun buildCalendarWeeks(month: YearMonth): List<List<LocalDate>> {
    val first = month.atDay(1)
    val start = first.minusDays((first.dayOfWeek.value - 1).toLong())
    return (0 until 6).map { week ->
        (0 until 7).map { day -> start.plusDays((week * 7 + day).toLong()) }
    }
}

/** 对应 Web 版 Calendar：月视图网格 + 选中日详情，数据按 recordDate 聚合 */
data class TaskDraft(
    val title: String,
    val notes: String?,
    val colorTag: ColorTag,
    val importance: Int,
    val dueKind: TaskDueKind,
    val dueDate: String?,
    val dueAt: String?,
    val timeZone: String?,
    val reminderAt: String?,
)

sealed interface CalendarEvent {
    data class Failed(val message: String) : CalendarEvent
}

class CalendarViewModel(
    private val repository: FlashRepository,
    private val reminders: TaskReminderScheduler,
) : ViewModel() {

    private val eventChannel = Channel<CalendarEvent>(Channel.BUFFERED)
    val events = eventChannel.receiveAsFlow()

    private val aggregates: StateFlow<Map<String, DayAggregate>> = combine(
        repository.logs,
        repository.emotions,
        repository.tasks,
    ) { logs, emotions, tasks ->
        aggregateByDate(logs, emotions, tasks)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyMap())

    /** 「今日」流：对齐午夜重发，挂过夜后今日口径自动更新（供网格高亮与选中跟随） */
    private val today: StateFlow<LocalDate> = todayFlow()
        .stateIn(viewModelScope, SharingStarted.Eagerly, LocalDate.now())

    init {
        // 跨午夜时仅当用户仍停留在旧"今日"才跟随到新一天；已手动翻页/选日的不打扰
        viewModelScope.launch {
            var previous = today.value
            today.collect { current ->
                if (current != previous) {
                    if (_selectedDate.value == previous) {
                        _selectedDate.value = current
                        _displayedMonth.value = YearMonth.from(current)
                    }
                    previous = current
                }
            }
        }
    }

    private val _displayedMonth = MutableStateFlow(YearMonth.now())
    val displayedMonth: StateFlow<YearMonth> = _displayedMonth.asStateFlow()

    private val _selectedDate = MutableStateFlow(LocalDate.now())
    val selectedDate: StateFlow<LocalDate> = _selectedDate.asStateFlow()

    /** 当前展示月份的完整网格（42 格，含前后月溢出天），以及选中日详情 */
    val uiState: StateFlow<CalendarUiState> = combine(
        aggregates,
        _displayedMonth,
        _selectedDate,
        today,
    ) { map, month, selected, todayDate ->
        CalendarUiState(
            month = month,
            weeks = buildCalendarWeeks(month),
            aggregates = map,
            selectedDate = selected,
            selectedAggregate = map[selected.toString()],
            today = todayDate,
        )
    }.stateIn(
        viewModelScope,
        SharingStarted.WhileSubscribed(5000),
        CalendarUiState(
            YearMonth.now(),
            buildCalendarWeeks(YearMonth.now()),
            emptyMap(),
            LocalDate.now(),
            null,
            LocalDate.now(),
        ),
    )

    fun prevMonth() {
        _displayedMonth.value = _displayedMonth.value.minusMonths(1)
    }

    fun nextMonth() {
        _displayedMonth.value = _displayedMonth.value.plusMonths(1)
    }

    fun backToToday() {
        _displayedMonth.value = YearMonth.now()
        _selectedDate.value = LocalDate.now()
    }

    fun selectDate(date: LocalDate) {
        _selectedDate.value = date
        // 选中溢出天时跟随切换到对应月份
        val month = YearMonth.from(date)
        if (month != _displayedMonth.value) _displayedMonth.value = month
    }

    fun saveTask(existing: TaskItem?, draft: TaskDraft) {
        if (draft.title.isBlank()) return
        viewModelScope.launch {
            runCatching {
                val task = if (existing == null) {
                    repository.newTask(
                        draft.title,
                        draft.notes,
                        draft.colorTag,
                        draft.importance,
                        draft.dueKind,
                        draft.dueDate,
                        draft.dueAt,
                        draft.timeZone,
                        draft.reminderAt,
                    ).also { repository.addTask(it) }
                } else {
                    existing.copy(
                        title = draft.title.trim().take(200),
                        notes = draft.notes?.trim()?.ifEmpty { null },
                        colorTag = draft.colorTag,
                        importance = draft.importance.coerceIn(0, 4),
                        dueKind = draft.dueKind,
                        dueDate = draft.dueDate,
                        dueAt = draft.dueAt,
                        timeZone = draft.timeZone,
                        reminderAt = draft.reminderAt,
                    ).also { repository.updateTask(it) }
                }
                reminders.schedule(task)
            }.onFailure {
                eventChannel.send(CalendarEvent.Failed(it.message ?: "任务保存失败"))
            }
        }
    }

    fun setCompleted(task: TaskItem, completed: Boolean) {
        viewModelScope.launch {
            runCatching { repository.setTaskCompleted(task, completed) }
                .onSuccess { updated ->
                    if (completed) reminders.cancel(task.id) else reminders.schedule(updated)
                }
                .onFailure { eventChannel.send(CalendarEvent.Failed(it.message ?: "任务更新失败")) }
        }
    }

    fun deleteTask(task: TaskItem) {
        viewModelScope.launch {
            runCatching { repository.deleteTask(task.id) }
                .onSuccess { reminders.cancel(task.id) }
                .onFailure { eventChannel.send(CalendarEvent.Failed(it.message ?: "任务删除失败")) }
        }
    }

    companion object {
        fun factory(
            repository: FlashRepository,
            reminders: TaskReminderScheduler,
        ): ViewModelProvider.Factory = viewModelFactory {
            initializer { CalendarViewModel(repository, reminders) }
        }
    }
}

data class CalendarUiState(
    val month: YearMonth,
    val weeks: List<List<LocalDate>>,
    val aggregates: Map<String, DayAggregate>,
    val selectedDate: LocalDate,
    val selectedAggregate: DayAggregate?,
    val today: LocalDate,
)
