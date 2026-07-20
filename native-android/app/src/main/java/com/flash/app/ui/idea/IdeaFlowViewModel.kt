package com.flash.app.ui.idea

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
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/** 对应 Web 版 IdeaFlow：灵感（category=idea）按日期分组，重要性从内容 !! 推断 */
class IdeaFlowViewModel(private val repository: FlashRepository) : ViewModel() {

    val ideaGroups: StateFlow<List<Pair<String, List<LogItem>>>> = repository.logs
        .map { logs ->
            logs.filter { it.category == Category.IDEA }
                .groupBy { it.recordDate }
                .toList()
                .sortedByDescending { it.first }
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private val _text = MutableStateFlow("")
    val text: StateFlow<String> = _text.asStateFlow()

    fun updateText(value: String) {
        _text.value = value.take(MAX_LENGTH)
    }

    fun save() {
        val content = _text.value.trim()
        if (content.isEmpty()) return
        viewModelScope.launch {
            repository.addLog(
                content = content,
                colorTag = ColorTag.IDEA,
                category = Category.IDEA,
                importance = importanceFromContent(content),
            )
            _text.value = ""
        }
    }

    fun delete(id: String) {
        viewModelScope.launch { repository.deleteLog(id) }
    }

    companion object {
        const val MAX_LENGTH = 140

        fun factory(repository: FlashRepository): ViewModelProvider.Factory = viewModelFactory {
            initializer { IdeaFlowViewModel(repository) }
        }
    }
}
