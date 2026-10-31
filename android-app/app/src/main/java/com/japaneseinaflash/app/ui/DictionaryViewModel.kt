package com.japaneseinaflash.app.ui

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.japaneseinaflash.app.data.CardDetail
import com.japaneseinaflash.app.data.CardSummary
import com.japaneseinaflash.app.data.DataVersions
import com.japaneseinaflash.app.data.DeviceDictionaryInstaller
import com.japaneseinaflash.app.data.DictionaryFiles
import com.japaneseinaflash.app.data.DictionaryRepository
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.merge
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

sealed interface Screen {
    data object Search : Screen
    data class Detail(val cardId: Long) : Screen
    data object About : Screen
}

enum class Phase {
    Preparing,
    Ready,
    Failed,
}

enum class DictionaryError {
    PrepareFailed,
    SearchFailed,
    CardFailed,
    CardMissing,
}

data class DictionaryUiState(
    val phase: Phase = Phase.Preparing,
    val query: String = "",
    val results: List<CardSummary> = emptyList(),
    val searching: Boolean = false,
    val screen: Screen = Screen.Search,
    val canGoBack: Boolean = false,
    val card: CardDetail? = null,
    val versions: DataVersions? = null,
    val error: DictionaryError? = null,
)

@OptIn(ExperimentalCoroutinesApi::class)
class DictionaryViewModel(app: Application) : AndroidViewModel(app) {
    private val repository = CompletableDeferred<DictionaryRepository>()
    private val queryText = MutableStateFlow("")
    private val submitTicks = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    private val backStack = ArrayDeque<Screen>()
    private var cardRequest = 0

    private val _state = MutableStateFlow(DictionaryUiState())
    val state: StateFlow<DictionaryUiState> = _state.asStateFlow()

    init {
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val installed = DeviceDictionaryInstaller.install(getApplication())
                val opened = DictionaryRepository.open(installed)
                val versions = DataVersions(
                    cards = opened.databaseVersion(DictionaryFiles.SCHEMA_CARD).orEmpty(),
                    search = opened.databaseVersion(DictionaryFiles.SCHEMA_FTS).orEmpty(),
                    examples = opened.databaseVersion(DictionaryFiles.SCHEMA_EX).orEmpty(),
                )
                repository.complete(opened)
                _state.update { it.copy(phase = Phase.Ready, versions = versions) }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.e(TAG, "Could not open the dictionary", e)
                _state.update { it.copy(phase = Phase.Failed, error = DictionaryError.PrepareFailed) }
                repository.completeExceptionally(e)
            }
        }
        viewModelScope.launch {
            merge(
                queryText.drop(1).debounce(300),
                submitTicks.map { queryText.value },
            ).collectLatest { query ->
                runSearch(query)
            }
        }
    }

    fun onQueryChange(value: String) {
        queryText.value = value
        _state.update { it.copy(query = value) }
        if (value.isEmpty()) {
            submitTicks.tryEmit(Unit)
        }
    }

    fun submit() {
        submitTicks.tryEmit(Unit)
    }

    fun openCard(id: Long) {
        val request = ++cardRequest
        push(Screen.Detail(id))
        _state.update { it.copy(card = null, error = null) }
        viewModelScope.launch {
            try {
                val opened = repository.await()
                val card = withContext(Dispatchers.IO) { opened.loadCard(id) }
                if (request != cardRequest) return@launch
                _state.update {
                    it.copy(
                        card = card,
                        error = if (card == null) DictionaryError.CardMissing else null,
                    )
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                Log.e(TAG, "Could not load card $id", e)
                if (request != cardRequest) return@launch
                _state.update { it.copy(card = null, error = DictionaryError.CardFailed) }
            }
        }
    }

    fun openAbout() {
        if (_state.value.screen is Screen.About) return
        push(Screen.About)
    }

    fun back() {
        val previous = backStack.removeLastOrNull() ?: return
        _state.update {
            it.copy(screen = previous, canGoBack = backStack.isNotEmpty(), error = null)
        }
    }

    override fun onCleared() {
        if (repository.isCompleted && repository.getCompletionExceptionOrNull() == null) {
            repository.getCompleted().close()
        }
    }

    private fun push(screen: Screen) {
        backStack.addLast(_state.value.screen)
        _state.update { it.copy(screen = screen, canGoBack = true) }
    }

    private suspend fun runSearch(query: String) {
        val opened = try {
            repository.await()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            return
        }
        if (query != queryText.value) return
        if (query.isBlank()) {
            _state.update { it.copy(searching = false, results = emptyList(), error = null) }
            return
        }
        _state.update { it.copy(searching = true, results = emptyList(), error = null) }
        try {
            val results = withContext(Dispatchers.IO) { opened.search(query) }
            if (query != queryText.value) return
            _state.update { it.copy(searching = false, results = results) }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "Search failed", e)
            if (query != queryText.value) return
            _state.update {
                it.copy(searching = false, results = emptyList(), error = DictionaryError.SearchFailed)
            }
        }
    }

    private companion object {
        const val TAG = "JapaneseInAFlash"
    }
}
