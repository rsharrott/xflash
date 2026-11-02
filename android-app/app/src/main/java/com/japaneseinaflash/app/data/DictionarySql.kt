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
 * A prefix such as `co*` or `こ*` can hit tens of thousands of rows. The gloss
 * text is built only for the exact token (`co`, `こ`), which is a small set.
 * The other hits are ordered as non-exact matches (common word, then short
 * headword) and merged in [SearchRank]. Doing the string work once per exact
 * row, instead of again on every sort comparison, is what keeps that prefix
 * close to the old length-only query.
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
     * One row per hit, with `gloss` and `rank` each computed from stored
     * columns rather than rebuilt inside `ORDER BY`.
     *
     * A leading parenthetical (`(one's) mother`) is skipped before the first
     * gloss is read. `rank` is 0 for an exact headword, reading, romaji, or
     * first gloss, 1 for an exact gloss in a later sense, and 2 otherwise.
     * Placeholders: exact term (via `q`), MATCH expression.
     */
    private val SCORED_ROWS = """
        SELECT card_id, ptag, head_len,
          CASE
            WHEN term_l = '' THEN 2
            WHEN head_l = term_l
              OR instr(forms_pad, '; ' || term_l || '; ') > 0
              OR instr(reading_pad, '; ' || term_l || '; ') > 0
              OR instr(romaji_pad, '; ' || term_l || '; ') > 0
              OR first_l = term_l
              OR substr(first_l, 1, length(term_l) + 2) = term_l || ' ('
            THEN 0
            WHEN instr(' | ' || gloss || ' | ', ' | ' || term_l || ' | ') > 0
              OR instr(' | ' || gloss || ' | ', ' | ' || term_l || ' (') > 0
            THEN 1
            ELSE 2
          END AS rank
        FROM (
          SELECT card_id, ptag, head_len, term_l, head_l, forms_pad, reading_pad, romaji_pad, gloss,
            CASE WHEN instr(body, ' | ') > 0
                 THEN substr(body, 1, instr(body, ' | ') - 1)
                 ELSE body END AS first_l
          FROM (
            SELECT card_id, ptag, head_len, term_l, head_l, forms_pad, reading_pad, romaji_pad, gloss,
              CASE WHEN gloss LIKE '(%' AND instr(gloss, ') ') > 0
                   THEN substr(gloss, instr(gloss, ') ') + 2)
                   ELSE gloss END AS body
            FROM (
              SELECT
                c.card_id AS card_id,
                f.ptag AS ptag,
                length(c.headword) AS head_len,
                lower(q.raw) AS term_l,
                lower(ifnull(c.headword, '')) AS head_l,
                '; ' || lower(CASE WHEN instr(ifnull(f.content, ''), ' [ ') > 0
                     THEN substr(f.content, 1, instr(f.content, ' [ ') - 1)
                     ELSE ifnull(c.headword, '') END) || '; ' AS forms_pad,
                '; ' || lower(ifnull(c.reading, '')) || '; ' AS reading_pad,
                '; ' || lower(ifnull(c.romaji, '')) || '; ' AS romaji_pad,
                replace(replace(lower(
                  CASE WHEN instr(ifnull(f.content, ''), ' ] ') > 0
                       THEN substr(f.content, instr(f.content, ' ] ') + 3)
                       ELSE '' END
                ), ' / ', ' | '), '; ', ' | ') AS gloss
              FROM cards_search_content AS f
              INNER JOIN cards c ON c.card_id = CAST(f.card_id AS INTEGER)
              CROSS JOIN q
              WHERE cards_search_content MATCH ?
            )
          )
        )
    """.trimIndent()

    /**
     * Ordered card ids. Placeholders: exact term, MATCH expression, limit.
     */
    val SEARCH = """
        WITH q(raw) AS (SELECT ?)
        SELECT card_id FROM (
          $SCORED_ROWS
        )
        ORDER BY rank ASC, ptag DESC, head_len ASC, card_id ASC
        LIMIT ?
    """.trimIndent()

    /**
     * [SEARCH] plus the precomputed rank, for the exact token of a prefix.
     * Placeholders: exact term, MATCH expression, limit.
     */
    val SCORED = """
        WITH q(raw) AS (SELECT ?)
        SELECT card_id, rank, ptag, head_len FROM (
          $SCORED_ROWS
        )
        ORDER BY rank ASC, ptag DESC, head_len ASC, card_id ASC
        LIMIT ?
    """.trimIndent()

    /**
     * Prefix fillers with no gloss work. They are non-exact matches, so they
     * sort by common word, then short headword. Placeholders: MATCH, limit.
     */
    val PREFIX_HITS = """
        SELECT c.card_id, f.ptag, length(c.headword) AS head_len
        FROM cards_search_content AS f
        INNER JOIN cards c ON c.card_id = CAST(f.card_id AS INTEGER)
        WHERE cards_search_content MATCH ?
        ORDER BY f.ptag DESC, head_len ASC, c.card_id ASC
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
