package com.japaneseinaflash.app.ui

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import com.japaneseinaflash.app.data.CardDetail
import com.japaneseinaflash.app.data.CardSummary
import com.japaneseinaflash.app.data.DataVersions
import com.japaneseinaflash.app.data.DeviceDictionaryInstaller
import com.japaneseinaflash.app.data.DictionaryFiles
import com.japaneseinaflash.app.data.DictionaryRepository
import com.japaneseinaflash.app.data.SearchPlan
import com.japaneseinaflash.app.data.SearchQuery
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.merge
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

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

enum class SearchNotice {
    TooLong,
}

data class DictionaryUiState(
    val phase: Phase = Phase.Preparing,
    val query: String = "",
    val results: List<CardSummary> = emptyList(),
    val searching: Boolean = false,
    val card: CardDetail? = null,
    val versions: DataVersions? = null,
    val error: DictionaryError? = null,
    val notice: SearchNotice? = null,
)

@OptIn(ExperimentalCoroutinesApi::class, FlowPreview::class)
class DictionaryViewModel internal constructor(
    app: Application,
    private val savedState: SavedStateHandle,
    private val openInstalled: suspend (Application) -> DictionaryRepository,
    private val runQuery: suspend (DictionaryRepository, String) -> List<CardSummary>,
) : AndroidViewModel(app) {

    constructor(app: Application, savedState: SavedStateHandle) : this(
        app,
        savedState,
        { application -> DeviceDictionaryInstaller.open(application) },
        { repository, query -> withContext(Dispatchers.IO) { repository.search(query) } },
    )
    private var repository = CompletableDeferred<DictionaryRepository>()
    private val queryText = MutableStateFlow(savedState.get<String>(KEY_QUERY).orEmpty())
    private val submitTicks = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    private var cardRequest = 0

    @Volatile
    private var cleared = false

    /** Last query that finished without a search error. Failures stay re-runnable. */
    private var lastSuccessfulQuery: String? = null

    private val _state = MutableStateFlow(DictionaryUiState())
    val state: StateFlow<DictionaryUiState> = _state.asStateFlow()

    init {
        _state.value = DictionaryUiState(query = queryText.value)
        viewModelScope.launch(Dispatchers.IO) { prepare() }
        viewModelScope.launch {
            merge(
                queryText.drop(1).debounce(300),
                submitTicks.map { queryText.value },
            ).collectLatest { query ->
                runSearch(query)
            }
        }
        if (queryText.value.isNotEmpty()) {
            submitTicks.tryEmit(Unit)
        }
    }

    suspend fun openRepository(): DictionaryRepository = repository.await()

    fun onQueryChange(value: String) {
        queryText.value = value
        savedState[KEY_QUERY] = value
        _state.update { it.copy(query = value) }
        if (value.isEmpty()) {
            submitTicks.tryEmit(Unit)
        }
    }

    fun submit() {
        submitTicks.tryEmit(Unit)
    }

    fun retry() {
        if (_state.value.phase != Phase.Failed) return
        repository = CompletableDeferred()
        _state.update { it.copy(phase = Phase.Preparing, error = null, searching = false) }
        viewModelScope.launch(Dispatchers.IO) { prepare() }
    }

    fun loadCard(id: Long) {
        viewModelScope.launch { loadCardNow(id) }
    }

    override fun onCleared() {
        cleared = true
        val pending = repository
        if (pending.isCompleted && pending.getCompletionExceptionOrNull() == null) {
            pending.getCompleted().close()
        }
    }

    private suspend fun prepare() {
        val slot = repository
        try {
            val opened = openInstalled(getApplication())
            if (cleared || !slot.complete(opened)) {
                opened.close()
                if (!slot.isCompleted) {
                    slot.completeExceptionally(CancellationException("DictionaryViewModel cleared"))
                }
                return
            }
            val versions = DataVersions(
                cards = opened.databaseVersion(DictionaryFiles.SCHEMA_CARD).orEmpty(),
                search = opened.databaseVersion(DictionaryFiles.SCHEMA_FTS).orEmpty(),
                examples = opened.databaseVersion(DictionaryFiles.SCHEMA_EX).orEmpty(),
            )
            _state.update { it.copy(phase = Phase.Ready, versions = versions, error = null) }
            if (queryText.value.isNotEmpty()) {
                submitTicks.tryEmit(Unit)
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "Could not open the dictionary", e)
            _state.update { it.copy(phase = Phase.Failed, error = DictionaryError.PrepareFailed) }
            if (!slot.isCompleted) slot.completeExceptionally(e)
        }
    }

    private suspend fun loadCardNow(id: Long) {
        val request = ++cardRequest
        _state.update { it.copy(card = null, error = null) }
        try {
            val opened = repository.await()
            val card = withContext(Dispatchers.IO) { opened.loadCard(id) }
            if (request != cardRequest) return
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
            if (request != cardRequest) return
            _state.update { it.copy(card = null, error = DictionaryError.CardFailed) }
        }
    }

    private suspend fun runSearch(query: String) {
        if (query != queryText.value) return
        if (!shouldRunSearch(query, lastSuccessfulQuery, _state.value.error)) return
        when (SearchQuery.plan(query)) {
            SearchPlan.Blank -> {
                if (query != queryText.value) return
                lastSuccessfulQuery = query
                _state.update { it.copy(searching = false, results = emptyList(), error = null, notice = null) }
                return
            }
            SearchPlan.TooLong -> {
                if (query != queryText.value) return
                lastSuccessfulQuery = query
                _state.update {
                    it.copy(searching = false, results = emptyList(), error = null, notice = SearchNotice.TooLong)
                }
                return
            }
            is SearchPlan.Ready -> Unit
        }
        val pending = repository
        val opened = try {
            pending.await()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            return
        }
        if (query != queryText.value) return
        // Leave the previous list on screen until this search returns.
        // Forget the last success while this search is in flight. Otherwise
        // backing up to that query (co? -> co) skips the search and the
        // spinner stays up.
        lastSuccessfulQuery = null
        _state.update { it.copy(searching = true, error = null, notice = null) }
        try {
            val results = runQuery(opened, query)
            if (query != queryText.value) return
            lastSuccessfulQuery = query
            _state.update { it.copy(searching = false, results = results, notice = null) }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "Search failed", e)
            if (query != queryText.value) return
            _state.update {
                it.copy(searching = false, results = emptyList(), error = DictionaryError.SearchFailed, notice = null)
            }
        }
    }

    private companion object {
        const val TAG = "JapaneseInAFlash"
        const val KEY_QUERY = "query"
    }
}

/**
 * Skip only a repeat of a query that already succeeded. An error, including one
 * left from before the dictionary finished opening, has to be allowed through
 * so Enter and Retry can run it again.
 */
internal fun shouldRunSearch(query: String, lastSuccess: String?, error: DictionaryError?): Boolean =
    error != null || query != lastSuccess
