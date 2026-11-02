package com.japaneseinaflash.app.ui

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.japaneseinaflash.app.data.AppPreferencesStore
import com.japaneseinaflash.app.data.MembershipResult
import com.japaneseinaflash.app.data.StudyStore
import com.japaneseinaflash.app.data.TagRecord
import com.japaneseinaflash.app.study.STARRED_TAG_ID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

data class AddToSetUi(
    val cardId: Long,
    val headword: String,
    val reading: String,
    val sets: List<TagRecord>,
    val checked: Set<Long>,
    val builtIn: List<TagRecord>,
    val creating: Boolean = false,
)

class CardActionsViewModel(
    app: Application,
    private val session: DictionaryViewModel,
    private val preferences: AppPreferencesStore,
) : AndroidViewModel(app) {
    private val writes = Mutex()
    private val _sheet = MutableStateFlow<AddToSetUi?>(null)
    val sheet: StateFlow<AddToSetUi?> = _sheet.asStateFlow()

    private val _starred = MutableStateFlow<Map<Long, Boolean>>(emptyMap())
    val starred: StateFlow<Map<Long, Boolean>> = _starred.asStateFlow()

    private val _lastCard = MutableStateFlow(false)
    val lastCard: StateFlow<Boolean> = _lastCard.asStateFlow()

    fun open(cardId: Long) {
        viewModelScope.launch {
            writes.withLock {
                try {
                    reload(cardId)
                } catch (e: Exception) {
                    Log.e(TAG, "Could not open add to set", e)
                }
            }
        }
    }

    fun dismiss() {
        _sheet.value = null
    }

    fun dismissLastCard() {
        _lastCard.value = false
    }

    fun startCreate() = _sheet.update { it?.copy(creating = true) }

    fun cancelCreate() = _sheet.update { it?.copy(creating = false) }

    fun toggle(tagId: Long, member: Boolean) {
        val cardId = _sheet.value?.cardId ?: return
        viewModelScope.launch { writeMembership(tagId, cardId, member) }
    }

    fun create(name: String) {
        val cardId = _sheet.value?.cardId ?: return
        viewModelScope.launch {
            writes.withLock {
                try {
                    val study = StudyStore(session.openRepository())
                    val active = preferences.preferences.first().tagId
                    val id = withContext(Dispatchers.IO) {
                        val created = study.createSet(name)
                        if (created != null) {
                            val result = study.setMembership(created, cardId, true, active)
                            if (result == MembershipResult.LastCard) null else created
                        } else {
                            null
                        }
                    }
                    _sheet.update { it?.copy(creating = false) }
                    if (id != null) reload(cardId)
                } catch (e: Exception) {
                    Log.e(TAG, "Could not create a set", e)
                    _sheet.update { it?.copy(creating = false) }
                }
            }
        }
    }

    fun setStar(cardId: Long, member: Boolean) {
        viewModelScope.launch { writeMembership(STARRED_TAG_ID, cardId, member) }
    }

    fun starred(cardId: Long): Boolean = _starred.value[cardId] == true

    fun refreshStar(cardId: Long) {
        viewModelScope.launch {
            writes.withLock {
                try {
                    val study = StudyStore(session.openRepository())
                    val member = withContext(Dispatchers.IO) {
                        study.userSetsForCard(cardId).firstOrNull { it.first.id == STARRED_TAG_ID }?.second == true
                    }
                    _starred.update { it + (cardId to member) }
                } catch (e: Exception) {
                    Log.e(TAG, "Could not read starred", e)
                }
            }
        }
    }

    private suspend fun writeMembership(tagId: Long, cardId: Long, member: Boolean) {
        writes.withLock {
            val previousChecked = _sheet.value?.takeIf { it.cardId == cardId }?.checked
            val previousStar = _starred.value[cardId]
            if (previousChecked != null) {
                _sheet.update { sheet ->
                    sheet?.copy(
                        checked = if (member) sheet.checked + tagId else sheet.checked - tagId,
                    )
                }
            }
            if (tagId == STARRED_TAG_ID) _starred.update { it + (cardId to member) }
            try {
                val study = StudyStore(session.openRepository())
                val active = preferences.preferences.first().tagId
                val result = withContext(Dispatchers.IO) {
                    study.setMembership(tagId, cardId, member, active)
                }
                if (result == MembershipResult.LastCard) {
                    restore(cardId, tagId, previousChecked, previousStar)
                    _lastCard.value = true
                }
            } catch (e: Exception) {
                Log.e(TAG, "Could not update set membership", e)
                restore(cardId, tagId, previousChecked, previousStar)
            }
        }
    }

    private fun restore(cardId: Long, tagId: Long, previousChecked: Set<Long>?, previousStar: Boolean?) {
        if (previousChecked != null && _sheet.value?.cardId == cardId) {
            _sheet.update { it?.copy(checked = previousChecked) }
        }
        if (tagId == STARRED_TAG_ID) {
            _starred.update { current ->
                if (previousStar == null) current - cardId else current + (cardId to previousStar)
            }
        }
    }

    private suspend fun reload(cardId: Long) {
        val repo = session.openRepository()
        val loaded = withContext(Dispatchers.IO) {
            val study = StudyStore(repo)
            val card = repo.loadCard(cardId)
            Triple(card, study.userSetsForCard(cardId), study.builtInSetsWithCard(cardId))
        }
        val card = loaded.first
        val membership = loaded.second
        _starred.update { it + (cardId to (membership.firstOrNull { set -> set.first.id == STARRED_TAG_ID }?.second == true)) }
        _sheet.value = AddToSetUi(
            cardId = cardId,
            headword = card?.headword.orEmpty(),
            reading = card?.reading.orEmpty(),
            sets = membership.map { it.first },
            checked = membership.filter { it.second }.map { it.first.id }.toSet(),
            builtIn = loaded.third,
        )
    }

    companion object {
        private const val TAG = "CardActions"

        fun factory(
            session: DictionaryViewModel,
            preferences: AppPreferencesStore,
        ): ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val app = this[ViewModelProvider.AndroidViewModelFactory.APPLICATION_KEY] as Application
                CardActionsViewModel(app, session, preferences)
            }
        }
    }
}
