package com.japaneseinaflash.app.data

import java.util.Locale

/**
 * A search hit with the rank already decided.
 * `rank` 0 is an exact headword, reading, romaji, or first gloss.
 * 1 is an exact gloss in a later sense. 2 is everything else.
 */
internal data class RankedCard(
    val id: Long,
    val rank: Int,
    val ptag: Int,
    val headLength: Int,
)

/**
 * A prefix hit, before it is ordered by whether a field starts with the stem.
 */
internal data class PrefixHit(
    val id: Long,
    val ptag: Int,
    val headLength: Int,
    val headword: String,
    val reading: String,
    val romaji: String,
    val glossHead: String,
)

/**
 * How a typed query is ranked once [SearchQuery] has made it safe.
 *
 * A prefix (`co*`) prefers a headword, reading, romaji, or the main English
 * gloss that starts with the stem, then a common word, then a short headword.
 * A single token keeps the exact-gloss rank and fills the rest from the cheap
 * common-word order. Anything with more than one word uses the full query.
 */
internal object SearchRank {
    /** Rows read for a prefix so a short field-prefix hit is inside the window. */
    const val PREFIX_WINDOW = 400

    fun isPrefixQuery(match: String, exactTerm: String): Boolean =
        exactTerm.isNotEmpty() && !exactTerm.any { it.isWhitespace() } && match == "$exactTerm*"

    fun isSingleToken(match: String, exactTerm: String): Boolean =
        exactTerm.isNotEmpty() && match == exactTerm && !exactTerm.any { it.isWhitespace() }

    fun merge(promoted: List<RankedCard>, fillers: List<RankedCard>, limit: Int): List<Long> {
        val byId = HashMap<Long, RankedCard>(fillers.size + promoted.size)
        for (card in fillers) byId[card.id] = card.copy(rank = 2)
        for (card in promoted) byId[card.id] = card
        return byId.values
            .sortedWith(
                compareBy<RankedCard> { it.rank }
                    .thenByDescending { it.ptag }
                    .thenBy { it.headLength }
                    .thenBy { it.id },
            )
            .take(limit)
            .map { it.id }
    }

    fun prefixIds(hits: List<PrefixHit>, stem: String, limit: Int): List<Long> {
        val needle = stem.lowercase(Locale.ROOT)
        return hits
            .sortedWith(
                compareBy<PrefixHit> { if (it.startsWith(needle)) 0 else 1 }
                    .thenByDescending { it.ptag }
                    .thenBy { it.headLength }
                    .thenBy { it.id },
            )
            .take(limit)
            .map { it.id }
    }

    private fun PrefixHit.startsWith(needle: String): Boolean =
        fieldStarts(headword, needle) ||
            fieldStarts(reading, needle) ||
            fieldStarts(romaji, needle) ||
            fieldStarts(glossHead, needle)

    private fun fieldStarts(value: String, needle: String): Boolean {
        if (needle.isEmpty()) return false
        for (part in value.split(';')) {
            if (part.trim().lowercase(Locale.ROOT).startsWith(needle)) return true
        }
        return false
    }
}
