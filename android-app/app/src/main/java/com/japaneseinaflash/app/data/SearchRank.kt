package com.japaneseinaflash.app.data

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
 * How a typed query is ranked once [SearchQuery] has made it safe.
 *
 * A prefix is ordered in SQL. A single token uses the same gloss rank as a
 * phrase, read from a stored copy of the hits. Anything with more than one
 * word uses the full query.
 */
internal object SearchRank {
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
}
