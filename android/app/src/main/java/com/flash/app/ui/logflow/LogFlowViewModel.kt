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
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.receiveAsFlow
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

sealed interface LogFlowEvent {
    data class Deleted(val log: LogItem, val wasIdeaViewed: Boolean = false) : LogFlowEvent
    data class Failed(val message: String) : LogFlowEvent
}

/** LIKE 通配符转义（与 DAO 的 ESCAPE '\' 配套），保证搜索按字面匹配 */
internal fun escapeLike(raw: String): String = buildString {
    for (c in raw) {
        if (c == '\\' || c == '%' || c == '_') append('\\')
        append(c)
    }
}

internal fun LogSort.toSortKey(): String = when (this) {
    LogSort.NEWEST -> "newest"
    LogSort.OLDEST -> "oldest"
    LogSort.TAG -> "tag"
}

/** 对应 Web 版 LogFlow 页 + logFilters.ts；过滤/排序下推 SQL，列表分页增量加载 */
@OptIn(ExperimentalCoroutinesApi::class)
class LogFlowViewModel(private val repository: FlashRepository) : ViewModel() {

    private val eventChannel = Channel<LogFlowEvent>(Channel.BUFFERED)
    val events = eventChannel.receiveAsFlow()

    private val _filter = MutableStateFlow(LogFilter())
    val filter: StateFlow<LogFilter> = _filter.asStateFlow()

    /** 已加载条数上限，滑到底部时按页增大（配合 DAO 的 LIMIT 查询） */
    private val _limit = MutableStateFlow(PAGE_SIZE)

    val logs: StateFlow<List<LogItem>> = combine(_filter, _limit) { filter, limit ->
        filter to limit
    }.flatMapLatest { (filter, limit) ->
        repository.observeLogPage(
            query = escapeLike(filter.query.trim().lowercase()),
            tags = filter.tags.mapTo(mutableSetOf()) { it.storageKey },
            startDate = filter.startDate,
            endDate = filter.endDate,
            sort = filter.sort.toSortKey(),
            limit = limit,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    /** 当前过滤条件下的命中总数（"N 条"展示 + 是否还有更多） */
    val totalCount: StateFlow<Int> = _filter.flatMapLatest { filter ->
        repository.observeLogCount(
            query = escapeLike(filter.query.trim().lowercase()),
            tags = filter.tags.mapTo(mutableSetOf()) { it.storageKey },
            startDate = filter.startDate,
            endDate = filter.endDate,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 0)

    fun loadMore() {
        if (logs.value.size < totalCount.value) _limit.value += PAGE_SIZE
    }

    private fun updateFilter(transform: (LogFilter) -> LogFilter) {
        _filter.value = transform(_filter.value)
        _limit.value = PAGE_SIZE
    }

    fun setQuery(query: String) {
        updateFilter { it.copy(query = query) }
    }

    fun toggleTag(tag: ColorTag) {
        updateFilter { current ->
            val tags = current.tags
            current.copy(tags = if (tag in tags) tags - tag else tags + tag)
        }
    }

    fun setSort(sort: LogSort) {
        updateFilter { it.copy(sort = sort) }
    }

    fun setDateRange(start: String?, end: String?) {
        val normalized = if (start != null && end != null && start > end) end to start else start to end
        updateFilter { it.copy(startDate = normalized.first, endDate = normalized.second) }
    }

    fun updateLog(log: LogItem) {
        viewModelScope.launch {
            runCatching { repository.updateLog(log) }
                .onFailure {
                    eventChannel.send(LogFlowEvent.Failed(it.message ?: "保存失败，请重试"))
                }
        }
    }

    fun deleteLog(log: LogItem) {
        viewModelScope.launch {
            // 删除会级联清掉 idea_view_state，先记住已读状态供撤销时恢复
            val wasIdeaViewed = log.category == Category.IDEA &&
                runCatching { repository.isIdeaViewed(log.id) }.getOrDefault(false)
            runCatching { repository.deleteLog(log.id) }
                .onSuccess { eventChannel.send(LogFlowEvent.Deleted(log, wasIdeaViewed)) }
                .onFailure {
                    eventChannel.send(LogFlowEvent.Failed(it.message ?: "删除失败，请重试"))
                }
        }
    }

    fun restoreLog(log: LogItem, wasIdeaViewed: Boolean) {
        viewModelScope.launch {
            runCatching {
                repository.updateLog(log)
                if (wasIdeaViewed) repository.markIdeaViewed(log.id)
            }.onFailure {
                eventChannel.send(LogFlowEvent.Failed(it.message ?: "撤销失败，请重试"))
            }
        }
    }

    companion object {
        const val PAGE_SIZE = 50

        fun factory(repository: FlashRepository): ViewModelProvider.Factory = viewModelFactory {
            initializer { LogFlowViewModel(repository) }
        }
    }
}
