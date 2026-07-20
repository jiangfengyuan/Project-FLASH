package com.flash.app.ui.calendar

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.flash.app.data.FlashRepository
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.LogItem
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import java.time.LocalDate
import java.time.YearMonth

data class DayAggregate(
    val date: String,
    val logs: List<LogItem>,
    val emotions: List<EmotionRecord>,
)

/** 对应 Web 版 Calendar：月视图网格 + 选中日详情，数据按 recordDate 聚合 */
class CalendarViewModel(repository: FlashRepository) : ViewModel() {

    private val aggregates: StateFlow<Map<String, DayAggregate>> = combine(
        repository.logs,
        repository.emotions,
    ) { logs, emotions ->
        val dates = (logs.map { it.recordDate } + emotions.map { it.recordDate }).toSortedSet()
        dates.associateWith { date ->
            DayAggregate(
                date = date,
                logs = logs.filter { it.recordDate == date },
                emotions = emotions.filter { it.recordDate == date },
            )
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyMap())

    private val _displayedMonth = MutableStateFlow(YearMonth.now())
    val displayedMonth: StateFlow<YearMonth> = _displayedMonth.asStateFlow()

    private val _selectedDate = MutableStateFlow(LocalDate.now())
    val selectedDate: StateFlow<LocalDate> = _selectedDate.asStateFlow()

    /** 当前展示月份的完整网格（42 格，含前后月溢出天），以及选中日详情 */
    val uiState: StateFlow<CalendarUiState> = combine(
        aggregates,
        _displayedMonth,
        _selectedDate,
    ) { map, month, selected ->
        CalendarUiState(
            month = month,
            weeks = buildWeeks(month),
            aggregates = map,
            selectedDate = selected,
            selectedAggregate = map[selected.toString()],
        )
    }.stateIn(
        viewModelScope,
        SharingStarted.WhileSubscribed(5000),
        CalendarUiState(YearMonth.now(), emptyList(), emptyMap(), LocalDate.now(), null),
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

    private fun buildWeeks(month: YearMonth): List<List<LocalDate>> {
        val first = month.atDay(1)
        // 周一为一周起点（value: Mon=1..Sun=7）
        val startOffset = first.dayOfWeek.value - 1
        val start = first.minusDays(startOffset.toLong())
        return (0 until 6).map { week ->
            (0 until 7).map { day -> start.plusDays((week * 7 + day).toLong()) }
        }
    }

    companion object {
        fun factory(repository: FlashRepository): ViewModelProvider.Factory = viewModelFactory {
            initializer { CalendarViewModel(repository) }
        }
    }
}

data class CalendarUiState(
    val month: YearMonth,
    val weeks: List<List<LocalDate>>,
    val aggregates: Map<String, DayAggregate>,
    val selectedDate: LocalDate,
    val selectedAggregate: DayAggregate?,
)
