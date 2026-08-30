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
import com.flash.app.data.model.importanceFromContent
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.LocalDate

data class HomeUiState(
    val todayLogCount: Int = 0,
    val todayIdeaCount: Int = 0,
    val todayEmotionCount: Int = 0,
    val latestEmotion: EmotionRecord? = null,
    val recentLogs: List<LogItem> = emptyList(),
)

class HomeViewModel(private val repository: FlashRepository) : ViewModel() {

    val uiState: StateFlow<HomeUiState> = combine(
        repository.logs,
        repository.emotions,
    ) { logs, emotions ->
        val today = LocalDate.now().toString()
        HomeUiState(
            todayLogCount = logs.count { it.recordDate == today && it.category == Category.LOG },
            todayIdeaCount = logs.count { it.recordDate == today && it.category == Category.IDEA },
            todayEmotionCount = emotions.count { it.recordDate == today },
            // “当前”只表示今天的状态，避免把几天前的情绪误导为此刻情绪。
            latestEmotion = emotions.firstOrNull { it.recordDate == today },
            recentLogs = logs.take(5),
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), HomeUiState())

    fun quickAdd(content: String, category: Category) {
        val trimmed = content.trim()
        if (trimmed.isEmpty()) return
        viewModelScope.launch {
            when (category) {
                Category.LOG -> repository.addLog(trimmed, ColorTag.DAILY, Category.LOG)
                Category.IDEA -> repository.addLog(
                    trimmed,
                    ColorTag.IDEA,
                    Category.IDEA,
                    importance = importanceFromContent(trimmed),
                )
            }
        }
    }

    companion object {
        fun factory(repository: FlashRepository): ViewModelProvider.Factory = viewModelFactory {
            initializer { HomeViewModel(repository) }
        }
    }
}
