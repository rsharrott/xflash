package com.japaneseinaflash.app.data

import com.japaneseinaflash.app.study.LEARNED_LEVEL
import com.japaneseinaflash.app.study.LEVEL_COUNT
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
            WHERE l.tag_id = ? AND COALESCE(u.card_level, 0) = CAST(? AS INTEGER) $skip
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
