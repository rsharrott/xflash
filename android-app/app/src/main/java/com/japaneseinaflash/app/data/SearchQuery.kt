package com.japaneseinaflash.app.data

import java.text.Normalizer

data class PreparedSearch(
    val sql: String,
    val matchArgument: String,
    val limit: Int,
)

object SearchQuery {
    const val DEFAULT_LIMIT = 50
    const val MAX_LIMIT = 100
    private const val MAX_EXPRESSION_CHARS = 200

    fun prepare(raw: String, limit: Int = DEFAULT_LIMIT): PreparedSearch? {
        val match = matchExpression(raw) ?: return null
        return PreparedSearch(
            sql = DictionarySql.SEARCH,
            matchArgument = match,
            limit = limit.coerceIn(1, MAX_LIMIT),
        )
    }

    /**
     * The iOS app turns a typed `?` into the FTS wildcard `*`. The 2012 Android
     * app replaced `*` with `?`, which is not how this FTS index matches.
     * Quotes and grouping characters are removed so a typed quote cannot break
     * the MATCH expression. The keyword is still passed as a bound argument.
     * NFKC folds full-width romaji and a full-width question mark from a
     * Japanese IME (`ｎｅｋｏ`, `？`) onto the ASCII the index was built with.
     */
    fun matchExpression(raw: String): String? {
        val normalized = Normalizer.normalize(raw, Normalizer.Form.NFKC)
        val cleaned = buildString(normalized.length) {
            for (ch in normalized) {
                when (ch) {
                    '?' -> append('*')
                    '"', '(', ')', '^', '\u0000' -> Unit
                    else -> if (!ch.isISOControl()) append(ch)
                }
            }
        }.trim()
        if (cleaned.isEmpty() || cleaned.length > MAX_EXPRESSION_CHARS) return null
        if (cleaned.all { it == '*' || it.isWhitespace() }) return null
        return cleaned
    }
}
