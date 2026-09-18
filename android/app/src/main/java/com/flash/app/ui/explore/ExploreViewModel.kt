// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.explore

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.flash.app.data.FlashRepository
import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.LogItem
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.LocalDate

enum class ExploreFilter(val displayName: String) {
    ALL("全部"),
    LOG("日志"),
    IDEA("灵感"),
    UNSORTED("待整理"),
}

/** 筛选面板状态：标签、日期范围、最低重要度；关闭面板后保留 */
data class ExplorePanel(
    val tags: Set<ColorTag> = emptySet(),
    val startDate: String? = null,
    val endDate: String? = null,
    val minImportance: Int = 0,
) {
    val isActive: Boolean
        get() = tags.isNotEmpty() || startDate != null || endDate != null || minImportance > 0
}

internal fun filterExploreLogs(
    logs: List<LogItem>,
    filter: ExploreFilter,
    query: String,
    panel: ExplorePanel = ExplorePanel(),
    unviewedIdeaIds: Set<String> = emptySet(),
    newestFirst: Boolean = true,
): List<LogItem> {
    val categoryMatches = when (filter) {
        ExploreFilter.ALL -> logs
        ExploreFilter.LOG -> logs.filter { it.category == Category.LOG }
        ExploreFilter.IDEA -> logs.filter { it.category == Category.IDEA }
        ExploreFilter.UNSORTED -> logs.filter {
            it.category == Category.IDEA && it.id in unviewedIdeaIds
        }
    }
    val normalized = query.trim().lowercase()
    val queryMatches = if (normalized.isEmpty()) {
        categoryMatches
    } else {
        categoryMatches.filter { item ->
            item.content.lowercase().contains(normalized) ||
                item.colorTag.displayName.lowercase().contains(normalized)
        }
    }
    val panelMatches = queryMatches.filter { item ->
        (panel.tags.isEmpty() || item.colorTag in panel.tags) &&
            (panel.startDate == null || item.recordDate >= panel.startDate) &&
            (panel.endDate == null || item.recordDate <= panel.endDate) &&
            item.importance >= panel.minImportance
    }
    return if (newestFirst) panelMatches else panelMatches.asReversed()
}

/** 一行统计摘要：「本周 N 条记录 · M 条待整理」 */
internal fun buildExploreSummary(logs: List<LogItem>, unviewedCount: Int, today: LocalDate): String {
    val weekStart = today.minusDays(6).toString()
    val weekCount = logs.count { it.recordDate >= weekStart }
    return "本周 $weekCount 条记录 · $unviewedCount 条待整理"
}

sealed interface ExploreEvent {
    data class Failed(val message: String) : ExploreEvent
}

/** 记录页（方案 §4.2）：统一信息流 + 筛选胶囊 + 筛选面板 + 待整理批量修改 */
class ExploreViewModel(private val repository: FlashRepository) : ViewModel() {

    private val eventChannel = Channel<ExploreEvent>(Channel.BUFFERED)
    val events = eventChannel.receiveAsFlow()

    private val _filter = MutableStateFlow(ExploreFilter.ALL)
    val filter: StateFlow<ExploreFilter> = _filter.asStateFlow()

    private val _query = MutableStateFlow("")
    val query: StateFlow<String> = _query.asStateFlow()

    private val _panel = MutableStateFlow(ExplorePanel())
    val panel: StateFlow<ExplorePanel> = _panel.asStateFlow()

    private val _newestFirst = MutableStateFlow(true)
    val newestFirst: StateFlow<Boolean> = _newestFirst.asStateFlow()

    val unviewedIdeaIds: StateFlow<Set<String>> = repository.unviewedIdeas
        .map { ideas -> ideas.mapTo(mutableSetOf(), LogItem::id) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptySet())

    val logs: StateFlow<List<LogItem>> = combine(
        repository.logs,
        _filter,
        _query,
        _panel,
        unviewedIdeaIds,
        _newestFirst,
    ) { values ->
        @Suppress("UNCHECKED_CAST")
        filterExploreLogs(
            logs = values[0] as List<LogItem>,
            filter = values[1] as ExploreFilter,
            query = values[2] as String,
            panel = values[3] as ExplorePanel,
            unviewedIdeaIds = values[4] as Set<String>,
            newestFirst = values[5] as Boolean,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val summary: StateFlow<String> = combine(
        repository.logs,
        unviewedIdeaIds,
    ) { logs, unviewed ->
        buildExploreSummary(logs, unviewed.size, LocalDate.now())
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), "")

    /** 待整理筛选下的批量选择 */
    private val _selection = MutableStateFlow<Set<String>>(emptySet())
    val selection: StateFlow<Set<String>> = _selection.asStateFlow()

    fun setFilter(filter: ExploreFilter) {
        _filter.value = filter
        if (filter != ExploreFilter.UNSORTED) _selection.value = emptySet()
    }

    fun setQuery(query: String) {
        _query.value = query.take(MAX_SEARCH_LENGTH)
    }

    fun togglePanelTag(tag: ColorTag) {
        val tags = _panel.value.tags
        _panel.value = _panel.value.copy(
            tags = if (tag in tags) tags - tag else tags + tag,
        )
    }

    fun setStartDate(date: String?) {
        _panel.value = _panel.value.copy(startDate = date)
    }

    fun setEndDate(date: String?) {
        _panel.value = _panel.value.copy(endDate = date)
    }

    fun setMinImportance(value: Int) {
        _panel.value = _panel.value.copy(minImportance = value)
    }

    fun toggleSort() {
        _newestFirst.value = !_newestFirst.value
    }

    fun clearFilters() {
        _query.value = ""
        _filter.value = ExploreFilter.ALL
        _panel.value = ExplorePanel()
    }

    fun toggleSelect(id: String) {
        val current = _selection.value
        _selection.value = if (id in current) current - id else current + id
    }

    fun clearSelection() {
        _selection.value = emptySet()
    }

    fun batchSetCategory(category: Category) {
        val ids = _selection.value.toList()
        if (ids.isEmpty()) return
        _selection.value = emptySet()
        viewModelScope.launch {
            runCatching { repository.updateLogCategories(ids, category) }
                .onFailure {
                    eventChannel.send(ExploreEvent.Failed(it.message ?: "批量修改失败，请重试"))
                }
        }
    }

    fun batchSetTag(tag: ColorTag) {
        val ids = _selection.value.toList()
        if (ids.isEmpty()) return
        _selection.value = emptySet()
        viewModelScope.launch {
            runCatching { repository.updateLogColorTags(ids, tag) }
                .onFailure {
                    eventChannel.send(ExploreEvent.Failed(it.message ?: "批量修改失败，请重试"))
                }
        }
    }

    companion object {
        const val MAX_SEARCH_LENGTH = 200

        fun factory(repository: FlashRepository): ViewModelProvider.Factory = viewModelFactory {
            initializer { ExploreViewModel(repository) }
        }
    }
}
