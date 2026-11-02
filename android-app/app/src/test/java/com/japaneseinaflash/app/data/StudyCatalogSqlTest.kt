package com.japaneseinaflash.app.data

import com.japaneseinaflash.app.study.opensAsSearch
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class StudyCatalogSqlTest {
    @Test
    fun topLevelGroupsFollowTheIosOrderAndOnlyCommonWordsIsSearched() {
        val user = listedSources().first { it.assetName == DictionaryFiles.USER_DB }.file
        val groups = sqlite3(
            user,
            "SELECT group_name FROM groups WHERE owner_id = 0 ORDER BY recommended DESC, group_name ASC;",
        ).trim().lines()
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
            groups,
        )
        assertTrue(opensAsSearch("Common Words"))
        assertFalse(opensAsSearch("Nouns"))
        val beginner = sqlite3(
            user,
            """
            SELECT t.tag_name FROM tags t, group_tag_link l
            WHERE t.tag_id = l.tag_id AND l.group_id = 24
            ORDER BY CASE WHEN t.tag_name LIKE '% Full Set' THEN 0 ELSE 1 END, t.tag_name ASC;
            """.trimIndent(),
        ).trim().lines()
        assertTrue(beginner.first().endsWith("Full Set"))
        assertEquals("Beginner 1 (≈N5) 01", beginner[1])
        val mine = sqlite3(
            user,
            "SELECT tag_name FROM tags WHERE editable = 1 OR tag_id = 0 ORDER BY tag_name COLLATE NOCASE ASC;",
        ).trim().lines()
        assertEquals("Long Weekend Favorites", mine.first())
    }
}
