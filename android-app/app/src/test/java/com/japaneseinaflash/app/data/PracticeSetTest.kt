package com.japaneseinaflash.app.data

import android.database.sqlite.SQLiteDatabase
import com.japaneseinaflash.app.study.AppPreferences
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.nio.file.Files

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class PracticeSetTest {
    @Test
    fun theNextCardComesFromTheChosenSet() {
        DictionaryRepository.open(fixture()).use { repo ->
            val study = StudyStore(repo)
            val basics = study.tag(1) ?: error("missing tag")
            val food = study.tag(2) ?: error("missing food")
            val fromBasics = study.nextPracticeCard(basics, AppPreferences.DEFAULT_USER_ID, 30, 2, false, 0.0, null)
                ?: error("no card for basics")
            val fromFood = study.nextPracticeCard(food, AppPreferences.DEFAULT_USER_ID, 30, 2, false, 0.0, null)
            assertEquals(10L, fromBasics!!.card.detail.id)
            assertEquals(20L, fromFood!!.card.detail.id)
        }
    }

    @Test
    fun hidingLearnedShowsALearnedCardAndSaysTheSetIsLearned() {
        DictionaryRepository.open(fixture()).use { repo ->
            val study = StudyStore(repo)
            val learned = study.nextPracticeCard(
                study.tag(3)!!,
                AppPreferences.DEFAULT_USER_ID,
                30,
                2,
                hideLearned = true,
                random = 0.0,
                avoid = null,
            )
            assertTrue(learned!!.allLearned)
            assertEquals(30L, learned.card.detail.id)
            val stillStudying = study.nextPracticeCard(
                study.tag(1)!!,
                AppPreferences.DEFAULT_USER_ID,
                30,
                2,
                hideLearned = true,
                random = 0.0,
                avoid = null,
            )
            assertEquals(false, stillStudying!!.allLearned)
            assertEquals(10L, stillStudying.card.detail.id)
        }
    }

    private fun fixture(): InstalledDictionary {
        val dir = Files.createTempDirectory("jflash-practice").toFile()
        sqlite(File(dir, DictionaryFiles.USER_DB)) {
            execSQL(
                "CREATE TABLE tags (tag_id INTEGER PRIMARY KEY, tag_name TEXT, description TEXT, " +
                    "editable INTEGER, count INTEGER, tag_name_ja TEXT)",
            )
            execSQL("CREATE TABLE card_tag_link (tag_id INTEGER, card_id INTEGER)")
            execSQL(
                "CREATE TABLE user_history (card_id INTEGER, timestamp TEXT, user_id INTEGER, " +
                    "right_count INTEGER, wrong_count INTEGER, created_on TEXT, card_level INTEGER)",
            )
            execSQL("INSERT INTO tags VALUES (1, 'Basics', '', 1, 1, '')")
            execSQL("INSERT INTO tags VALUES (2, 'Food', '', 1, 1, '')")
            execSQL("INSERT INTO tags VALUES (3, 'Done', '', 1, 1, '')")
            execSQL("INSERT INTO card_tag_link VALUES (1, 10)")
            execSQL("INSERT INTO card_tag_link VALUES (2, 20)")
            execSQL("INSERT INTO card_tag_link VALUES (3, 30)")
            execSQL("INSERT INTO user_history VALUES (30, '', 1, 4, 0, '', 5)")
        }
        sqlite(File(dir, DictionaryFiles.CARD_DB)) {
            execSQL(
                "CREATE TABLE cards (card_id INTEGER PRIMARY KEY, headword TEXT, reading TEXT, romaji TEXT, kana_only INTEGER)",
            )
            execSQL("CREATE TABLE cards_html (card_id INTEGER PRIMARY KEY, meaning TEXT)")
            execSQL("INSERT INTO cards VALUES (10, 'あ', 'あ', 'a', 1)")
            execSQL("INSERT INTO cards VALUES (20, 'お茶', 'おちゃ', 'ocha', 0)")
            execSQL("INSERT INTO cards VALUES (30, '猫', 'ねこ', 'neko', 0)")
            execSQL("INSERT INTO cards_html VALUES (10, 'a')")
            execSQL("INSERT INTO cards_html VALUES (20, 'tea')")
            execSQL("INSERT INTO cards_html VALUES (30, 'cat')")
        }
        sqlite(File(dir, DictionaryFiles.FTS_DB)) { execSQL("CREATE TABLE unused (id INTEGER)") }
        sqlite(File(dir, DictionaryFiles.EX_DB)) {
            execSQL("CREATE TABLE sentences (sentence_id INTEGER PRIMARY KEY, sentence_ja TEXT, sentence_en TEXT)")
            execSQL("CREATE TABLE card_sentence_link (card_id, sentence_id INTEGER, should_show INTEGER)")
        }
        return InstalledDictionary(
            File(dir, DictionaryFiles.USER_DB),
            File(dir, DictionaryFiles.CARD_DB),
            File(dir, DictionaryFiles.FTS_DB),
            File(dir, DictionaryFiles.EX_DB),
        )
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
