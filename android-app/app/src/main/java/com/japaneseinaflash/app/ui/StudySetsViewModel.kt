package com.japaneseinaflash.app.ui

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.japaneseinaflash.app.data.AppPreferencesStore
import com.japaneseinaflash.app.data.GroupRecord
import com.japaneseinaflash.app.data.StudyStore
import com.japaneseinaflash.app.data.TagRecord
import com.japaneseinaflash.app.study.opensAsSearch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class SetsUiState(
    val loading: Boolean = true,
    val loadFailed: Boolean = false,
    val createFailed: Boolean = false,
    val searchFailed: Boolean = false,
    val title: String = "",
    val titleJa: String = "",
    val studying: TagRecord? = null,
    val activeId: Long = 0,
    val mySets: List<TagRecord> = emptyList(),
    val groups: List<GroupRecord> = emptyList(),
    val tags: List<TagRecord> = emptyList(),
    val searchOnly: Boolean = false,
    val query: String = "",
    val results: List<TagRecord> = emptyList(),
    val searching: Boolean = false,
    val confirm: TagRecord? = null,
    val emptySet: TagRecord? = null,
    val creating: Boolean = false,
)

class StudySetsViewModel(
    app: Application,
    private val session: DictionaryViewModel,
    private val store: AppPreferencesStore,
    private val groupId: Long?,
) : AndroidViewModel(app) {
    private val _state = MutableStateFlow(SetsUiState())
    val state: StateFlow<SetsUiState> = _state.asStateFlow()
    private val queries = MutableStateFlow("")

    init {
        reload()
        viewModelScope.watchSetSearch(queries, find = { query ->
            withContext(Dispatchers.IO) { StudyStore(session.openRepository()).searchTags(query) }
        }) { rows, searchFailed ->
            _state.update {
                it.copy(results = rows, searching = false, searchFailed = searchFailed)
            }
        }
    }

    fun onQuery(value: String) {
        _state.update {
            it.copy(query = value, searchFailed = false, searching = value.isNotBlank())
        }
        queries.value = value
    }

    fun askToStart(tag: TagRecord) {
        if (tag.count <= 0) {
            _state.update { it.copy(emptySet = tag) }
            return
        }
        if (tag.id == _state.value.activeId) return
        _state.update { it.copy(confirm = tag) }
    }

    fun dismissDialogs() = _state.update { it.copy(confirm = null, emptySet = null, creating = false) }

    fun confirmStart(onStarted: () -> Unit) {
        val tag = _state.value.confirm ?: return
        viewModelScope.launch {
            store.update { it.copy(tagId = tag.id) }
            _state.update { it.copy(confirm = null, activeId = tag.id) }
            onStarted()
        }
    }

    fun startCreate() = _state.update { it.copy(creating = true) }

    fun create(name: String) {
        viewModelScope.launch {
            try {
                val study = StudyStore(session.openRepository())
                withContext(Dispatchers.IO) { study.createSet(name) }
                _state.update { it.copy(creating = false, createFailed = false) }
                reload()
            } catch (e: Exception) {
                Log.e(TAG, "Could not create a set", e)
                _state.update { it.copy(creating = false, createFailed = true) }
            }
        }
    }

    private fun reload() {
        viewModelScope.launch {
            _state.update { it.copy(loading = true, loadFailed = false) }
            try {
                val prefs = store.preferences.first()
                val study = StudyStore(session.openRepository())
                val snapshot = withContext(Dispatchers.IO) {
                    val active = study.tag(prefs.tagId)
                    if (groupId == null) {
                        val top = study.topGroupId()
                        Loaded(
                            title = "",
                            titleJa = "",
                            studying = active,
                            mySets = study.mySets(),
                            groups = top?.let { study.groups(it) }.orEmpty(),
                            tags = emptyList(),
                            searchOnly = false,
                            activeId = prefs.tagId,
                        )
                    } else {
                        val group = study.group(groupId)
                        val searchOnly = group != null && opensAsSearch(group.name)
                        Loaded(
                            title = group?.name.orEmpty(),
                            titleJa = group?.nameJa.orEmpty(),
                            studying = null,
                            mySets = emptyList(),
                            groups = if (group != null && group.childGroups > 0) study.groups(group.id) else emptyList(),
                            tags = if (searchOnly || group == null) emptyList() else study.tagsInGroup(group.id),
                            searchOnly = searchOnly,
                            activeId = prefs.tagId,
                        )
                    }
                }
                _state.update {
                    it.copy(
                        loading = false,
                        title = snapshot.title,
                        titleJa = snapshot.titleJa,
                        studying = snapshot.studying,
                        mySets = snapshot.mySets,
                        groups = snapshot.groups,
                        tags = snapshot.tags,
                        searchOnly = snapshot.searchOnly,
                        activeId = snapshot.activeId,
                        loadFailed = false,
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Could not load study sets", e)
                _state.update { it.copy(loading = false, loadFailed = true) }
            }
        }
    }

    private data class Loaded(
        val title: String,
        val titleJa: String,
        val studying: TagRecord?,
        val mySets: List<TagRecord>,
        val groups: List<GroupRecord>,
        val tags: List<TagRecord>,
        val searchOnly: Boolean,
        val activeId: Long,
    )

    companion object {
        private const val TAG = "StudySets"

        fun factory(session: DictionaryViewModel, store: AppPreferencesStore, groupId: Long?): ViewModelProvider.Factory =
            viewModelFactory {
                initializer {
                    val app = this[ViewModelProvider.AndroidViewModelFactory.APPLICATION_KEY] as Application
                    StudySetsViewModel(app, session, store, groupId)
                }
            }
    }
}

internal fun kotlinx.coroutines.CoroutineScope.watchSetSearch(
    queries: kotlinx.coroutines.flow.Flow<String>,
    debounceMs: Long = 200,
    find: suspend (String) -> List<TagRecord>,
    publish: (List<TagRecord>, Boolean) -> Unit,
) = launch {
    queries.debounce(debounceMs).collectLatest { raw ->
        val trimmed = raw.trim()
        if (trimmed.isEmpty()) {
            publish(emptyList(), false)
            return@collectLatest
        }
        try {
            publish(find(trimmed), false)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            publish(emptyList(), true)
        }
    }
}
