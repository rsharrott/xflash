package com.japaneseinaflash.app.ui

import android.app.Application
import android.database.sqlite.SQLiteDatabase
import androidx.lifecycle.SavedStateHandle
import androidx.test.core.app.ApplicationProvider
import com.japaneseinaflash.app.data.AppPreferencesStore
import com.japaneseinaflash.app.data.DictionaryFiles
import com.japaneseinaflash.app.data.DictionaryRepository
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import java.io.File
import java.nio.file.Files

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class CardActionsViewModelTest {
    @Test
    fun setsStayInNameOrderAndTheLastActiveCardStays() = runBlocking {
        val app = ApplicationProvider.getApplicationContext<Application>()
        val repo = repository()
        val session = DictionaryViewModel(
            app,
            SavedStateHandle(),
            openInstalled = { repo },
            runQuery = { _, _ -> emptyList() },
        )
        idleUntil { session.state.value.phase == Phase.Ready }
        val store = AppPreferencesStore(app)
        store.update { it.copy(tagId = 2L) }
        val actions = CardActionsViewModel(app, session, store)
        actions.open(10)
        idleUntil { actions.sheet.value != null }
        assertEquals(
            listOf("apple", "My Starred Words", "Zebra"),
            actions.sheet.value!!.sets.map { it.name },
        )
        actions.toggle(2L, false)
        idleUntil { actions.lastCard.value }
        assertTrue(actions.lastCard.value)
        assertTrue(2L in actions.sheet.value!!.checked)
    }

    private fun idleUntil(ready: () -> Boolean) {
        val deadline = System.currentTimeMillis() + 5_000
        while (!ready() && System.currentTimeMillis() < deadline) {
            shadowOf(android.os.Looper.getMainLooper()).idle()
            Thread.sleep(20)
        }
    }

    private fun repository(): DictionaryRepository {
        val dir = Files.createTempDirectory("jflash-actions").toFile()
        sqlite(File(dir, DictionaryFiles.USER_DB)) {
            execSQL("CREATE TABLE version (version TEXT)")
            execSQL("INSERT INTO version VALUES ('2.0')")
            execSQL(
                "CREATE TABLE tags (tag_id INTEGER PRIMARY KEY, tag_name TEXT, description TEXT, " +
                    "editable INTEGER, count INTEGER, tag_name_ja TEXT)",
            )
            execSQL("CREATE TABLE card_tag_link (tag_id INTEGER, card_id INTEGER)")
            execSQL("INSERT INTO tags VALUES (5, 'Zebra', '', 1, 0, '')")
            execSQL("INSERT INTO tags VALUES (0, 'My Starred Words', '', 0, 0, '')")
            execSQL("INSERT INTO tags VALUES (2, 'apple', '', 1, 1, '')")
            execSQL("INSERT INTO card_tag_link VALUES (2, 10)")
        }
        sqlite(File(dir, DictionaryFiles.CARD_DB)) {
            execSQL("CREATE TABLE version (version TEXT)")
            execSQL("INSERT INTO version VALUES ('2.0')")
            execSQL(
                "CREATE TABLE cards (card_id INTEGER PRIMARY KEY, headword TEXT, reading TEXT, romaji TEXT)",
            )
            execSQL("CREATE TABLE cards_html (card_id INTEGER PRIMARY KEY, meaning TEXT)")
            execSQL("CREATE TABLE system_card_tag_link (tag_id INTEGER, card_id INTEGER)")
            execSQL("INSERT INTO cards VALUES (10, 'あ', 'あ', 'a')")
            execSQL("INSERT INTO cards_html VALUES (10, 'a')")
        }
        sqlite(File(dir, DictionaryFiles.FTS_DB)) {
            execSQL("CREATE TABLE version (version TEXT)")
            execSQL("INSERT INTO version VALUES ('2.0')")
        }
        sqlite(File(dir, DictionaryFiles.EX_DB)) {
            execSQL("CREATE TABLE version (version TEXT)")
            execSQL("INSERT INTO version VALUES ('2.0')")
            execSQL("CREATE TABLE sentences (sentence_id INTEGER PRIMARY KEY, sentence_ja TEXT, sentence_en TEXT)")
            execSQL("CREATE TABLE card_sentence_link (card_id INTEGER, sentence_id INTEGER, should_show INTEGER)")
        }
        val db = SQLiteDatabase.openOrCreateDatabase(File(dir, DictionaryFiles.USER_DB), null)
        listOf(
            DictionaryFiles.SCHEMA_CARD to DictionaryFiles.CARD_DB,
            DictionaryFiles.SCHEMA_FTS to DictionaryFiles.FTS_DB,
            DictionaryFiles.SCHEMA_EX to DictionaryFiles.EX_DB,
        ).forEach { (schema, name) ->
            db.execSQL("ATTACH DATABASE '${File(dir, name).canonicalPath}' AS $schema")
        }
        return DictionaryRepository(db)
    }

    private fun sqlite(file: File, block: SQLiteDatabase.() -> Unit) {
        val db = SQLiteDatabase.openOrCreateDatabase(file, null)
        try {
            db.block()
        } finally {
            db.close()
        }
    }
}
