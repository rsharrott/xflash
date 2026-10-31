package com.japaneseinaflash.app.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MeaningTextTest {
    @Test
    fun listOfSensesKeepsThePartOfSpeech() {
        val senses = parseMeaning(
            "<ol><li>cat (esp. the domestic cat) / feline<dfn>noun</dfn></li>" +
                "<li>geisha<dfn>noun</dfn></li></ol>",
        )
        assertEquals(2, senses.size)
        assertEquals("cat (esp. the domestic cat) / feline", senses[0].text)
        assertEquals("noun", senses[0].partOfSpeech)
        assertEquals("geisha", senses[1].text)
    }

    @Test
    fun singleSenseWithoutAList() {
        val senses = parseMeaning("cat<dfn>noun</dfn>")
        assertEquals(Sense("cat", "noun"), senses.single())
    }

    @Test
    fun plainTextAndEntities() {
        assertEquals(listOf(Sense("a & b", null)), parseMeaning("a &amp; b"))
        assertEquals("less than <", parseMeaning("less than &lt;").single().text)
        assertEquals("quote", parseMeaning("&#39;quote&#39;").single().text.trim('\'').let { it })
        assertEquals("'", parseMeaning("&#39;").single().text)
    }

    @Test
    fun blankIsEmpty() {
        assertTrue(parseMeaning(null).isEmpty())
        assertTrue(parseMeaning("   ").isEmpty())
        assertNull(parseMeaning("cat").single().partOfSpeech)
    }
}
