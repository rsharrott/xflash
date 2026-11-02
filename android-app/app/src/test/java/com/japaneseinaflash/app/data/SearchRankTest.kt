package com.japaneseinaflash.app.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SearchRankTest {
    @Test
    fun anExactLongWordOutranksAShorterPrefixHit() {
        val promoted = listOf(RankedCard(id = 9, rank = 0, ptag = 1, headLength = 8))
        val fillers = listOf(
            RankedCard(id = 1, rank = 2, ptag = 1, headLength = 2),
            RankedCard(id = 9, rank = 2, ptag = 1, headLength = 8),
        )
        assertEquals(listOf(9L, 1L), SearchRank.merge(promoted, fillers, limit = 2))
    }

    @Test
    fun aLaterGlossOutranksANonExactShorterWord() {
        val promoted = listOf(RankedCard(id = 4, rank = 1, ptag = 0, headLength = 6))
        val fillers = listOf(RankedCard(id = 2, rank = 2, ptag = 1, headLength = 1))
        assertEquals(listOf(4L, 2L), SearchRank.merge(promoted, fillers, limit = 2))
    }

    @Test
    fun onlyASingleTokenStarIsAPrefixQuery() {
        assertTrue(SearchRank.isPrefixQuery("co*", "co"))
        assertTrue(SearchRank.isPrefixQuery("こ*", "こ"))
        assertFalse(SearchRank.isPrefixQuery("black and white", "black and white"))
        assertFalse(SearchRank.isPrefixQuery("neko", "neko"))
        assertFalse(SearchRank.isPrefixQuery("s", "s"))
        assertFalse(SearchRank.isPrefixQuery("neko OR inu", ""))
    }

    @Test
    fun aSingleTokenUsesTheStagedRank() {
        assertTrue(SearchRank.isSingleToken("and", "and"))
        assertTrue(SearchRank.isSingleToken("s", "s"))
        assertFalse(SearchRank.isSingleToken("and*", "and"))
        assertFalse(SearchRank.isSingleToken("black and white", "black and white"))
        assertFalse(SearchRank.isSingleToken("neko OR inu", ""))
    }

    @Test
    fun aPrefixPrefersTheFieldThatStartsWithTheStem() {
        val hits = listOf(
            PrefixHit(1, 1, 1, "熟", "こなれる", "konareru", "ripe"),
            PrefixHit(2, 0, 3, "指揮官", "しきかん", "shikikan", "commander"),
            PrefixHit(3, 1, 1, "回", "かい", "kai", "counter for occurrences"),
            PrefixHit(4, 1, 1, "咳", "せき", "seki", "cough"),
        )
        assertEquals(listOf(3L, 4L, 2L, 1L), SearchRank.prefixIds(hits, "co", limit = 4))
    }
}
