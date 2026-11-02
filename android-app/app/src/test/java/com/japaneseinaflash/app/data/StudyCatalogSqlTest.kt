package com.japaneseinaflash.app.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class StudyCatalogSqlTest {
    @Test
    fun realGroupsAndBeginnerSetsFollowTheIosOrder() {
        val user = listedSources().first { it.assetName == DictionaryFiles.USER_DB }.file
        val groups = sqlite3(
            user,
            "SELECT group_name FROM groups WHERE owner_id = 0 ORDER BY recommended DESC, group_name ASC;",
        ).trim().lines()
        assertEquals("Recommended", groups[0])
        assertEquals("Survival Japanese", groups[1])
        assertEquals("Vocabulary Levels", groups[2])
        assertTrue(groups.indexOf("Common Phrases") < groups.indexOf("Common Words"))
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
        assertEquals(
            "233",
            sqlite3(user, "SELECT COUNT(*) FROM group_tag_link WHERE group_id = 11;").trim(),
        )
        val mine = sqlite3(
            user,
            "SELECT tag_name FROM tags WHERE editable = 1 OR tag_id = 0 ORDER BY tag_name COLLATE NOCASE ASC;",
        )
        assertTrue(mine.contains("My Starred Words"))
        assertTrue(mine.contains("Long Weekend Favorites"))
    }
}
