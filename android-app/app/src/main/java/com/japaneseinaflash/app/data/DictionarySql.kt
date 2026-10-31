package com.japaneseinaflash.app.data

/**
 * Queries the 2.0 databases the way the iOS app does.
 *
 * Search binds the keyword (`MATCH ?`). It never interpolates it: a search can
 * arrive from the text field and, on iOS, from a URL. Rank is shortest `content`
 * first, then common-word `ptag`, then `card_id` so the order is stable.
 * Japanese FTS has a single indexed column, `content` (headword, reading, romaji,
 * and glosses). There is no `headword` or `reading` column to match on.
 *
 * Example sentences are the card's `should_show = 1` links, at most 10.
 * `card_sentence_link.card_id` is untyped, and Android binds every `?` as text.
 * Text does not match an untyped integer, so the id is cast.
 */
object DictionarySql {
    val SEARCH = """
        SELECT card_id FROM cards_search_content
        WHERE cards_search_content MATCH ?
        ORDER BY LENGTH(content) ASC, ptag DESC, card_id ASC
        LIMIT ?
    """.trimIndent()

    val CARD = """
        SELECT c.card_id, c.headword, c.reading, c.romaji, ch.meaning
        FROM cards c
        INNER JOIN cards_html ch ON c.card_id = ch.card_id
        WHERE c.card_id = CAST(? AS INTEGER)
    """.trimIndent()

    val SENTENCES = """
        SELECT s.sentence_id, s.sentence_ja, s.sentence_en
        FROM sentences s
        INNER JOIN card_sentence_link l ON s.sentence_id = l.sentence_id
        WHERE l.card_id = CAST(? AS INTEGER) AND l.should_show = 1
        LIMIT 10
    """.trimIndent()

    fun summaries(count: Int): String {
        require(count in 1..SearchQuery.MAX_LIMIT)
        val placeholders = List(count) { "?" }.joinToString(",")
        return """
            SELECT c.card_id, c.headword, c.reading, ch.meaning
            FROM cards c
            INNER JOIN cards_html ch ON c.card_id = ch.card_id
            WHERE c.card_id IN ($placeholders)
        """.trimIndent()
    }

    fun version(schema: String): String {
        require(schema == "main" || schema in DictionaryFiles.SCHEMAS) { schema }
        return "SELECT version FROM $schema.version LIMIT 1"
    }
}
