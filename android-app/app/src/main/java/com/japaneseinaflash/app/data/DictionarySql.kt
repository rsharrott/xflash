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
 * A common token (`and`, `one`, `s`) can hit thousands of rows. Building the
 * gloss inside `ORDER BY` repeats that work on every comparison, so a single
 * token is written once into [TOKEN_STAGE] and ranked from those stored
 * columns. A prefix (`co*`, `and*`, `one*`) is ordered in SQL over every hit:
 * an exact headword, reading, romaji, or main English gloss, then one that
 * starts with the stem, then `ptag`, then the short headword. An abbreviation
 * buried in a later sense does not outrank 回 for `co?`, and a field match
 * past the first few hundred rows is not dropped.
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
     * One hit, with the gloss already folded to lowercase.
     *
     * A leading `/ ` and a trailing ` /` are real separators (`此れ`, `私儀`),
     * not part of the word. ` / ` and `; ` separate senses. Placeholders:
     * exact term, MATCH expression.
     */
    private val HIT_COLUMNS = """
        SELECT card_id, ptag, head_len, term_l, head_l, forms_pad, reading_pad, romaji_pad,
          replace(replace(
            CASE WHEN trimmed LIKE '% /' THEN substr(trimmed, 1, length(trimmed) - 2) ELSE trimmed END
          , ' / ', ' | '), '; ', ' | ') AS gloss
        FROM (
          SELECT card_id, ptag, head_len, term_l, head_l, forms_pad, reading_pad, romaji_pad,
            CASE WHEN rawg LIKE '/ %' THEN substr(rawg, 3) ELSE rawg END AS trimmed
          FROM (
            SELECT
              c.card_id AS card_id,
              f.ptag AS ptag,
              length(c.headword) AS head_len,
              lower(?) AS term_l,
              lower(ifnull(c.headword, '')) AS head_l,
              '; ' || lower(CASE WHEN instr(ifnull(f.content, ''), ' [ ') > 0
                   THEN substr(f.content, 1, instr(f.content, ' [ ') - 1)
                   ELSE ifnull(c.headword, '') END) || '; ' AS forms_pad,
              '; ' || lower(ifnull(c.reading, '')) || '; ' AS reading_pad,
              '; ' || lower(ifnull(c.romaji, '')) || '; ' AS romaji_pad,
              lower(CASE WHEN instr(ifnull(f.content, ''), ' ] ') > 0
                   THEN substr(f.content, instr(f.content, ' ] ') + 3)
                   ELSE '' END) AS rawg
            FROM cards_search_content AS f
            INNER JOIN cards c ON c.card_id = CAST(f.card_id AS INTEGER)
            WHERE cards_search_content MATCH ?
          )
        )
    """.trimIndent()

    /**
     * The only rank rule. [SEARCH] and [TOKEN_RANKED] both read it, so a
     * single word and a phrase cannot drift apart.
     *
     * A leading parenthetical on the first gloss only (`(your) school`) is
     * skipped. A `)` later in the entry does not become the main gloss.
     * `rank` is 0 for an exact headword, reading, romaji, or first gloss,
     * 1 for an exact gloss in a later sense, and 2 otherwise. The gloss is
     * already lowercase, so `Life` matches `life`.
     */
    private fun rankedRows(from: String) = """
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
            CASE WHEN comp LIKE '(%' AND instr(comp, ') ') > 0
                 THEN substr(comp, instr(comp, ') ') + 2)
                 ELSE comp END AS first_l
          FROM (
            SELECT card_id, ptag, head_len, term_l, head_l, forms_pad, reading_pad, romaji_pad, gloss,
              CASE WHEN instr(gloss, ' | ') > 0
                   THEN substr(gloss, 1, instr(gloss, ' | ') - 1)
                   ELSE gloss END AS comp
            FROM (
              $from
            )
          )
        )
    """.trimIndent()

    /**
     * Ordered card ids for a phrase or an `OR`. Placeholders: exact term,
     * MATCH expression, limit.
     */
    val SEARCH = """
        SELECT card_id FROM (
          ${rankedRows(HIT_COLUMNS)}
        )
        ORDER BY rank ASC, ptag DESC, head_len ASC, card_id ASC
        LIMIT ?
    """.trimIndent()

    /**
     * Stores one row per hit of a single token, gloss included, so the rank
     * below does not rebuild that string. Placeholders: exact term, MATCH.
     */
    val TOKEN_STAGE = """
        CREATE TEMP TABLE search_token_stage AS
        $HIT_COLUMNS
    """.trimIndent()

    /** Drops the table created by [TOKEN_STAGE]. */
    const val TOKEN_STAGE_DROP = "DROP TABLE IF EXISTS search_token_stage"

    /**
     * [SEARCH]'s order, read from [TOKEN_STAGE]. Placeholder: limit.
     */
    val TOKEN_RANKED = """
        SELECT card_id FROM (
          ${rankedRows("SELECT * FROM search_token_stage")}
        )
        ORDER BY rank ASC, ptag DESC, head_len ASC, card_id ASC
        LIMIT ?
    """.trimIndent()

    /**
     * Every prefix hit. An exact field (`one` on 一つ) comes before a field
     * that only starts with the stem (`one's house`), then a common short
     * word. Placeholders: stem, MATCH (`stem*`), limit.
     */
    val PREFIX = """
        WITH q(stem) AS (SELECT lower(?))
        SELECT c.card_id
        FROM cards_search_content AS f
        INNER JOIN cards c ON c.card_id = CAST(f.card_id AS INTEGER)
        CROSS JOIN q
        WHERE cards_search_content MATCH ?
        ORDER BY
          CASE
            WHEN instr('; ' || lower(ifnull(c.headword, '')) || '; ', '; ' || q.stem || '; ') > 0
              OR instr('; ' || lower(ifnull(c.reading, '')) || '; ', '; ' || q.stem || '; ') > 0
              OR instr('; ' || lower(ifnull(c.romaji, '')) || '; ', '; ' || q.stem || '; ') > 0
              OR instr('; ' || lower(ifnull(c.headword_en, '')) || '; ', '; ' || q.stem || '; ') > 0
            THEN 0
            WHEN '; ' || lower(ifnull(c.headword, '')) LIKE '%; ' || q.stem || '%'
              OR '; ' || lower(ifnull(c.reading, '')) LIKE '%; ' || q.stem || '%'
              OR '; ' || lower(ifnull(c.romaji, '')) LIKE '%; ' || q.stem || '%'
              OR '; ' || lower(ifnull(c.headword_en, '')) LIKE '%; ' || q.stem || '%'
            THEN 1
            ELSE 2
          END,
          f.ptag DESC, length(c.headword) ASC, c.card_id ASC
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
