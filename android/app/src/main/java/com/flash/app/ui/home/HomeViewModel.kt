// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.flash.app.data.FlashRepository
import com.flash.app.data.model.Category
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.LogItem
import com.flash.app.data.model.TaskItem
import com.flash.app.i18n.tr
import com.flash.app.domain.todayFlow
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId

data class HomeUiState(
    val todayLogCount: Int = 0,
    val todayIdeaCount: Int = 0,
    val todayEmotionCount: Int = 0,
    val latestEmotion: EmotionRecord? = null,
    val recentLogs: List<LogItem> = emptyList(),
    val unviewedIdeaCount: Int = 0,
    val oldestUnviewedIdeaId: String? = null,
    val todayTaskCount: Int = 0,
    val todayDoneTaskCount: Int = 0,
    /** 未完成待办（全部，不限今日），与 iOS 今日一览同口径 */
    val openTaskCount: Int = 0,
    val unviewedIdeaIds: Set<String> = emptySet(),
) {
    /** 今日一览主数据：今日记录数（日志 + 灵感） */
    val todayRecordCount: Int get() = todayLogCount + todayIdeaCount
}

/** 最近闪念条数（对齐 iOS） */
internal const val RECENT_LIMIT = 6

internal fun buildHomeUiState(
    logs: List<LogItem>,
    emotions: List<EmotionRecord>,
    unviewedIdeas: List<LogItem>,
    today: String,
    tasks: List<TaskItem> = emptyList(),
): HomeUiState = HomeUiState(
    todayLogCount = logs.count { it.recordDate == today && it.category == Category.LOG },
    todayIdeaCount = logs.count { it.recordDate == today && it.category == Category.IDEA },
    todayEmotionCount = emotions.count { it.recordDate == today },
    latestEmotion = emotions.firstOrNull { it.recordDate == today },
    recentLogs = logs.take(RECENT_LIMIT),
    unviewedIdeaCount = unviewedIdeas.size,
    // 仓库按时间倒序返回；提醒入口优先处理积压最久的一条。
    oldestUnviewedIdeaId = unviewedIdeas.lastOrNull()?.id,
    todayTaskCount = tasks.count { it.calendarDate == today && !it.isCompleted },
    openTaskCount = tasks.count { !it.isCompleted },
    unviewedIdeaIds = unviewedIdeas.mapTo(mutableSetOf()) { it.id },
    todayDoneTaskCount = tasks.count { task ->
        task.completedAt?.let {
            runCatching {
                Instant.parse(it).atZone(ZoneId.systemDefault()).toLocalDate().toString() == today
            }.getOrDefault(false)
        } == true
    },
)

sealed interface HomeEvent {
    data class Failed(val message: String) : HomeEvent
}

class HomeViewModel(private val repository: FlashRepository) : ViewModel() {

    private val eventChannel = Channel<HomeEvent>(Channel.BUFFERED)
    val events = eventChannel.receiveAsFlow()

    // 「今日」随 todayFlow 对齐午夜重发，挂过夜后今日口径自动更新
    val uiState: StateFlow<HomeUiState> = combine(
        repository.logs,
        repository.emotions,
        repository.unviewedIdeas,
        repository.tasks,
        todayFlow(),
    ) { logs, emotions, unviewedIdeas, tasks, today ->
        buildHomeUiState(logs, emotions, unviewedIdeas, today.toString(), tasks)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), HomeUiState())

    fun toggleFavorite(log: LogItem) {
        viewModelScope.launch {
            runCatching { repository.setLogFavorite(log, log.isFavorite != true) }
                .onFailure { eventChannel.send(HomeEvent.Failed(it.message ?: tr("操作失败，请重试"))) }
        }
    }

    /** 删除即生效，返回撤销动作（由调用方放进 4 秒提示）；失败返回 null */
    suspend fun deleteWithUndo(log: LogItem): (suspend () -> Unit)? =
        runCatching { repository.deleteLogWithUndo(log) }
            .onFailure { eventChannel.send(HomeEvent.Failed(it.message ?: tr("删除失败，请重试"))) }
            .getOrNull()

    companion object {
        fun factory(repository: FlashRepository): ViewModelProvider.Factory = viewModelFactory {
            initializer { HomeViewModel(repository) }
        }
    }
}
