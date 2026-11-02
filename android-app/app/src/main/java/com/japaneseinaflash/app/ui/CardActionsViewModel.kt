package com.japaneseinaflash.app.ui

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.japaneseinaflash.app.data.StudyStore
import com.japaneseinaflash.app.data.TagRecord
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class AddToSetUi(
    val cardId: Long,
    val headword: String,
    val reading: String,
    val sets: List<TagRecord>,
    val checked: Set<Long>,
    val builtIn: List<String>,
    val creating: Boolean = false,
)

class CardActionsViewModel(
    app: Application,
    private val session: DictionaryViewModel,
) : AndroidViewModel(app) {
    private val _sheet = MutableStateFlow<AddToSetUi?>(null)
    val sheet: StateFlow<AddToSetUi?> = _sheet.asStateFlow()

    private val _starred = MutableStateFlow<Map<Long, Boolean>>(emptyMap())
    val starred: StateFlow<Map<Long, Boolean>> = _starred.asStateFlow()

    fun open(cardId: Long) {
        viewModelScope.launch {
            try {
                val repo = session.openRepository()
                val loaded = withContext(Dispatchers.IO) {
                    val study = StudyStore(repo)
                    val card = repo.loadCard(cardId)
                    val membership = study.userSetsForCard(cardId)
                    val builtIn = study.builtInSetsWithCard(cardId)
                    Triple(card, membership, builtIn)
                }
                val card = loaded.first
                val membership = loaded.second
                _starred.update { it + (cardId to (membership.firstOrNull { set -> set.first.id == 0L }?.second == true)) }
                _sheet.value = AddToSetUi(
                    cardId = cardId,
                    headword = card?.headword.orEmpty(),
                    reading = card?.reading.orEmpty(),
                    sets = membership.map { it.first },
                    checked = membership.filter { it.second }.map { it.first.id }.toSet(),
                    builtIn = loaded.third.map { it.name },
                )
            } catch (e: Exception) {
                Log.e(TAG, "Could not open add to set", e)
            }
        }
    }

    fun dismiss() = _sheet.update { it?.copy(creating = false) }.also { _sheet.value = null }

    fun startCreate() = _sheet.update { it?.copy(creating = true) }

    fun cancelCreate() = _sheet.update { it?.copy(creating = false) }

    fun toggle(tagId: Long, member: Boolean) {
        val cardId = _sheet.value?.cardId ?: return
        _sheet.update { sheet ->
            sheet?.copy(
                checked = if (member) sheet.checked + tagId else sheet.checked - tagId,
            )
        }
        if (tagId == 0L) _starred.update { it + (cardId to member) }
        viewModelScope.launch {
            try {
                val study = StudyStore(session.openRepository())
                withContext(Dispatchers.IO) { study.setMembership(tagId, cardId, member) }
            } catch (e: Exception) {
                Log.e(TAG, "Could not update set membership", e)
            }
        }
    }

    fun create(name: String) {
        val cardId = _sheet.value?.cardId ?: return
        viewModelScope.launch {
            try {
                val study = StudyStore(session.openRepository())
                val id = withContext(Dispatchers.IO) {
                    val created = study.createSet(name)
                    if (created != null) study.setMembership(created, cardId, true)
                    created
                }
                _sheet.update { it?.copy(creating = false) }
                if (id != null) open(cardId)
            } catch (e: Exception) {
                Log.e(TAG, "Could not create a set", e)
                _sheet.update { it?.copy(creating = false) }
            }
        }
    }

    fun setStar(cardId: Long, member: Boolean) {
        _starred.update { it + (cardId to member) }
        viewModelScope.launch {
            try {
                val study = StudyStore(session.openRepository())
                withContext(Dispatchers.IO) { study.setMembership(0L, cardId, member) }
            } catch (e: Exception) {
                Log.e(TAG, "Could not update starred", e)
            }
        }
    }

    fun starred(cardId: Long): Boolean = _starred.value[cardId] == true

    fun refreshStar(cardId: Long) {
        viewModelScope.launch {
            try {
                val study = StudyStore(session.openRepository())
                val member = withContext(Dispatchers.IO) {
                    study.userSetsForCard(cardId).firstOrNull { it.first.id == 0L }?.second == true
                }
                _starred.update { it + (cardId to member) }
            } catch (e: Exception) {
                Log.e(TAG, "Could not read starred", e)
            }
        }
    }

    companion object {
        private const val TAG = "CardActions"

        fun factory(session: DictionaryViewModel): ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val app = this[ViewModelProvider.AndroidViewModelFactory.APPLICATION_KEY] as Application
                CardActionsViewModel(app, session)
            }
        }
    }
}
