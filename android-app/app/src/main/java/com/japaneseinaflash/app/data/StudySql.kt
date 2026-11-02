package com.japaneseinaflash.app.data

import com.japaneseinaflash.app.study.LEARNED_LEVEL
import com.japaneseinaflash.app.study.LEVEL_COUNT
import com.japaneseinaflash.app.study.STARRED_TAG_ID
import com.japaneseinaflash.app.study.userOwnsMembership

internal object StudySql {
    fun tagById(): String =
        "SELECT tag_id, tag_name, IFNULL(tag_name_ja, ''), count, editable FROM tags WHERE tag_id = ? LIMIT 1"

    fun levelCounts(userOwned: Boolean): String = """
        SELECT COALESCE(u.card_level, 0) AS level, COUNT(*) AS n
        FROM ${link(userOwned)} l
        LEFT JOIN user_history u ON u.card_id = l.card_id AND u.user_id = ?
        WHERE l.tag_id = ?
        GROUP BY level
    """.trimIndent()

    fun cardAtLevel(userOwned: Boolean, avoid: Boolean): String {
        val skip = if (avoid) "AND l.card_id != ?" else ""
        return """
            SELECT l.card_id
            FROM ${link(userOwned)} l
            LEFT JOIN user_history u ON u.card_id = l.card_id AND u.user_id = ?
            WHERE l.tag_id = ? AND COALESCE(u.card_level, 0) = ? $skip
            ORDER BY RANDOM()
            LIMIT 1
        """.trimIndent()
    }

    const val PRACTICE_CARD = """
        SELECT c.card_id, c.headword, c.reading, c.romaji, ch.meaning, c.kana_only
        FROM cards c
        INNER JOIN cards_html ch ON c.card_id = ch.card_id
        WHERE c.card_id = CAST(? AS INTEGER)
    """

    const val HISTORY = """
        SELECT right_count, wrong_count, card_level
        FROM user_history
        WHERE card_id = ? AND user_id = ?
        LIMIT 1
    """

    const val RECORD = """
        INSERT OR REPLACE INTO user_history
            (card_id, timestamp, created_on, user_id, right_count, wrong_count, card_level)
        VALUES (?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, ?, ?, ?, ?)
    """

    /** Child groups, recommended first, then the English name. Matches GroupPeer.m. */
    const val GROUPS_BY_OWNER = """
        SELECT g.group_id, g.group_name, IFNULL(g.group_name_ja, ''), g.recommended, g.tag_count,
               (SELECT COUNT(*) FROM groups c WHERE c.owner_id = g.group_id) AS child_groups
        FROM groups g
        WHERE g.owner_id = ?
        ORDER BY g.recommended DESC, g.group_name ASC
    """

    const val TOP_GROUP = """
        SELECT group_id FROM groups WHERE owner_id = -1 ORDER BY group_id LIMIT 1
    """

    const val GROUP_BY_ID = """
        SELECT g.group_id, g.group_name, IFNULL(g.group_name_ja, ''), g.recommended, g.tag_count,
               (SELECT COUNT(*) FROM groups c WHERE c.owner_id = g.group_id) AS child_groups
        FROM groups g
        WHERE g.group_id = ?
        LIMIT 1
    """

    /** Full Set first, then the English name. Matches TagPeer.m. */
    const val TAGS_IN_GROUP = """
        SELECT t.tag_id, t.tag_name, IFNULL(t.tag_name_ja, ''), t.count, t.editable
        FROM tags t
        INNER JOIN group_tag_link l ON l.tag_id = t.tag_id
        WHERE l.group_id = ?
        ORDER BY CASE WHEN t.tag_name LIKE '% Full Set' THEN 0 ELSE 1 END, t.tag_name ASC
    """

    const val SEARCH_TAGS = """
        SELECT t.tag_id, t.tag_name, IFNULL(t.tag_name_ja, ''), t.count, t.editable
        FROM tags t
        WHERE (t.tag_name LIKE ? OR IFNULL(t.tag_name_ja, '') LIKE ?)
          AND t.tag_id IN (SELECT tag_id FROM group_tag_link)
        ORDER BY t.tag_name ASC
    """

    const val SEARCH_TAGS_IN_GROUP = """
        SELECT t.tag_id, t.tag_name, IFNULL(t.tag_name_ja, ''), t.count, t.editable
        FROM tags t
        INNER JOIN group_tag_link l ON l.tag_id = t.tag_id
        WHERE l.group_id = ?
          AND (t.tag_name LIKE ? OR IFNULL(t.tag_name_ja, '') LIKE ?)
        ORDER BY t.tag_name ASC
    """

    const val USER_SETS = """
        SELECT t.tag_id, t.tag_name, IFNULL(t.tag_name_ja, ''), t.count, t.editable
        FROM tags t
        WHERE t.editable = 1 OR t.tag_id = $STARRED_TAG_ID
        ORDER BY t.tag_name COLLATE NOCASE ASC
    """

    const val MEMBER_USER = """
        SELECT 1 FROM card_tag_link WHERE tag_id = ? AND card_id = ? LIMIT 1
    """

    const val BUILTIN_WITH_CARD = """
        SELECT t.tag_id, t.tag_name, IFNULL(t.tag_name_ja, '')
        FROM CARD_DB.system_card_tag_link l
        INNER JOIN tags t ON t.tag_id = l.tag_id
        WHERE l.card_id = ? AND t.editable = 0
        ORDER BY t.tag_name COLLATE NOCASE ASC
    """

    const val INSERT_TAG = "INSERT INTO tags (tag_name, description, editable, count) VALUES (?, '', 1, 0)"

    const val LINK_TAG = "INSERT INTO group_tag_link (tag_id, group_id) VALUES (?, ?)"

    const val BUMP_GROUP = "UPDATE groups SET tag_count = tag_count + 1 WHERE group_id = ?"

    const val INSERT_MEMBER = "INSERT INTO card_tag_link (card_id, tag_id) VALUES (?, ?)"

    const val DELETE_MEMBER = "DELETE FROM card_tag_link WHERE card_id = ? AND tag_id = ?"

    const val BUMP_TAG_COUNT = "UPDATE tags SET count = CASE WHEN count + ? < 0 THEN 0 ELSE count + ? END WHERE tag_id = ?"

    private fun link(userOwned: Boolean): String =
        if (userOwned) "card_tag_link" else "CARD_DB.system_card_tag_link"

    fun levelsFrom(rows: List<Pair<Int, Int>>): IntArray {
        val levels = IntArray(LEVEL_COUNT)
        rows.forEach { (level, count) ->
            if (level in 0..LEARNED_LEVEL) levels[level] = count
        }
        return levels
    }

    fun owns(tagId: Long, editable: Int): Boolean = userOwnsMembership(tagId, editable != 0)
}
