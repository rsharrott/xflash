package com.japaneseinaflash.app.data

import android.database.sqlite.SQLiteDatabase
import com.japaneseinaflash.app.study.opensAsSearch
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class StudyCatalogSqlTest {
    @Test
    fun topLevelGroupsFollowTheIosOrderAndOnlyCommonWordsIsSearched() {
        val user = listedSources().first { it.assetName == DictionaryFiles.USER_DB }.file
        val db = SQLiteDatabase.openDatabase(user.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
        db.use {
            val top = it.rawQuery(StudySql.TOP_GROUP, null).use { cursor ->
                check(cursor.moveToFirst())
                cursor.getLong(0)
            }
            assertEquals(
                listOf(
                    "Recommended",
                    "Survival Japanese",
                    "Vocabulary Levels",
                    "Common Phrases",
                    "Common Words",
                    "Core 1000",
                    "Expressions",
                    "Foreign Loan Words",
                    "Japanese Dialects",
                    "Parts of Speech",
                    "Specialist Terminology",
                ),
                names(it, StudySql.GROUPS_BY_OWNER, arrayOf(top.toString())),
            )
            assertTrue(opensAsSearch("Common Words"))
            assertFalse(opensAsSearch("Nouns"))
            val beginner = names(it, StudySql.TAGS_IN_GROUP, arrayOf("24"))
            assertTrue(beginner.first().endsWith("Full Set"))
            assertEquals("Beginner 1 (≈N5) 01", beginner[1])
            val mine = names(it, StudySql.USER_SETS, emptyArray())
            assertEquals("Long Weekend Favorites", mine.first())
        }
    }

    private fun names(db: SQLiteDatabase, sql: String, args: Array<String>): List<String> {
        val names = mutableListOf<String>()
        db.rawQuery(sql, args).use { cursor ->
            while (cursor.moveToNext()) names.add(cursor.getString(1))
        }
        return names
    }
}
