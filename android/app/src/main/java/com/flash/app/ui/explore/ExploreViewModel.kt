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
import com.flash.app.data.model.importanceFromContent
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

enum class ExploreFilter(val displayName: String) {
    ALL("全部"),
    LOG("日志"),
    IDEA("灵感"),
}

/** 探索页：统一信息流（日志+灵感），模块筛选 + 底部快速输入 */
class ExploreViewModel(private val repository: FlashRepository) : ViewModel() {

    private val _filter = MutableStateFlow(ExploreFilter.ALL)
    val filter: StateFlow<ExploreFilter> = _filter.asStateFlow()

    val logs: StateFlow<List<LogItem>> = combine(
        repository.logs,
        _filter,
    ) { logs, filter ->
        when (filter) {
            ExploreFilter.ALL -> logs
            ExploreFilter.LOG -> logs.filter { it.category == Category.LOG }
            ExploreFilter.IDEA -> logs.filter { it.category == Category.IDEA }
        }
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private val _text = MutableStateFlow("")
    val text: StateFlow<String> = _text.asStateFlow()

    private val _selectedTag = MutableStateFlow<ColorTag?>(null)
    val selectedTag: StateFlow<ColorTag?> = _selectedTag.asStateFlow()

    fun setFilter(filter: ExploreFilter) {
        _filter.value = filter
    }

    fun updateText(value: String) {
        _text.value = value.take(MAX_LENGTH)
    }

    fun toggleTag(tag: ColorTag) {
        _selectedTag.value = if (_selectedTag.value == tag) null else tag
    }

    /** 当前筛选为「灵感」时按灵感保存（含 !! 重要性推断），否则存为日志 */
    fun save() {
        val content = _text.value.trim()
        if (content.isEmpty()) return
        val asIdea = _filter.value == ExploreFilter.IDEA
        val tag = _selectedTag.value ?: if (asIdea) ColorTag.IDEA else ColorTag.DAILY
        viewModelScope.launch {
            repository.addLog(
                content = content,
                colorTag = tag,
                category = if (asIdea) Category.IDEA else Category.LOG,
                importance = if (asIdea) importanceFromContent(content) else 0,
            )
            _text.value = ""
            _selectedTag.value = null
        }
    }

    companion object {
        const val MAX_LENGTH = 140

        fun factory(repository: FlashRepository): ViewModelProvider.Factory = viewModelFactory {
            initializer { ExploreViewModel(repository) }
        }
    }
}
