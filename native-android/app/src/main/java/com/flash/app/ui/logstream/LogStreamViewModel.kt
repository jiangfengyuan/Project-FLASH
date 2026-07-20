package com.flash.app.ui.logstream

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
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class LogStreamViewModel(private val repository: FlashRepository) : ViewModel() {

    /** 最近的日志流（全部类别，最新在前），对应 Web 版 StreamList */
    val recentLogs: StateFlow<List<LogItem>> = repository.logs
        .map { it.take(RECENT_LIMIT) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private val _text = MutableStateFlow("")
    val text: StateFlow<String> = _text.asStateFlow()

    private val _selectedTag = MutableStateFlow<ColorTag?>(null)
    val selectedTag: StateFlow<ColorTag?> = _selectedTag.asStateFlow()

    fun updateText(value: String) {
        _text.value = value.take(MAX_LENGTH)
    }

    fun toggleTag(tag: ColorTag) {
        _selectedTag.value = if (_selectedTag.value == tag) null else tag
    }

    fun save() {
        val content = _text.value.trim()
        if (content.isEmpty()) return
        val tag = _selectedTag.value ?: ColorTag.DAILY
        viewModelScope.launch {
            repository.addLog(content = content, colorTag = tag, category = Category.LOG)
            _text.value = ""
            _selectedTag.value = null
        }
    }

    companion object {
        const val MAX_LENGTH = 140
        private const val RECENT_LIMIT = 50

        fun factory(repository: FlashRepository): ViewModelProvider.Factory = viewModelFactory {
            initializer { LogStreamViewModel(repository) }
        }
    }
}
