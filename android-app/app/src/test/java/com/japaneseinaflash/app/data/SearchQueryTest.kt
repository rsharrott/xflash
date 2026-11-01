package com.japaneseinaflash.app.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SearchQueryTest {
    @Test
    fun questionMarkBecomesTheFtsWildcard() {
        val prepared = SearchQuery.prepare("nek?")
        assertEquals("nek*", prepared!!.matchArgument)
    }

    @Test
    fun fullWidthRomajiAndQuestionMarkAreNormalized() {
        assertEquals("neko", SearchQuery.prepare("\uFF4E\uFF45\uFF4B\uFF4F")!!.matchArgument)
        assertEquals("nek*", SearchQuery.prepare("\uFF4E\uFF45\uFF4B\uFF1F")!!.matchArgument)
    }

    @Test
    fun japaneseIsAPrefixSoCompoundsMatchAndTheExactTermStays() {
        val kana = SearchQuery.prepare("ねこ")!!
        assertEquals("ねこ*", kana.matchArgument)
        assertEquals("ねこ", kana.exactTerm)
        val kanji = SearchQuery.prepare("  水  ")!!
        assertEquals("水*", kanji.matchArgument)
        assertEquals("水", kanji.exactTerm)
        assertEquals("\"水\"", SearchQuery.prepare("\"水\"")!!.matchArgument)
    }

    @Test
    fun quotesStayBoundAndCannotChangeTheSql() {
        val prepared = SearchQuery.prepare("ca\"t(x)")!!
        assertEquals("ca \"tx\"", prepared.matchArgument)
        assertEquals(DictionarySql.SEARCH, prepared.sql)
        assertFalse(prepared.matchArgument, prepared.sql.contains(prepared.matchArgument))
        assertTrue(prepared.sql.contains("cards_search_content MATCH ?"))
        assertTrue(prepared.sql.contains("LIMIT ?"))
        assertEquals(prepared.sql.count { it == '?' }, prepared.arguments.size)
    }

    @Test
    fun operatorsAreQuotedOrDroppedSoTheMatchStaysWellFormed() {
        assertEquals("\"OR\"", SearchQuery.prepare("OR")!!.matchArgument)
        assertEquals("neko", SearchQuery.prepare("neko OR")!!.matchArgument)
        assertEquals("neko", SearchQuery.prepare("-neko")!!.matchArgument)
        assertEquals("\"NEAR\"", SearchQuery.prepare("NEAR")!!.matchArgument)
        assertEquals("neko", SearchQuery.prepare("neko NEAR/2")!!.matchArgument)
        assertEquals("\"hot water\"", SearchQuery.prepare("\"hot water\"")!!.matchArgument)
        assertEquals("nek*", SearchQuery.prepare("nek?")!!.matchArgument)
    }

    @Test
    fun lowercaseOperatorWordsStaySearchTerms() {
        val phrase = SearchQuery.prepare("black and white")!!
        assertEquals("black and white", phrase.matchArgument)
        assertEquals("black and white", phrase.exactTerm)
        val not = SearchQuery.prepare("not available")!!
        assertEquals("not available", not.matchArgument)
        assertEquals("not available", not.exactTerm)
        assertEquals("near", SearchQuery.prepare("near")!!.matchArgument)
        assertEquals("or", SearchQuery.prepare("or")!!.matchArgument)
    }

    @Test
    fun prolongedSoundMarkIsAKanaPrefix() {
        assertEquals("ラーメン*", SearchQuery.prepare("ラーメン")!!.matchArgument)
        assertEquals("ラー*", SearchQuery.prepare("ラー")!!.matchArgument)
        assertEquals("ゲーム*", SearchQuery.prepare("ゲーム")!!.matchArgument)
        assertEquals("コーヒー*", SearchQuery.prepare("コーヒー")!!.matchArgument)
        assertEquals("コーヒー・ショップ*", SearchQuery.prepare("コーヒー・ショップ")!!.matchArgument)
    }

    @Test
    fun wildcardKeepsTextAfterTheMarkAndSkipsAOneLetterStem() {
        assertEquals("neko", SearchQuery.prepare("ne?ko")!!.matchArgument)
        assertEquals("nek*", SearchQuery.prepare("nek?")!!.matchArgument)
        assertEquals("s", SearchQuery.prepare("s?")!!.matchArgument)
        assertEquals("s", SearchQuery.prepare("s*")!!.matchArgument)
        assertEquals("\"e-mail\"", SearchQuery.prepare("e-mail?")!!.matchArgument)
    }

    @Test
    fun rankIsExactThenCommonThenHeadwordLength() {
        val sql = DictionarySql.SEARCH
        val order = sql.substringAfter("ORDER BY")
        val first = order.indexOf("THEN 0")
        val later = order.indexOf("THEN 1")
        val ptag = order.indexOf("ptag DESC")
        val head = order.indexOf("head_len ASC")
        val card = order.indexOf("card_id ASC")
        assertTrue(first in 0 until later)
        assertTrue(later < ptag)
        assertTrue(ptag < head)
        assertTrue(head < card)
        assertFalse(order.contains("LENGTH(content)"))
        assertFalse(sql.contains("headword MATCH"))
        assertFalse(sql.contains("reading MATCH"))
        val prepared = SearchQuery.prepare("cat")!!
        assertEquals("cat", prepared.exactTerm)
        assertEquals(listOf("cat", "cat", "50"), prepared.arguments)
    }

    @Test
    fun overlongQueriesAreReportedInsteadOfSearching() {
        assertTrue(SearchQuery.plan("a".repeat(SearchQuery.MAX_EXPRESSION_CHARS)) is SearchPlan.Ready)
        assertTrue(SearchQuery.plan("a".repeat(SearchQuery.MAX_EXPRESSION_CHARS + 1)) is SearchPlan.TooLong)
        assertNull(SearchQuery.prepare("a".repeat(SearchQuery.MAX_EXPRESSION_CHARS + 1)))
    }

    @Test
    fun blankAndStarOnlyQueriesAreNotRun() {
        assertNull(SearchQuery.prepare(""))
        assertNull(SearchQuery.prepare("   "))
        assertNull(SearchQuery.prepare("???"))
        assertNull(SearchQuery.prepare("*"))
        assertNull(SearchQuery.prepare("\""))
    }

    @Test
    fun limitIsClamped() {
        assertEquals(1, SearchQuery.prepare("cat", limit = 0)!!.limit)
        assertEquals(SearchQuery.MAX_LIMIT, SearchQuery.prepare("cat", limit = 500)!!.limit)
        assertEquals(SearchQuery.DEFAULT_LIMIT, SearchQuery.prepare("cat")!!.limit)
    }

    @Test
    fun summaryPlaceholdersMatchTheIdCount() {
        val sql = DictionarySql.summaries(3)
        assertTrue(sql.contains("IN (?,?,?)"))
        assertFalse(sql.contains("1"))
    }

    @Test
    fun sentencesAreTheShownLinksOnly() {
        assertTrue(DictionarySql.SENTENCES.contains("l.should_show = 1"))
        assertTrue(DictionarySql.SENTENCES.contains("LIMIT 10"))
    }

    @Test
    fun versionSchemaIsAFixedName() {
        assertEquals("SELECT version FROM CARD_DB.version LIMIT 1", DictionarySql.version("CARD_DB"))
        assertEquals("SELECT version FROM main.version LIMIT 1", DictionarySql.version("main"))
    }

    @Test(expected = IllegalArgumentException::class)
    fun versionSchemaRejectsAnythingElse() {
        DictionarySql.version("CARD_DB; DROP TABLE cards")
    }
}
