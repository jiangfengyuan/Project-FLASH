// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.logflow

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.flash.app.data.FlashRepository
import com.flash.app.data.model.Category
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.LogItem
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

enum class LogSort(val displayName: String) {
    NEWEST("最新"),
    OLDEST("最早"),
    TAG("按标签"),
}

data class LogFilter(
    val query: String = "",
    val tags: Set<ColorTag> = emptySet(),
    val startDate: String? = null, // yyyy-MM-dd，含当天
    val endDate: String? = null,
    val sort: LogSort = LogSort.NEWEST,
)

/** 对应 Web 版 LogFlow 页 + logFilters.ts */
class LogFlowViewModel(private val repository: FlashRepository) : ViewModel() {

    private val _filter = MutableStateFlow(LogFilter())
    val filter: StateFlow<LogFilter> = _filter.asStateFlow()

    val logs: StateFlow<List<LogItem>> = combine(
        repository.logs,
        _filter,
    ) { logs, filter ->
        applyFilter(logs, filter)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun setQuery(query: String) {
        _filter.value = _filter.value.copy(query = query)
    }

    fun toggleTag(tag: ColorTag) {
        val current = _filter.value.tags
        _filter.value = _filter.value.copy(
            tags = if (tag in current) current - tag else current + tag,
        )
    }

    fun setSort(sort: LogSort) {
        _filter.value = _filter.value.copy(sort = sort)
    }

    fun setDateRange(start: String?, end: String?) {
        val normalized = if (start != null && end != null && start > end) end to start else start to end
        _filter.value = _filter.value.copy(startDate = normalized.first, endDate = normalized.second)
    }

    fun updateLog(log: LogItem) {
        viewModelScope.launch { repository.updateLog(log) }
    }

    fun deleteLog(id: String) {
        viewModelScope.launch { repository.deleteLog(id) }
    }

    private fun applyFilter(logs: List<LogItem>, filter: LogFilter): List<LogItem> {
        val query = filter.query.lowercase()
        val filtered = logs.filter { log ->
            if (log.category != Category.LOG) return@filter false
            val matchesSearch = query.isEmpty() || log.content.lowercase().contains(query)
            val matchesTags = filter.tags.isEmpty() || log.colorTag in filter.tags
            // recordDate 为 yyyy-MM-dd，字典序即时间序（与 Web 版 logFilters.ts 一致）
            val matchesStart = filter.startDate == null || log.recordDate >= filter.startDate
            val matchesEnd = filter.endDate == null || log.recordDate <= filter.endDate
            matchesSearch && matchesTags && matchesStart && matchesEnd
        }
        return when (filter.sort) {
            LogSort.TAG -> filtered.sortedBy { it.colorTag.storageKey }
            LogSort.OLDEST -> filtered.sortedBy { it.createdAt }
            LogSort.NEWEST -> filtered.sortedByDescending { it.createdAt }
        }
    }

    companion object {
        fun factory(repository: FlashRepository): ViewModelProvider.Factory = viewModelFactory {
            initializer { LogFlowViewModel(repository) }
        }
    }
}
