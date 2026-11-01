package com.japaneseinaflash.app.data

/**
 * Queries the 2.0 databases the way the iOS app reads them, with a different
 * search rank.
 *
 * Search binds the keyword (`MATCH ?`) and a separate exact-match term. It
 * never interpolates either: a search can arrive from the text field and, on
 * iOS, from a URL. Japanese FTS has one indexed text column, `content`
 * (headword, readings, romaji, and glosses). `card_id` and `ptag` are stored
 * but not indexed. `ptag` is 1 when the JMdict entry carries news1, ichi1,
 * spec1, spec2, or gai1. That is the only frequency or priority column on
 * the dictionary databases.
 *
 * Rank is exact headword, reading, romaji, or the first gloss, then an exact
 * gloss in a later sense, then `ptag`, then the headword's length, then
 * `card_id`. A later sense that happens to be the query (遣る for "eat") no
 * longer ties the word whose first gloss is the query (食べる). Whole-entry
 * `LENGTH(content)` is not used: a common word such as 水 has a long gloss
 * list, so sorting by that length first buried it under short compounds.
 *
 * iOS Japanese search has the same burying. `CardPeer keywordIsHeadword` and
 * `keywordIsReading` are compiled out for JFlash (both return NO), so every
 * Japanese query is
 * `cards_search_content MATCH ? ORDER BY LENGTH(content) ASC, ptag DESC, card_id ASC`.
 * Running that statement on this database puts 井戸 and 水位 ahead of 水 for
 * "water", 寝ぬ and 淫雨 ahead of 犬 for "inu", ギコ猫 ahead of 猫 for "neko",
 * and 猫 (ねこま) ahead of 猫 (ねこ) for "cat". The iOS app is unchanged.
 * Chinese Flash does rank a headword or reading column by that column's
 * length; Japanese does not take that path.
 *
 * Example sentences are the card's `should_show = 1` links, at most 10.
 * `card_sentence_link.card_id` is untyped, and Android binds every `?` as text.
 * Text does not match an untyped integer, so the id is cast.
 */
object DictionarySql {
    /**
     * Placeholders, in order: exact term, MATCH expression, limit.
     * The exact term is `''` when the query has nothing to compare
     * (the rank then starts at "not exact").
     */
    val SEARCH = """
        WITH q(term) AS (SELECT ?)
        SELECT card_id FROM (
          SELECT
            c.card_id AS card_id,
            c.headword AS headword,
            c.reading AS reading,
            c.romaji AS romaji,
            f.ptag AS ptag,
            length(c.headword) AS head_len,
            CASE WHEN instr(ifnull(f.content, ''), ' [ ') > 0
                 THEN substr(f.content, 1, instr(f.content, ' [ ') - 1)
                 ELSE ifnull(c.headword, '') END AS forms,
            replace(replace(lower(
              CASE WHEN instr(ifnull(f.content, ''), ' ] ') > 0
                   THEN substr(f.content, instr(f.content, ' ] ') + 3)
                   ELSE '' END
            ), ' / ', ' | '), '; ', ' | ') AS gloss,
            q.term AS term
          FROM cards_search_content AS f
          INNER JOIN cards c ON c.card_id = CAST(f.card_id AS INTEGER)
          CROSS JOIN q
          WHERE cards_search_content MATCH ?
        )
        ORDER BY
          CASE
            WHEN term = '' THEN 2
            WHEN lower(headword) = lower(term)
              OR instr('; ' || lower(forms) || '; ', '; ' || lower(term) || '; ') > 0
              OR instr('; ' || lower(ifnull(reading, '')) || '; ', '; ' || lower(term) || '; ') > 0
              OR instr('; ' || lower(ifnull(romaji, '')) || '; ', '; ' || lower(term) || '; ') > 0
              OR (
                CASE WHEN instr(gloss, ' | ') > 0
                     THEN substr(gloss, 1, instr(gloss, ' | ') - 1)
                     ELSE gloss END
              ) = lower(term)
              OR substr(
                CASE WHEN instr(gloss, ' | ') > 0
                     THEN substr(gloss, 1, instr(gloss, ' | ') - 1)
                     ELSE gloss END,
                1,
                length(lower(term)) + 2
              ) = lower(term) || ' ('
            THEN 0
            WHEN instr(' | ' || gloss || ' | ', ' | ' || lower(term) || ' | ') > 0
              OR instr(' | ' || gloss || ' | ', ' | ' || lower(term) || ' (') > 0
            THEN 1
            ELSE 2
          END ASC,
          ptag DESC,
          head_len ASC,
          card_id ASC
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
