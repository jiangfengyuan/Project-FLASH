// Copyright (c) 2026 Fengyuan Jiang
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package com.flash.app.ui.detail

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
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class RecordDetailUiState(
    val loaded: Boolean = false,
    val record: LogItem? = null,
    val busy: Boolean = false,
)

sealed interface RecordDetailEvent {
    data object Saved : RecordDetailEvent
    data object Deleted : RecordDetailEvent
    data class Failed(val message: String) : RecordDetailEvent
}

class RecordDetailViewModel(
    private val repository: FlashRepository,
    recordId: String,
) : ViewModel() {

    private val busy = MutableStateFlow(false)
    private val source = repository.observeLog(recordId).map { record -> true to record }

    val uiState: StateFlow<RecordDetailUiState> = combine(source, busy) { (loaded, record), isBusy ->
        RecordDetailUiState(loaded = loaded, record = record, busy = isBusy)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), RecordDetailUiState())

    private val eventChannel = Channel<RecordDetailEvent>(Channel.BUFFERED)
    val events = eventChannel.receiveAsFlow()

    init {
        // SQL 仅会标记实际属于 IDEA 的记录；普通日志不会产生无效阅读状态。
        viewModelScope.launch { repository.markIdeaViewed(recordId) }
    }

    fun save(content: String, colorTag: ColorTag, category: Category, importance: Int) {
        val current = uiState.value.record ?: return
        // 超限不静默截断：repository.updateLog 会拒绝并抛出带可读信息的异常，
        // 由 Failed 事件提示；编辑框自身也已禁用超限保存。
        val normalized = content.trim()
        if (normalized.isEmpty() || busy.value) return
        busy.value = true
        viewModelScope.launch {
            runCatching {
                repository.updateLog(
                    current.copy(
                        content = normalized,
                        colorTag = colorTag,
                        category = category,
                        importance = importance.coerceIn(0, 4),
                    )
                )
                // 从日志切换为 Idea 也属于一次主动处理，不应重新进入“待梳理”。
                if (category == Category.IDEA) repository.markIdeaViewed(current.id)
            }.onSuccess {
                eventChannel.send(RecordDetailEvent.Saved)
            }.onFailure {
                eventChannel.send(RecordDetailEvent.Failed(it.message ?: "保存失败，请重试"))
            }
            busy.value = false
        }
    }

    fun delete() {
        val id = uiState.value.record?.id ?: return
        if (busy.value) return
        busy.value = true
        viewModelScope.launch {
            runCatching { repository.deleteLog(id) }
                .onSuccess { eventChannel.send(RecordDetailEvent.Deleted) }
                .onFailure {
                    eventChannel.send(RecordDetailEvent.Failed(it.message ?: "删除失败，请重试"))
                }
            busy.value = false
        }
    }

    companion object {
        fun factory(repository: FlashRepository, recordId: String): ViewModelProvider.Factory = viewModelFactory {
            initializer { RecordDetailViewModel(repository, recordId) }
        }
    }
}
