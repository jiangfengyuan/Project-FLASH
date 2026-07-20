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
import com.flash.app.data.model.EmotionLevel
import com.flash.app.data.model.EmotionRecord
import com.flash.app.data.model.SubEmotion
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class EmotionViewModel(private val repository: FlashRepository) : ViewModel() {

    val emotions: StateFlow<List<EmotionRecord>> = repository.emotions
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    var selectedLevel by mutableStateOf(EmotionLevel.SLIGHTLY_HAPPY)
        private set
    var selectedSubEmotion by mutableStateOf<SubEmotion?>(null)
        private set
    var note by mutableStateOf("")
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
        val level = selectedLevel
        val sub = if (level.isNegative) selectedSubEmotion else null
        val noteValue = note.ifBlank { null }
        viewModelScope.launch {
            repository.addEmotion(level = level, subEmotion = sub, note = noteValue)
            note = ""
            selectedSubEmotion = null
        }
    }

    fun delete(record: EmotionRecord) {
        viewModelScope.launch { repository.deleteEmotion(record.id) }
    }

    companion object {
        fun factory(repository: FlashRepository): ViewModelProvider.Factory = viewModelFactory {
            initializer { EmotionViewModel(repository) }
        }
    }
}
