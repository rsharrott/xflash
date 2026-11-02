package com.japaneseinaflash.app.ui

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.japaneseinaflash.app.data.AppPreferencesStore
import com.japaneseinaflash.app.data.PracticeCard
import com.japaneseinaflash.app.data.StudyStore
import com.japaneseinaflash.app.study.AppPreferences
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlin.random.Random

data class PracticeUiState(
    val setName: String = "",
    val levels: IntArray = IntArray(6),
    val total: Int = 0,
    val card: PracticeCard? = null,
    val revealed: Boolean = false,
    val showReading: Boolean = false,
    val empty: Boolean = false,
    val loading: Boolean = true,
    val failed: Boolean = false,
)

class PracticeViewModel(
    app: Application,
    private val session: DictionaryViewModel,
    private val store: AppPreferencesStore,
) : AndroidViewModel(app) {
    val preferences: StateFlow<AppPreferences> = store.preferences.stateIn(
        viewModelScope,
        SharingStarted.WhileSubscribed(5_000),
        AppPreferences(),
    )

    private val _state = MutableStateFlow(PracticeUiState())
    val state: StateFlow<PracticeUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            session.state.map { it.phase }.distinctUntilChanged().collect { phase ->
                if (phase == Phase.Ready) reload(avoid = null)
            }
        }
        viewModelScope.launch {
            store.preferences.map { it.cardKey() }.distinctUntilChanged().collect {
                if (session.state.value.phase == Phase.Ready && !_state.value.loading) {
                    reload(avoid = null)
                }
            }
        }
    }

    fun showAnswer() = _state.update { it.copy(revealed = true) }

    fun toggleReading() = _state.update { it.copy(showReading = !it.showReading) }

    fun mark(right: Boolean) {
        val card = _state.value.card ?: return
        viewModelScope.launch {
            val prefs = preferences.value
            try {
                val study = StudyStore(session.openRepository())
                withContext(Dispatchers.IO) { study.record(card, prefs.userId, right) }
                reload(avoid = card.detail.id)
            } catch (e: Exception) {
                Log.e(TAG, "Could not record the answer", e)
                _state.update { it.copy(failed = true) }
            }
        }
    }

    private fun reload(avoid: Long?) {
        viewModelScope.launch {
            _state.update { it.copy(loading = true, failed = false) }
            try {
                val prefs = preferences.value
                val study = StudyStore(session.openRepository())
                val snapshot = withContext(Dispatchers.IO) {
                    val tag = study.tag(prefs.tagId) ?: study.tag(AppPreferences.DEFAULT_TAG_ID)
                    if (tag == null) return@withContext null
                    val pool = prefs.pool()
                    val card = study.nextPracticeCard(
                        tag = tag,
                        userId = prefs.userId,
                        maxCards = pool.maxCards,
                        frequency = pool.frequency,
                        hideLearned = prefs.hideLearned,
                        random = Random.nextDouble(),
                        avoid = avoid,
                    )
                    val levels = study.levelCounts(tag, prefs.userId)
                    Triple(tag.name, levels, card)
                }
                if (snapshot == null) {
                    _state.update { it.copy(loading = false, empty = true, card = null, failed = false) }
                    return@launch
                }
                val (name, levels, card) = snapshot
                _state.update {
                    it.copy(
                        setName = name,
                        levels = levels,
                        total = levels.sum(),
                        card = card,
                        revealed = false,
                        showReading = false,
                        empty = card == null,
                        loading = false,
                        failed = false,
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Could not load practice", e)
                _state.update { it.copy(loading = false, failed = true) }
            }
        }
    }

    private companion object {
        const val TAG = "Practice"
    }
}
