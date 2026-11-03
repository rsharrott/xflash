package com.japaneseinaflash.app.data

import android.database.sqlite.SQLiteDatabase
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.nio.file.Files

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], manifest = Config.NONE)
class MembershipTest {
    @Test
    fun addToSetListsEveryUserSetByName() {
        openFixture().use { repo ->
            val study = StudyStore(repo)
            val names = study.userSetsForCard(10).map { it.first.name }
            assertEquals(listOf("apple", "My Starred Words", "Zebra"), names)
        }
    }

    @Test
    fun addingAndRemovingUpdatesMembershipAndTheCount() {
        openFixture().use { repo ->
            val study = StudyStore(repo)
            assertEquals(MembershipResult.Changed, study.setMembership(2, 10, true, activeTagId = 5))
            assertTrue(study.userSetsForCard(10).first { it.first.id == 2L }.second)
            assertEquals(1, study.tag(2)!!.count)
            assertEquals(MembershipResult.Changed, study.setMembership(0, 10, true, activeTagId = 5))
            assertTrue(study.userSetsForCard(10).first { it.first.id == 0L }.second)
            assertEquals(MembershipResult.Changed, study.setMembership(2, 10, false, activeTagId = 5))
            assertFalse(study.userSetsForCard(10).first { it.first.id == 2L }.second)
            assertEquals(0, study.tag(2)!!.count)
        }
    }

    @Test
    fun theLastCardOfTheActiveSetStays() {
        openFixture().use { repo ->
            val study = StudyStore(repo)
            study.setMembership(2, 10, true, activeTagId = 9)
            study.setMembership(2, 11, true, activeTagId = 9)
            assertEquals(MembershipResult.Changed, study.setMembership(2, 10, false, activeTagId = 2))
            assertEquals(MembershipResult.LastCard, study.setMembership(2, 11, false, activeTagId = 2))
            assertTrue(study.userSetsForCard(11).first { it.first.id == 2L }.second)
            assertEquals(1, study.tag(2)!!.count)
            assertEquals(MembershipResult.Changed, study.setMembership(2, 11, false, activeTagId = 5))
            assertFalse(study.userSetsForCard(11).first { it.first.id == 2L }.second)
        }
    }

    @Test
    fun aNewSetCanTakeTheCard() {
        openFixture().use { repo ->
            val study = StudyStore(repo)
            val id = study.createSet("Notes") ?: error("set was not created")
            assertEquals(MembershipResult.Changed, study.setMembership(id, 10, true, activeTagId = 5))
            val row = study.userSetsForCard(10).first { it.first.id == id }
            assertEquals("Notes", row.first.name)
            assertTrue(row.second)
            val names = study.userSetsForCard(10).map { it.first.name }
            assertEquals(listOf("apple", "My Starred Words", "Notes", "Zebra"), names)
        }
    }

    private fun openFixture(): DictionaryRepository {
        val installed = fixture()
        val db = SQLiteDatabase.openOrCreateDatabase(installed.userDatabase, null)
        listOf(
            DictionaryFiles.SCHEMA_CARD to installed.cardDatabase,
            DictionaryFiles.SCHEMA_FTS to installed.ftsDatabase,
            DictionaryFiles.SCHEMA_EX to installed.exampleDatabase,
        ).forEach { (schema, file) ->
            val path = file.canonicalPath
            db.execSQL("ATTACH DATABASE '$path' AS $schema")
        }
        return DictionaryRepository(db)
    }

    private fun fixture(): InstalledDictionary {
        val dir = Files.createTempDirectory("jflash-membership").toFile()
        sqlite(File(dir, DictionaryFiles.USER_DB)) {
            execSQL(
                "CREATE TABLE tags (tag_id INTEGER PRIMARY KEY, tag_name TEXT, description TEXT, " +
                    "editable INTEGER, count INTEGER, tag_name_ja TEXT)",
            )
            execSQL("CREATE TABLE card_tag_link (tag_id INTEGER, card_id INTEGER)")
            execSQL(
                "CREATE TABLE groups (group_id INTEGER PRIMARY KEY, group_name TEXT, group_name_ja TEXT, " +
                    "recommended INTEGER, tag_count INTEGER, owner_id INTEGER)",
            )
            execSQL("CREATE TABLE group_tag_link (tag_id INTEGER, group_id INTEGER)")
            execSQL("INSERT INTO groups VALUES (1, 'Top', '', 0, 0, -1)")
            execSQL("INSERT INTO tags VALUES (5, 'Zebra', '', 1, 0, '')")
            execSQL("INSERT INTO tags VALUES (0, 'My Starred Words', '', 0, 0, '')")
            execSQL("INSERT INTO tags VALUES (2, 'apple', '', 1, 0, '')")
        }
        sqlite(File(dir, DictionaryFiles.CARD_DB)) {
            execSQL("CREATE TABLE system_card_tag_link (tag_id INTEGER, card_id INTEGER)")
        }
        sqlite(File(dir, DictionaryFiles.FTS_DB)) { execSQL("CREATE TABLE unused (id INTEGER)") }
        sqlite(File(dir, DictionaryFiles.EX_DB)) { execSQL("CREATE TABLE unused (id INTEGER)") }
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
