package com.japaneseinaflash.app.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.japaneseinaflash.app.data.AppPreferencesStore
import com.japaneseinaflash.app.study.AppPreferences
import com.japaneseinaflash.app.study.DarkMode
import com.japaneseinaflash.app.study.Difficulty
import com.japaneseinaflash.app.study.KanaHeadword
import com.japaneseinaflash.app.study.ReadingMode
import com.japaneseinaflash.app.study.StudyLanguage
import com.japaneseinaflash.app.study.StudyTheme
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class PreferencesViewModel(app: Application) : AndroidViewModel(app) {
    val store = AppPreferencesStore(app)
    val preferences: StateFlow<AppPreferences> = store.preferences.stateIn(
        viewModelScope,
        SharingStarted.WhileSubscribed(5_000),
        AppPreferences(),
    )

    fun setTheme(theme: StudyTheme) = edit { it.copy(theme = theme) }

    fun setDarkMode(mode: DarkMode) = edit { it.copy(darkMode = mode) }

    fun setReading(mode: ReadingMode) = edit { it.copy(reading = mode) }

    fun setLanguage(language: StudyLanguage) = edit { it.copy(language = language) }

    fun setKana(kana: KanaHeadword) = edit { it.copy(kanaHeadword = kana) }

    fun setDifficulty(difficulty: Difficulty) = edit { current ->
        val next = current.copy(difficulty = difficulty)
        if (difficulty == Difficulty.CUSTOM) next else next
    }

    fun setCustom(maxCards: Int, frequency: Int) = edit {
        it.copy(
            difficulty = Difficulty.CUSTOM,
            customMax = maxCards.coerceIn(AppPreferences.MIN_POOL, AppPreferences.MAX_POOL),
            customFrequency = frequency.coerceIn(AppPreferences.MIN_FREQUENCY, AppPreferences.MAX_FREQUENCY),
        )
    }

    fun setHideLearned(hide: Boolean) = edit { it.copy(hideLearned = hide) }

    fun setActiveTag(id: Long) = edit { it.copy(tagId = id) }

    private fun edit(transform: (AppPreferences) -> AppPreferences) {
        viewModelScope.launch { store.update(transform) }
    }

    companion object {
        fun practiceFactory(session: DictionaryViewModel, store: AppPreferencesStore): ViewModelProvider.Factory =
            viewModelFactory {
                initializer {
                    val app = this[ViewModelProvider.AndroidViewModelFactory.APPLICATION_KEY] as Application
                    PracticeViewModel(app, session, store)
                }
            }
    }
}
