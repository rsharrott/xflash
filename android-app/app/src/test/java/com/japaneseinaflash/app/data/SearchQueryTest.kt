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
    fun japanesePassesThroughUnchanged() {
        assertEquals("ねこ", SearchQuery.matchExpression("ねこ"))
        assertEquals("猫", SearchQuery.matchExpression("  猫  "))
    }

    @Test
    fun quotesAndGroupingAreRemovedButTheKeywordStaysBound() {
        val prepared = SearchQuery.prepare("ca\"t(x)")
        assertEquals("catx", prepared!!.matchArgument)
        assertEquals(DictionarySql.SEARCH, prepared.sql)
        assertFalse(prepared.sql.contains("catx"))
        assertTrue(prepared.sql.contains("cards_search_content MATCH ?"))
        assertTrue(prepared.sql.contains("LIMIT ?"))
    }

    @Test
    fun rankIsShortestContentThenCommonWordsThenCardId() {
        val sql = DictionarySql.SEARCH
        assertTrue(sql.contains("ORDER BY LENGTH(content) ASC, ptag DESC, card_id ASC"))
        assertFalse(sql.contains("headword MATCH"))
        assertFalse(sql.contains("reading MATCH"))
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
