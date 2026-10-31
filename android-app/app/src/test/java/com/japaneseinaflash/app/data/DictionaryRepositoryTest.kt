package com.japaneseinaflash.app.data

import android.database.SQLException
import android.database.sqlite.SQLiteDatabase
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.nio.file.Files

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class DictionaryRepositoryTest {
    @Test
    fun searchRanksByLengthThenCommonAndLoadsShownSentences() {
        val installed = fixture()
        DictionaryRepository.open(installed).use { repo ->
            assertEquals("1.1", repo.databaseVersion("main"))
            assertEquals("2.0", repo.databaseVersion(DictionaryFiles.SCHEMA_CARD))
            assertEquals("2.0", repo.databaseVersion(DictionaryFiles.SCHEMA_FTS))
            assertEquals("2.0", repo.databaseVersion(DictionaryFiles.SCHEMA_EX))

            assertEquals(listOf(12L, 11L, 10L), repo.search("zzz").map { it.id })
            assertEquals("alpha", repo.search("zzz").first().meaning)

            val cat = repo.search("nek?")
            assertEquals(listOf(1L), cat.map { it.id })
            assertEquals("猫", cat.single().headword)
            assertEquals("ねこ", cat.single().reading)
            assertEquals("cat", cat.single().meaning)

            val detail = repo.loadCard(1)
            assertEquals("neko", detail!!.romaji)
            assertEquals(listOf("cat", "geisha"), detail.senses.map { it.text })
            assertEquals(10, detail.sentences.size)
            assertFalse(detail.sentences.any { it.id == 99L })
            assertTrue(detail.sentences.all { it.id in 1L..11L })

            assertTrue(repo.search("'; DROP TABLE cards; --").isEmpty())
            assertEquals("猫", repo.loadCard(1)!!.headword)
            assertNull(repo.loadCard(404))
            assertTrue(repo.search("AND").isEmpty())
        }
    }

    @Test
    fun cardDatabaseIsAttachedReadOnlyAndTheUserDatabaseIsWritable() {
        val installed = fixture()
        val db = openDictionary(installed)
        try {
            db.execSQL("CREATE TABLE probe (id INTEGER)")
            db.execSQL("INSERT INTO probe (id) VALUES (1)")
            val schemas = mutableListOf<String>()
            db.rawQuery("PRAGMA database_list", null).use { cursor ->
                while (cursor.moveToNext()) schemas.add(cursor.getString(1))
            }
            assertTrue(schemas.containsAll(DictionaryFiles.SCHEMAS))
            assertThrows(SQLException::class.java) {
                db.execSQL("INSERT INTO cards (card_id, headword) VALUES (99, 'nope')")
            }
        } finally {
            db.close()
        }
    }

    private fun fixture(): InstalledDictionary {
        val dir = Files.createTempDirectory("jflash-repo").toFile()
        sqlite(File(dir, DictionaryFiles.USER_DB)) {
            execSQL("CREATE TABLE version (plugin_key TEXT PRIMARY KEY, version TEXT, plugin_name TEXT)")
            execSQL("INSERT INTO version VALUES ('USER_DB', '1.1', 'Core Database')")
        }
        sqlite(File(dir, DictionaryFiles.CARD_DB)) {
            execSQL(
                "CREATE TABLE cards (card_id INTEGER PRIMARY KEY, card_type TEXT, headword TEXT, " +
                    "headword_en TEXT, reading TEXT, romaji TEXT, kana_only INTEGER)",
            )
            execSQL("CREATE TABLE cards_html (card_id INTEGER PRIMARY KEY, meaning TEXT)")
            execSQL("CREATE TABLE version (plugin_key TEXT PRIMARY KEY, version TEXT, plugin_name TEXT)")
            execSQL("INSERT INTO version VALUES ('CARD_DB', '2.0', 'Cards')")
            insertCard(1, "猫", "ねこ", "neko", "<ol><li>cat<dfn>noun</dfn></li><li>geisha<dfn>noun</dfn></li></ol>")
            insertCard(10, "zzza", "zzza", "zzza", "plain")
            insertCard(11, "zzzb", "zzzb", "zzzb", "plain")
            insertCard(12, "zzz", "zzz", "zzz", "<ol><li>alpha<dfn>noun</dfn></li></ol>")
        }
        sqlite(File(dir, DictionaryFiles.FTS_DB)) {
            execSQL(
                "CREATE VIRTUAL TABLE cards_search_content USING fts4(" +
                    "card_id, content, ptag INTEGER NOT NULL DEFAULT 0, " +
                    "notindexed=card_id, notindexed=ptag, matchinfo=fts3)",
            )
            execSQL("CREATE TABLE version (plugin_key TEXT PRIMARY KEY, version TEXT, plugin_name TEXT)")
            execSQL("INSERT INTO version VALUES ('FTS_DB', '2.0', 'Search')")
            insertFts(1, "猫 [ ねこ / neko ] cat", 1)
            insertFts(10, "zzz aa", 0)
            insertFts(11, "zzz bb", 1)
            insertFts(12, "zzz", 0)
        }
        sqlite(File(dir, DictionaryFiles.EX_DB)) {
            execSQL(
                "CREATE TABLE sentences (sentence_id INTEGER PRIMARY KEY, sentence_ja TEXT, " +
                    "sentence_en TEXT, checked BOOL)",
            )
            execSQL(
                "CREATE TABLE card_sentence_link (card_id NOT NULL, sentence_id INTEGER NOT NULL, " +
                    "should_show INTEGER, sense_number INTEGER)",
            )
            execSQL("CREATE TABLE version (plugin_key TEXT PRIMARY KEY, version TEXT, plugin_name TEXT)")
            execSQL("INSERT INTO version VALUES ('EX_DB', '2.0', 'Examples')")
            for (id in 1..11) {
                execSQL("INSERT INTO sentences VALUES ($id, '文$id', 'sentence $id', 1)")
                execSQL("INSERT INTO card_sentence_link VALUES (1, $id, 1, 1)")
            }
            execSQL("INSERT INTO sentences VALUES (99, '隠れた文', 'hidden', 1)")
            execSQL("INSERT INTO card_sentence_link VALUES (1, 99, 0, 1)")
        }
        return InstalledDictionary(
            userDatabase = File(dir, DictionaryFiles.USER_DB),
            cardDatabase = File(dir, DictionaryFiles.CARD_DB),
            ftsDatabase = File(dir, DictionaryFiles.FTS_DB),
            exampleDatabase = File(dir, DictionaryFiles.EX_DB),
        )
    }

    private fun SQLiteDatabase.insertCard(id: Int, headword: String, reading: String, romaji: String, meaning: String) {
        execSQL(
            "INSERT INTO cards VALUES (?, '3', ?, '', ?, ?, 0)",
            arrayOf<Any>(id, headword, reading, romaji),
        )
        execSQL("INSERT INTO cards_html VALUES (?, ?)", arrayOf<Any>(id, meaning))
    }

    private fun SQLiteDatabase.insertFts(id: Int, content: String, ptag: Int) {
        execSQL(
            "INSERT INTO cards_search_content (card_id, content, ptag) VALUES (?, ?, ?)",
            arrayOf<Any>(id, content, ptag),
        )
    }

    private fun sqlite(file: File, block: SQLiteDatabase.() -> Unit) {
        if (file.exists()) file.delete()
        val db = SQLiteDatabase.openOrCreateDatabase(file, null)
        try {
            db.block()
        } finally {
            db.close()
        }
    }
}
