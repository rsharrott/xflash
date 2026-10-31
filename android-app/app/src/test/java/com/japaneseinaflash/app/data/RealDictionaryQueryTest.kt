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
        val search = bind(DictionarySql.SEARCH, "ねこ", "5")
        val cardSql = bind(DictionarySql.CARD, "1467640")
        val sentenceSql = bind(DictionarySql.SENTENCES, "1467640")
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

    private fun bind(sql: String, vararg args: String): String {
        var left = sql
        for (arg in args) {
            require("'" !in arg && "?" !in arg)
            val literal = if (arg.all { it.isDigit() }) arg else "'$arg'"
            val index = left.indexOf('?')
            require(index >= 0)
            left = left.replaceRange(index, index + 1, literal)
        }
        require("?" !in left)
        return left
    }
}
