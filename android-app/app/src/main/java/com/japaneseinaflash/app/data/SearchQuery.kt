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
     * Tokens are quoted when they would otherwise be FTS operators or when
     * they contain characters that break an unquoted query. SQLite FTS treats
     * only the uppercase words `AND`, `OR`, `NOT`, and `NEAR` as operators, so
     * lowercase `and`, `or`, `not`, and `near` stay search terms (`not available`,
     * `black and white`). An uppercase `OR` between words is kept (`neko OR inu`
     * matches either word). A quoted `"OR"` stays a word inside that disjunction.
     * `AND`, `NOT`, and `NEAR` are dropped, and a dangling `OR` is dropped, so
     * none of them can reject the query. A leading `-` is the NOT
     * operator and is removed. `?` is the wildcard: a trailing `?` becomes `*`,
     * characters after a `?` stay in the word (`ne?ko` is `neko`), and a
     * one-letter ASCII stem is not expanded (`s?` stays `s`) because `s*` scans
     * the whole index. Quoted phrases stay phrases. A kanji or kana token,
     * including the prolonged sound mark `ー`, is a prefix, so `水` matches
     * `水*` and `ラー` matches `ラーメン`. The exact term is what ranking
     * compares to the headword, reading, romaji, and gloss. NFKC folds
     * full-width romaji and a full-width question mark (`ｎｅｋｏ`, `？`).
     */
    fun plan(raw: String, limit: Int = DEFAULT_LIMIT): SearchPlan {
        val normalized = Normalizer.normalize(raw, Normalizer.Form.NFKC).trim()
        if (normalized.isEmpty()) return SearchPlan.Blank
        if (normalized.length > MAX_EXPRESSION_CHARS) return SearchPlan.TooLong
        val parsed = tokens(normalized)
        if (parsed.isEmpty()) return SearchPlan.Blank
        val words = parsed.filter { !it.isJoiner() }
        val pieces = if (words.isNotEmpty()) {
            words
        } else {
            parsed.map { piece ->
                piece.copy(text = piece.text.literalOperator(), forceQuote = true, userWildcard = false)
            }
        }
        val disjunction = linkedByOr(parsed)
        val match = if (disjunction) {
            words.joinToString(" OR ") { it.toMatch() }
        } else {
            pieces.map { it.toMatch() }.filter { it.isNotEmpty() }.joinToString(" ")
        }
        if (match.isEmpty() || match.all { it == '*' || it.isWhitespace() }) return SearchPlan.Blank
        val exact = if (disjunction) "" else pieces.joinToString(" ") { it.text }.trim()
        if (exact.isEmpty() && !disjunction) return SearchPlan.Blank
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

    /** A bare FTS operator. A quoted `"OR"` is a word, not a joiner. */
    private fun Piece.isJoiner(): Boolean = !phrase && text.isOperator()

    /**
     * True when every word is joined to the next by uppercase `OR` and no other
     * operator is present. A leading or trailing `OR` does not count, and a
     * quoted `"OR"` counts as a word.
     */
    private fun linkedByOr(raw: List<Piece>): Boolean {
        var words = 0
        var seenWord = false
        var orSinceWord = false
        for (piece in raw) {
            if (piece.isJoiner()) {
                if (piece.text != "OR") return false
                orSinceWord = true
                continue
            }
            if (seenWord && !orSinceWord) return false
            seenWord = true
            orSinceWord = false
            words++
        }
        return words >= 2
    }

    private fun tokens(normalized: String): List<Piece> {
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
        return raw
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
        val trailingWildcard = stripped.last() == '?' || stripped.last() == '*'
        // `?` inside a word is not a mid-token wildcard this index can express.
        // Keep the characters on both sides (`ne?ko` → neko) instead of dropping
        // everything after the mark.
        val text = stripped.filter { it != '?' && it != '*' }
        if (text.isEmpty()) return null
        val expand = trailingWildcard && (text.isJapaneseScript() || text.length >= MIN_ASCII_WILDCARD_STEM)
        return Piece(
            text = text,
            phrase = false,
            userWildcard = expand,
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
        if (prefix && text.isSafeBareToken()) return "$text*"
        // A quoted prefix (`"nek"*`) does not match this FTS index, so a word
        // that cannot be written bare is kept as a literal phrase.
        if (forceQuote || phrase || !text.isSafeBareToken() || prefix) {
            return "\"" + text.replace("\"", "") + "\""
        }
        return text
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
            if (!cp.isSearchTokenChar()) return false
        }
        return true
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

    /**
     * U+30FC `ー` is the prolonged sound mark. Its script is Common, not
     * Katakana, so a word such as ラーメン would otherwise miss the kana prefix.
     * U+30FB `・` and U+30A0 `゠` are the katakana middle dot and double hyphen
     * and likewise sit inside kana words.
     */
    private fun Int.isJapaneseLetter(): Boolean {
        if (this == '々'.code || this == '〆'.code || this == '〻'.code) return true
        if (this == 'ー'.code || this == '・'.code || this == '゠'.code) return true
        return when (Character.UnicodeScript.of(this)) {
            Character.UnicodeScript.HAN,
            Character.UnicodeScript.HIRAGANA,
            Character.UnicodeScript.KATAKANA,
            -> true
            else -> false
        }
    }

    private fun Int.isSearchTokenChar(): Boolean =
        Character.isLetterOrDigit(this) || this == 'ー'.code || this == '・'.code || this == '゠'.code

    /** FTS operators are the uppercase words only. `and` is a normal token. */
    private val operator = Regex("AND|OR|NOT|NEAR(?:/\\d+)?")
    private val whitespace = Regex("\\s+")

    private const val MIN_ASCII_WILDCARD_STEM = 2
}
