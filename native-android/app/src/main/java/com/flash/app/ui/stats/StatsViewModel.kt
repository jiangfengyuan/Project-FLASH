package com.flash.app.ui.stats

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.flash.app.data.FlashRepository
import com.flash.app.data.model.Category
import com.flash.app.data.model.EmotionRecord
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn

data class StatsUiState(
    val totalLogs: Int = 0,
    val totalIdeas: Int = 0,
    val totalEmotions: Int = 0,
    val activeDays: Int = 0,
    val emotions: List<EmotionRecord> = emptyList(),
)

class StatsViewModel(repository: FlashRepository) : ViewModel() {

    val uiState: StateFlow<StatsUiState> = combine(
        repository.logs,
        repository.emotions,
    ) { logs, emotions ->
        StatsUiState(
            totalLogs = logs.count { it.category == Category.LOG },
            totalIdeas = logs.count { it.category == Category.IDEA },
            totalEmotions = emotions.size,
            activeDays = (logs.map { it.recordDate } + emotions.map { it.recordDate }).distinct().size,
            emotions = emotions,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), StatsUiState())

    companion object {
        fun factory(repository: FlashRepository): ViewModelProvider.Factory = viewModelFactory {
            initializer { StatsViewModel(repository) }
        }
    }
}
