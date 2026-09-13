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
import com.flash.app.data.model.ColorTag
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.LogItem
import com.flash.app.data.model.TaskItem
import com.flash.app.data.model.importanceFromContent
import com.flash.app.domain.todayFlow
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class HomeUiState(
    val todayLogCount: Int = 0,
    val todayIdeaCount: Int = 0,
    val todayEmotionCount: Int = 0,
    val latestEmotion: EmotionRecord? = null,
    val recentLogs: List<LogItem> = emptyList(),
    val unviewedIdeaCount: Int = 0,
    val oldestUnviewedIdeaId: String? = null,
    val todayTaskCount: Int = 0,
)

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
    recentLogs = logs.take(5),
    unviewedIdeaCount = unviewedIdeas.size,
    // 仓库按时间倒序返回；提醒入口优先处理积压最久的一条。
    oldestUnviewedIdeaId = unviewedIdeas.lastOrNull()?.id,
    todayTaskCount = tasks.count { it.calendarDate == today && !it.isCompleted },
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

    fun quickAdd(content: String, category: Category) {
        val trimmed = content.trim()
        if (trimmed.isEmpty()) return
        viewModelScope.launch {
            runCatching {
                when (category) {
                    Category.LOG -> repository.addLog(trimmed, ColorTag.DAILY, Category.LOG)
                    Category.IDEA -> repository.addLog(
                        trimmed,
                        ColorTag.IDEA,
                        Category.IDEA,
                        importance = importanceFromContent(trimmed),
                    )
                }
            }.onFailure {
                eventChannel.send(HomeEvent.Failed(it.message ?: "保存失败，请重试"))
            }
        }
    }

    companion object {
        fun factory(repository: FlashRepository): ViewModelProvider.Factory = viewModelFactory {
            initializer { HomeViewModel(repository) }
        }
    }
}
