package com.japaneseinaflash.app.data

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.japaneseinaflash.app.study.AppPreferences
import com.japaneseinaflash.app.study.DarkMode
import com.japaneseinaflash.app.study.Difficulty
import com.japaneseinaflash.app.study.KanaHeadword
import com.japaneseinaflash.app.study.ReadingMode
import com.japaneseinaflash.app.study.StudyLanguage
import com.japaneseinaflash.app.study.StudyTheme
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map

private val Context.settingsStore by preferencesDataStore(name = "jflash_settings")

/** Keys match the iOS defaults where those exist. Dark mode is Android-only. */
class AppPreferencesStore(context: Context) {
    private val store = context.applicationContext.settingsStore

    val preferences: Flow<AppPreferences> = store.data
        .catch { emit(emptyPreferences()) }
        .map { it.toAppPreferences() }

    suspend fun update(transform: (AppPreferences) -> AppPreferences) {
        store.edit { prefs ->
            val next = transform(prefs.toAppPreferences())
            prefs[Keys.THEME] = next.theme.key
            prefs[Keys.DARK] = next.darkMode.key
            prefs[Keys.READING] = next.reading.key
            prefs[Keys.HEADWORD] = next.language.key
            prefs[Keys.KANA] = next.kanaHeadword.key
            prefs[Keys.DIFFICULTY] = next.difficulty.key
            prefs[Keys.CUSTOM_MAX] = next.customMax
            prefs[Keys.CUSTOM_FREQUENCY] = next.customFrequency
            prefs[Keys.HIDE] = next.hideLearned
            prefs[Keys.TAG] = next.tagId
            prefs[Keys.USER] = next.userId
            prefs[Keys.MAX] = next.pool().maxCards
            prefs[Keys.FREQUENCY] = next.pool().frequency
        }
    }

    private object Keys {
        val THEME = stringPreferencesKey("theme")
        val DARK = stringPreferencesKey("dark_mode")
        val READING = stringPreferencesKey("reading")
        val HEADWORD = stringPreferencesKey("headword")
        val KANA = stringPreferencesKey("kana_only")
        val DIFFICULTY = intPreferencesKey("app_difficulty")
        val MAX = intPreferencesKey("maxStudying")
        val FREQUENCY = intPreferencesKey("frequency_multiplier")
        val CUSTOM_MAX = intPreferencesKey("custom_maxStudying")
        val CUSTOM_FREQUENCY = intPreferencesKey("custom_frequency_multiplier")
        val HIDE = booleanPreferencesKey("app_hide_buried_cards")
        val TAG = longPreferencesKey("tag_id")
        val USER = longPreferencesKey("user_id")
    }
}

internal fun Preferences.toAppPreferences(): AppPreferences = AppPreferences(
    theme = StudyTheme.fromKey(this[stringPreferencesKey("theme")]),
    darkMode = DarkMode.fromKey(this[stringPreferencesKey("dark_mode")]),
    reading = ReadingMode.fromKey(this[stringPreferencesKey("reading")]),
    language = StudyLanguage.fromKey(this[stringPreferencesKey("headword")]),
    kanaHeadword = KanaHeadword.fromKey(this[stringPreferencesKey("kana_only")]),
    difficulty = Difficulty.fromKey(this[intPreferencesKey("app_difficulty")] ?: Difficulty.MEDIUM.key),
    customMax = this[intPreferencesKey("custom_maxStudying")] ?: AppPreferences.MEDIUM_POOL,
    customFrequency = this[intPreferencesKey("custom_frequency_multiplier")] ?: AppPreferences.MEDIUM_FREQUENCY,
    hideLearned = this[booleanPreferencesKey("app_hide_buried_cards")] ?: false,
    tagId = this[longPreferencesKey("tag_id")] ?: AppPreferences.DEFAULT_TAG_ID,
    userId = this[longPreferencesKey("user_id")] ?: AppPreferences.DEFAULT_USER_ID,
)
