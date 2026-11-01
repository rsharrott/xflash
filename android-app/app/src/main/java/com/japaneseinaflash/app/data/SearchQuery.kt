package com.japaneseinaflash.app.data

import java.text.Normalizer
import java.util.Locale

data class PreparedSearch(
    val sql: String,
    val matchArgument: String,
    val exactTerm: String,
    val limit: Int,
) {
    /** Bound in placeholder order: exact term, MATCH expression, limit. */
    val arguments: List<String> get() = listOf(exactTerm, matchArgument, limit.toString())
}

sealed interface SearchPlan {
    data class Ready(val search: PreparedSearch) : SearchPlan
    data object Blank : SearchPlan
    data object TooLong : SearchPlan
}

object SearchQuery {
    const val DEFAULT_LIMIT = 50
    const val MAX_LIMIT = 100
    const val MAX_EXPRESSION_CHARS = 200

    fun prepare(raw: String, limit: Int = DEFAULT_LIMIT): PreparedSearch? =
        (plan(raw, limit) as? SearchPlan.Ready)?.search

    /**
     * Turns typed text into a MATCH expression SQLite will accept.
     *
     * Tokens are quoted when they would otherwise be FTS operators (`OR`,
     * `NEAR`, a leading `-`) or when they contain characters that break an
     * unquoted query. `?` is the wildcard and becomes a trailing `*`. Quoted
     * phrases stay phrases. A bare `AND`, `OR`, `NOT`, or `NEAR` next to a
     * real word is dropped so it cannot AND the query down to nothing (those
     * operator words are mostly absent from the index). A kanji or kana token
     * is a prefix, so `水` matches `水*` as well as the exact word. The exact
     * term is what ranking compares to the headword, reading, romaji, and gloss.
     * NFKC folds full-width romaji and a full-width question mark (`ｎｅｋｏ`, `？`).
     */
    fun plan(raw: String, limit: Int = DEFAULT_LIMIT): SearchPlan {
        val normalized = Normalizer.normalize(raw, Normalizer.Form.NFKC).trim()
        if (normalized.isEmpty()) return SearchPlan.Blank
        if (normalized.length > MAX_EXPRESSION_CHARS) return SearchPlan.TooLong
        val pieces = pieces(normalized)
        if (pieces.isEmpty()) return SearchPlan.Blank
        val match = pieces.map { it.toMatch() }.filter { it.isNotEmpty() }.joinToString(" ")
        if (match.isEmpty() || match.all { it == '*' || it.isWhitespace() }) return SearchPlan.Blank
        val exact = pieces.joinToString(" ") { it.text }.trim()
        if (exact.isEmpty()) return SearchPlan.Blank
        return SearchPlan.Ready(
            PreparedSearch(
                sql = DictionarySql.SEARCH,
                matchArgument = match,
                exactTerm = exact,
                limit = limit.coerceIn(1, MAX_LIMIT),
            ),
        )
    }

    private data class Piece(
        val text: String,
        val phrase: Boolean,
        val userWildcard: Boolean,
        val forceQuote: Boolean,
    )

    private fun pieces(normalized: String): List<Piece> {
        val raw = ArrayList<Piece>()
        var index = 0
        while (index < normalized.length) {
            val ch = normalized[index]
            if (ch.isWhitespace()) {
                index++
                continue
            }
            if (ch == '"') {
                val end = normalized.indexOf('"', index + 1)
                val body = if (end < 0) normalized.substring(index + 1) else normalized.substring(index + 1, end)
                index = if (end < 0) normalized.length else end + 1
                val text = cleanPhrase(body)
                if (text.isNotEmpty()) raw += Piece(text, phrase = true, userWildcard = false, forceQuote = true)
                continue
            }
            val start = index
            while (index < normalized.length && !normalized[index].isWhitespace() && normalized[index] != '"') {
                index++
            }
            parseBare(normalized.substring(start, index))?.let { raw += it }
        }
        val words = raw.filter { !it.text.isOperator() }
        if (words.isNotEmpty()) return words
        return raw.map { piece ->
            piece.copy(text = piece.text.literalOperator(), forceQuote = true, userWildcard = false)
        }
    }

    private fun parseBare(token: String): Piece? {
        val stripped = buildString(token.length) {
            for (ch in token) {
                when (ch) {
                    '"', '(', ')', '^', '\u0000' -> Unit
                    else -> if (!ch.isISOControl()) append(ch)
                }
            }
        }.trimStart('-')
        if (stripped.isEmpty()) return null
        val wild = stripped.indexOfAny(charArrayOf('?', '*'))
        val text = if (wild >= 0) stripped.substring(0, wild) else stripped
        val kept = text.filter { it != '?' && it != '*' }
        if (kept.isEmpty()) return null
        return Piece(
            text = kept,
            phrase = false,
            userWildcard = wild >= 0,
            forceQuote = false,
        )
    }

    private fun cleanPhrase(body: String): String {
        val cleaned = buildString(body.length) {
            for (ch in body) {
                when (ch) {
                    '"', '(', ')', '^', '?', '*', '\u0000' -> Unit
                    else -> if (!ch.isISOControl()) append(ch)
                }
            }
        }.trim()
        return whitespace.replace(cleaned, " ")
    }

    private fun Piece.toMatch(): String {
        val prefix = userWildcard || (!phrase && text.isJapaneseScript())
        if (forceQuote || phrase || !text.isSafeBareToken()) {
            if (prefix) {
                val bare = text.safeBare()
                return if (bare.isEmpty()) "" else "$bare*"
            }
            return "\"" + text.replace("\"", "") + "\""
        }
        return if (prefix) "$text*" else text
    }

    private fun String.isOperator(): Boolean = operator.matches(this)

    private fun String.literalOperator(): String {
        val upper = uppercase(Locale.ROOT)
        return if (upper == "NEAR" || upper.startsWith("NEAR/")) "NEAR" else this
    }

    private fun String.isSafeBareToken(): Boolean {
        if (isEmpty()) return false
        var index = 0
        while (index < length) {
            val cp = codePointAt(index)
            index += Character.charCount(cp)
            if (!Character.isLetterOrDigit(cp)) return false
        }
        return true
    }

    private fun String.safeBare(): String = buildString(length) {
        var index = 0
        while (index < this@safeBare.length) {
            val cp = this@safeBare.codePointAt(index)
            index += Character.charCount(cp)
            if (Character.isLetterOrDigit(cp)) appendCodePoint(cp)
        }
    }

    private fun String.isJapaneseScript(): Boolean {
        if (isEmpty()) return false
        var index = 0
        while (index < length) {
            val cp = codePointAt(index)
            index += Character.charCount(cp)
            if (!cp.isJapaneseLetter()) return false
        }
        return true
    }

    private fun Int.isJapaneseLetter(): Boolean {
        if (this == '々'.code || this == '〆'.code || this == '〻'.code) return true
        return when (Character.UnicodeScript.of(this)) {
            Character.UnicodeScript.HAN,
            Character.UnicodeScript.HIRAGANA,
            Character.UnicodeScript.KATAKANA,
            -> true
            else -> false
        }
    }

    private val operator = Regex("AND|OR|NOT|NEAR(?:/\\d+)?", RegexOption.IGNORE_CASE)
    private val whitespace = Regex("\\s+")
}
