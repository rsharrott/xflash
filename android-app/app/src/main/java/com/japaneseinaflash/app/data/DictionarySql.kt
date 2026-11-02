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
 * A common token (`and`, `one`, `s`) and a prefix (`co*`, `and*`, `こ*`) can
 * hit tens of thousands of rows. Ranking does not rebuild the gloss on every
 * sort comparison. A single token is copied once into [TOKEN_STAGE] and ranked
 * from that copy; the remaining hits stay in ptag then headword-length order.
 * A prefix is ordered by a headword, reading, romaji, or main English gloss
 * that starts with the stem, then the same common-word order, so an abbreviation
 * buried in a later sense does not outrank 回 for `co?`.
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
     * A leading parenthetical on the first gloss only (`(your) school`) is
     * skipped. A `)` later in the entry (`(one's) education` on 教養) is not,
     * so that later sense does not become the main gloss. `rank` is 0 for an
     * exact headword, reading, romaji, or first gloss, 1 for an exact gloss in
     * a later sense, and 2 otherwise. Placeholders: exact term (via `q`), MATCH.
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
            CASE WHEN comp LIKE '(%' AND instr(comp, ') ') > 0
                 THEN substr(comp, instr(comp, ') ') + 2)
                 ELSE comp END AS first_l
          FROM (
            SELECT card_id, ptag, head_len, term_l, head_l, forms_pad, reading_pad, romaji_pad, gloss,
              CASE WHEN instr(gloss, ' | ') > 0
                   THEN substr(gloss, 1, instr(gloss, ' | ') - 1)
                   ELSE gloss END AS comp
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
     * One row per hit for a single token, copied so the rank below reads each
     * string once. Placeholders: exact term, MATCH expression (the same token).
     */
    val TOKEN_STAGE = """
        CREATE TEMP TABLE search_token_stage AS
        SELECT
          c.card_id AS cid,
          f.ptag AS ptag,
          length(c.headword) AS hl,
          lower(?) AS term_l,
          lower(ifnull(c.headword, '')) AS head_l,
          lower(ifnull(c.reading, '')) AS reading_l,
          lower(ifnull(c.romaji, '')) AS romaji_l,
          lower(CASE WHEN instr(f.content, ' [ ') > 0
               THEN substr(f.content, 1, instr(f.content, ' [ ') - 1)
               ELSE ifnull(c.headword, '') END) AS forms_l,
          CASE WHEN instr(f.content, ' ] ') > 0
               THEN lower(substr(f.content, instr(f.content, ' ] ') + 3, 180))
               ELSE '' END AS snip,
          f.content AS content
        FROM cards_search_content AS f
        INNER JOIN cards c ON c.card_id = CAST(f.card_id AS INTEGER)
        WHERE cards_search_content MATCH ?
    """.trimIndent()

    /** Drops the table created by [TOKEN_STAGE]. */
    const val TOKEN_STAGE_DROP = "DROP TABLE IF EXISTS search_token_stage"

    /**
     * Rank-0 and rank-1 rows from [TOKEN_STAGE], already ordered.
     * The leading parenthetical is stripped only inside the first gloss
     * component. Placeholder: limit.
     */
    val TOKEN_RANKED = """
        SELECT cid, rank, ptag, hl FROM (
          SELECT cid, ptag, hl,
            CASE
              WHEN head_l = term_l
                OR instr('; ' || reading_l || '; ', '; ' || term_l || '; ') > 0
                OR instr('; ' || romaji_l || '; ', '; ' || term_l || '; ') > 0
                OR instr('; ' || forms_l || '; ', '; ' || term_l || '; ') > 0
                OR (
                  substr(snip || ' /', 1, length(term_l)) = term_l
                  AND substr(snip || ' /', length(term_l) + 1, 2) IN (' /', '; ', ' (')
                )
                OR (
                  substr(snip, 1, 1) = '('
                  AND instr(snip, ') ' || term_l) > 0
                  AND (instr(snip, ' / ') = 0 OR instr(snip, ') ' || term_l) < instr(snip, ' / '))
                  AND (instr(snip, '; ') = 0 OR instr(snip, ') ' || term_l) < instr(snip, '; '))
                  AND substr(snip || ' /', instr(snip, ') ' || term_l) + length(term_l) + 2, 2)
                      IN (' /', '; ', ' (')
                )
              THEN 0
              WHEN instr(content, ' / ' || term_l || ' / ') > 0
                OR instr(content, ' / ' || term_l || '; ') > 0
                OR instr(content, '; ' || term_l || ' / ') > 0
                OR instr(content, '; ' || term_l || '; ') > 0
                OR instr(content, ' / ' || term_l || ' (') > 0
                OR instr(content, '; ' || term_l || ' (') > 0
                OR content LIKE '% / ' || term_l
                OR content LIKE '%; ' || term_l
                OR instr(content, ' / ' || upper(term_l) || ' / ') > 0
                OR instr(content, ' / ' || upper(term_l) || '; ') > 0
                OR instr(content, '; ' || upper(term_l) || '; ') > 0
                OR content LIKE '% / ' || upper(term_l)
                OR content LIKE '%; ' || upper(term_l)
              THEN 1
              ELSE 2
            END AS rank
          FROM search_token_stage
        )
        WHERE rank < 2
        ORDER BY rank ASC, ptag DESC, hl ASC, cid ASC
        LIMIT ?
    """.trimIndent()

    /**
     * Hits ordered by common word, then short headword, with the fields a
     * prefix re-sort needs. Placeholders: MATCH, limit.
     */
    val PREFIX_WINDOW = """
        SELECT c.card_id, f.ptag, length(c.headword) AS head_len,
          ifnull(c.headword, ''), ifnull(c.reading, ''), ifnull(c.romaji, ''), ifnull(c.headword_en, '')
        FROM cards_search_content AS f
        INNER JOIN cards c ON c.card_id = CAST(f.card_id AS INTEGER)
        WHERE cards_search_content MATCH ?
        ORDER BY f.ptag DESC, head_len ASC, c.card_id ASC
        LIMIT ?
    """.trimIndent()

    /**
     * Fillers with no gloss work. They sort by common word, then short
     * headword. Placeholders: MATCH, limit.
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
