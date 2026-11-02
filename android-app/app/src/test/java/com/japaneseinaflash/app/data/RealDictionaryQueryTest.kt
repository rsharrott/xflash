package com.japaneseinaflash.app.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Runs the app's SQL against the real 2.0 databases with the system sqlite3,
 * the same files the APK will carry. Robolectric covers attach and the
 * Android cursor path with a small fixture.
 */
class RealDictionaryQueryTest {
    @Test
    fun nekoSearchResolvesToTheCatCardAndItsExamples() {
        val sources = listedSources().associateBy { it.assetName }
        val user = sources.getValue(DictionaryFiles.USER_DB).file
        val card = sources.getValue(DictionaryFiles.CARD_DB).file.absolutePath
        val fts = sources.getValue(DictionaryFiles.FTS_DB).file.absolutePath
        val examples = sources.getValue(DictionaryFiles.EX_DB).file.absolutePath
        val neko = SearchQuery.prepare("ねこ", limit = 1)!!
        val search = bind(neko.sql, neko.arguments)
        val cardSql = bind(DictionarySql.CARD, listOf("1467640"))
        val sentenceSql = bind(DictionarySql.SENTENCES, listOf("1467640"))
        val script = """
            ATTACH DATABASE '$card' AS CARD_DB;
            ATTACH DATABASE '$fts' AS FTS_DB;
            ATTACH DATABASE '$examples' AS EX_DB;
            $search;
            $cardSql;
            SELECT COUNT(*) FROM ($sentenceSql);
        """.trimIndent()
        val lines = sqlite3(user, script).lines().map { it.trim() }.filter { it.isNotEmpty() }
        assertEquals("1467640", lines[0])
        assertTrue(lines[1].startsWith("1467640|猫|ねこ|neko|"))
        val shown = lines[2].toInt()
        assertTrue("shown sentences were $shown", shown in 1..10)
    }

    @Test
    fun reportedQueriesPutTheCommonWordFirst() {
        assertEquals("水" to "みず", search("water").first())
        val inu = search("inu", limit = 10)
        assertEquals("犬" to "いぬ", inu.first())
        assertBefore(inu, "犬", "寝ぬ")
        assertBefore(inu, "犬", "淫雨")
        val neko = search("neko")
        assertEquals("猫" to "ねこ", neko.first())
        assertBefore(neko, "猫", "ギコ猫")
        val cat = search("cat")
        assertEquals("猫" to "ねこ", cat.first())
        assertBefore(cat, headword = "猫", laterReading = "ねこま")
        val kanji = search("水")
        assertEquals("水" to "みず", kanji.first())
        assertTrue(kanji.drop(1).any { it.first.startsWith("水") && it.first.length > 1 })
    }

    @Test
    fun primaryGlossOutranksALaterSense() {
        val eat = search("eat", limit = 40)
        assertBefore(eat, "食べる", "遣る")
        assertTrue("食べる was ${indexOf(eat, "食べる")} in $eat", indexOf(eat, "食べる") in 0..4)

        val go = search("go", limit = 40)
        assertBefore(go, "行く", "運ぶ")
        assertTrue("行く was ${indexOf(go, "行く")} in $go", indexOf(go, "行く") in 0..11)

        assertEquals("学校" to "がっこう", search("school").first())
        val person = search("person", limit = 8)
        val personIndex = person.indexOfFirst { it.first == "人" && it.second == "ひと" }
        assertTrue("人（ひと） was $personIndex in $person", personIndex in 0..2)
        assertTrue(person.take(personIndex).none { it.first == "彼" })

        assertEquals("犬" to "いぬ", search("dog").first())
        assertEquals("車" to "くるま", search("car").first())
        assertEquals("雨" to "あめ", search("rain").first())
    }

    @Test
    fun lowercaseAndAndProlongedKanaSearchTheRealIndex() {
        assertEquals("白黒" to "しろくろ", search("black and white", limit = 3).first())
        assertTrue(search("not available", limit = 5).isNotEmpty())
        assertTrue(search("ラー", limit = 5).isNotEmpty())
        val ramen = search("ラーメン", limit = 3)
        assertTrue(ramen.any { it.first == "ラーメン" || it.first == "拉麺" })
    }

    @Test
    fun prefixRankingAgreesWithTheFullQuery() {
        assertEquals(37, countMatches("ラー*"))
        for ((term, match) in listOf("co" to "co*", "こ" to "こ*")) {
            assertEquals(
                searchIds(DictionarySql.SEARCH, listOf(term, match, "50")),
                prefixIds(term, match, 50),
            )
        }
    }

    @Test
    fun operatorQueriesRunAndStillFindNeko() {
        assertEquals("猫" to "ねこ", search("neko OR", limit = 3).first())
        assertEquals("猫" to "ねこ", search("-neko", limit = 3).first())
        assertEquals("猫" to "ねこ", search("neko NEAR/2", limit = 3).first())
        assertTrue(search("OR", limit = 5).isNotEmpty())
        assertTrue(search("NEAR", limit = 5).isNotEmpty())
    }

    private fun search(raw: String, limit: Int = 8): List<Pair<String, String>> {
        val prepared = SearchQuery.prepare(raw, limit)!!
        val ids = query(bind(prepared.sql, prepared.arguments)).lines().map { it.trim() }.filter { it.isNotEmpty() }
        if (ids.isEmpty()) return emptyList()
        val listed = ids.joinToString(",")
        val rows = query(
            "SELECT card_id || '|' || headword || '|' || reading FROM cards WHERE card_id IN ($listed);",
        ).lines().map { it.trim() }.filter { it.isNotEmpty() }
        val byId = rows.associate { line ->
            val parts = line.split("|", limit = 3)
            parts[0] to (parts[1] to parts[2])
        }
        return ids.map { byId.getValue(it) }
    }

    private fun indexOf(rows: List<Pair<String, String>>, headword: String): Int =
        rows.indexOfFirst { it.first == headword }

    private fun assertBefore(
        rows: List<Pair<String, String>>,
        headword: String,
        laterHeadword: String = headword,
        laterReading: String? = null,
    ) {
        val first = rows.indexOfFirst { it.first == headword && (laterReading == null || it.second != laterReading) }
        val later = if (laterReading == null) {
            rows.indexOfFirst { it.first == laterHeadword }
        } else {
            rows.indexOfFirst { it.first == headword && it.second == laterReading }
        }
        assertTrue("$headword should come before $laterHeadword $laterReading in $rows", first >= 0 && later > first)
    }

    private fun prefixIds(term: String, match: String, limit: Int): List<String> {
        val promoted = searchIds(DictionarySql.SCORED, listOf(term, term, limit.toString())).map { line ->
            val parts = line.split("|")
            RankedCard(parts[0].toLong(), parts[1].toInt(), parts[2].toInt(), parts[3].toInt())
        }
        val fillers = searchIds(DictionarySql.PREFIX_HITS, listOf(match, limit.toString())).map { line ->
            val parts = line.split("|")
            RankedCard(parts[0].toLong(), rank = 2, ptag = parts[1].toInt(), headLength = parts[2].toInt())
        }
        return SearchRank.merge(promoted, fillers, limit).map { it.toString() }
    }

    private fun searchIds(sql: String, args: List<String>): List<String> =
        query(bind(sql, args)).lines().map { it.trim() }.filter { it.isNotEmpty() }

    private fun countMatches(match: String): Int =
        query("SELECT count(*) FROM cards_search_content WHERE cards_search_content MATCH '$match';").trim().toInt()

    private fun query(sql: String): String {
        val sources = listedSources().associateBy { it.assetName }
        val user = sources.getValue(DictionaryFiles.USER_DB).file
        val card = sources.getValue(DictionaryFiles.CARD_DB).file.absolutePath
        val fts = sources.getValue(DictionaryFiles.FTS_DB).file.absolutePath
        val script = """
            ATTACH DATABASE '$card' AS CARD_DB;
            ATTACH DATABASE '$fts' AS FTS_DB;
            $sql
        """.trimIndent()
        return sqlite3(user, script)
    }

    private fun bind(sql: String, args: List<String>): String {
        var left = sql
        for (arg in args) {
            val literal = if (arg.isNotEmpty() && arg.all { it.isDigit() }) {
                arg
            } else {
                "'" + arg.replace("'", "''") + "'"
            }
            val index = left.indexOf('?')
            require(index >= 0) { "no placeholder for [$arg]" }
            left = left.replaceRange(index, index + 1, literal)
        }
        require("?" !in left) { left }
        return left
    }
}
