package com.japaneseinaflash.app.ui

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.japaneseinaflash.app.data.AppPreferencesStore
import com.japaneseinaflash.app.data.DictionaryRepository
import com.japaneseinaflash.app.data.StudyStore
import com.japaneseinaflash.app.study.AppPreferences
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
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
    val card: com.japaneseinaflash.app.data.PracticeCard? = null,
    val revealed: Boolean = false,
    val showReading: Boolean = false,
    val empty: Boolean = false,
    val loading: Boolean = true,
    val failed: Boolean = false,
    val allLearned: Boolean = false,
)

class PracticeViewModel(
    app: Application,
    private val openRepository: suspend () -> DictionaryRepository,
    phase: Flow<Phase>,
    private val store: AppPreferencesStore,
) : AndroidViewModel(app) {
    val preferences: StateFlow<AppPreferences> = store.preferences.stateIn(
        viewModelScope,
        SharingStarted.Eagerly,
        AppPreferences(),
    )

    private val _state = MutableStateFlow(PracticeUiState())
    val state: StateFlow<PracticeUiState> = _state.asStateFlow()
    private var loadJob: Job? = null
    private var marking = false

    init {
        viewModelScope.launch {
            combine(
                phase,
                store.preferences.map { it.cardKey() },
            ) { ready, key -> ready to key }
                .collectLatest { (ready, _) ->
                    if (ready == Phase.Ready) load(avoid = null)
                }
        }
    }

    fun showAnswer() = _state.update { it.copy(revealed = true) }

    fun toggleReading() = _state.update { it.copy(showReading = !it.showReading) }

    fun dismissAllLearned() = _state.update { it.copy(allLearned = false) }

    fun mark(right: Boolean) {
        if (marking) return
        val card = _state.value.card ?: return
        marking = true
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            try {
                val prefs = store.preferences.first()
                val study = StudyStore(openRepository())
                withContext(Dispatchers.IO) { study.record(card, prefs.userId, right) }
                loadBody(avoid = card.detail.id)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.e(TAG, "Could not record the answer", e)
                _state.update { it.copy(failed = true) }
            } finally {
                marking = false
            }
        }
    }

    private fun load(avoid: Long?) {
        loadJob?.cancel()
        loadJob = viewModelScope.launch { loadBody(avoid) }
    }

    private suspend fun loadBody(avoid: Long?) {
        _state.update { it.copy(loading = true, failed = false) }
        try {
            val prefs = store.preferences.first()
            val study = StudyStore(openRepository())
            val snapshot = withContext(Dispatchers.IO) {
                val tag = study.tag(prefs.tagId) ?: study.tag(AppPreferences.DEFAULT_TAG_ID)
                if (tag == null) return@withContext null
                val pool = prefs.pool()
                val pick = study.nextPracticeCard(
                    tag = tag,
                    userId = prefs.userId,
                    maxCards = pool.maxCards,
                    frequency = pool.frequency,
                    hideLearned = prefs.hideLearned,
                    random = Random.nextDouble(),
                    avoid = avoid,
                )
                val levels = study.levelCounts(tag, prefs.userId)
                Loaded(tag.name, levels, pick)
            }
            if (snapshot == null) {
                _state.update { it.copy(loading = false, empty = true, card = null, failed = false) }
                return
            }
            _state.update {
                it.copy(
                    setName = snapshot.name,
                    levels = snapshot.levels,
                    total = snapshot.levels.sum(),
                    card = snapshot.pick?.card,
                    revealed = false,
                    showReading = false,
                    empty = snapshot.pick == null,
                    loading = false,
                    failed = false,
                    allLearned = snapshot.pick?.allLearned == true,
                )
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "Could not load practice", e)
            _state.update { it.copy(loading = false, failed = true) }
        }
    }

    private data class Loaded(
        val name: String,
        val levels: IntArray,
        val pick: com.japaneseinaflash.app.data.PracticePick?,
    )

    private companion object {
        const val TAG = "Practice"
    }
}
