package com.japaneseinaflash.app.data

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
     */
    fun matchExpression(raw: String): String? {
        val cleaned = buildString(raw.length) {
            for (ch in raw) {
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
