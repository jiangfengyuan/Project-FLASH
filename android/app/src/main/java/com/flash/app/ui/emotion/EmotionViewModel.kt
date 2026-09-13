// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.emotion

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.flash.app.data.FlashRepository
import com.flash.app.data.TextLimits
import com.flash.app.data.model.EmotionLevel
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.SubEmotion
import com.flash.app.domain.EmotionStats
import com.flash.app.domain.todayFlow
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

sealed interface EmotionEvent {
    data class Failed(val message: String) : EmotionEvent
}

@OptIn(ExperimentalCoroutinesApi::class)
class EmotionViewModel(private val repository: FlashRepository) : ViewModel() {

    private val eventChannel = Channel<EmotionEvent>(Channel.BUFFERED)
    val events = eventChannel.receiveAsFlow()

    /** 历史列表分页上限，滑到底部时按页增大（配合 DAO 的 LIMIT 查询） */
    private val _historyLimit = MutableStateFlow(HISTORY_PAGE_SIZE)

    private val _hasMoreHistory = MutableStateFlow(false)
    val hasMoreHistory: StateFlow<Boolean> = _hasMoreHistory.asStateFlow()

    /** 历史列表：只把前 N 条读进内存，不再全表加载 */
    val emotions: StateFlow<List<EmotionRecord>> = _historyLimit
        .flatMapLatest { limit ->
            repository.observeEmotionPage(limit)
                .onEach { list -> _hasMoreHistory.value = list.size >= limit }
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    /** 统计卡片只需要近期窗口（本周/近 30 天），按 recordDate 下推且随跨天刷新 */
    val statsEmotions: StateFlow<List<EmotionRecord>> = todayFlow()
        .flatMapLatest { today ->
            repository.observeEmotionsSince(EmotionStats.rollingWindow(STATS_WINDOW_DAYS, today).first.toString())
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun loadMoreHistory() {
        if (_hasMoreHistory.value) _historyLimit.value += HISTORY_PAGE_SIZE
    }

    var selectedLevel by mutableStateOf(EmotionLevel.SLIGHTLY_HAPPY)
        private set
    var selectedSubEmotion by mutableStateOf<SubEmotion?>(null)
        private set
    var note by mutableStateOf("")
        private set

    /** 保存期间为 true，用于防连点重复提交 */
    var saving by mutableStateOf(false)
        private set

    fun selectLevel(level: EmotionLevel) {
        selectedLevel = level
        // 子情绪仅存在于负面等级（与 Web 版 setCurrentLevel 逻辑一致）
        if (!level.isNegative) selectedSubEmotion = null
    }

    fun selectSubEmotion(sub: SubEmotion?) {
        selectedSubEmotion = if (selectedSubEmotion == sub) null else sub
    }

    fun updateNote(value: String) {
        note = value
    }

    fun save() {
        if (saving) return
        val level = selectedLevel
        val sub = if (level.isNegative) selectedSubEmotion else null
        val noteValue = note.ifBlank { null }
        // 超限不静默截断：提示并保留输入（对齐 macOS TextLimits 行为）
        if (noteValue != null && !TextLimits.fits(noteValue)) {
            viewModelScope.launch {
                eventChannel.send(
                    EmotionEvent.Failed(
                        TextLimits.ContentTooLongException(noteValue.length, TextLimits.MAX_CONTENT_LENGTH).message
                            ?: "备注过长，请删减后再保存",
                    )
                )
            }
            return
        }
        // 先同步置 saving + 清状态再 launch，防止连点产生重复记录
        saving = true
        note = ""
        selectedSubEmotion = null
        viewModelScope.launch {
            try {
                runCatching { repository.addEmotion(level = level, subEmotion = sub, note = noteValue) }
                    .onFailure {
                        eventChannel.send(EmotionEvent.Failed(it.message ?: "保存失败，请重试"))
                    }
            } finally {
                saving = false
            }
        }
    }

    fun delete(record: EmotionRecord) {
        viewModelScope.launch {
            runCatching { repository.deleteEmotion(record.id) }
                .onFailure {
                    eventChannel.send(EmotionEvent.Failed(it.message ?: "删除失败，请重试"))
                }
        }
    }

    companion object {
        const val HISTORY_PAGE_SIZE = 50

        /** EmotionStatsSection 最长窗口为滚动 30 天 */
        private const val STATS_WINDOW_DAYS = 30

        fun factory(repository: FlashRepository): ViewModelProvider.Factory = viewModelFactory {
            initializer { EmotionViewModel(repository) }
        }
    }
}
