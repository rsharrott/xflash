package com.japaneseinaflash.app.study

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LevelProgressTest {
    @Test
    fun rightAndWrongFollowTheIosLadder() {
        assertEquals(2, nextLevel(0, right = true))
        assertEquals(2, nextLevel(1, right = true))
        assertEquals(3, nextLevel(2, right = true))
        assertEquals(4, nextLevel(3, right = true))
        assertEquals(5, nextLevel(4, right = true))
        assertEquals(5, nextLevel(5, right = true))
        assertEquals(1, nextLevel(0, right = false))
        assertEquals(1, nextLevel(4, right = false))
        assertEquals(1, nextLevel(5, right = false))
    }

    @Test
    fun barsAreCumulativeOverSeenCards() {
        val levels = intArrayOf(70, 6, 8, 4, 2, 6)
        val bars = cumulativeBarFractions(levels)
        assertEquals(1f, bars[0], 0.001f)
        assertEquals(20f / 26f, bars[1], 0.001f)
        assertEquals(12f / 26f, bars[2], 0.001f)
        assertEquals(8f / 26f, bars[3], 0.001f)
        assertEquals(6f / 26f, bars[4], 0.001f)
        assertEquals(FloatArray(5) { 0f }.toList(), cumulativeBarFractions(intArrayOf(90, 0, 0, 0, 0, 0)).toList())
    }

    @Test
    fun pillUsesTheLearnedLineOnlyWhenTheSetIsDone() {
        assertEquals(
            "4 / 626 learned",
            learnedPillText(4, 626, { a, b -> "$a / $b learned" }, "Set learned ✓"),
        )
        assertEquals("0 / 0 learned", learnedPillText(0, 0, { a, b -> "$a / $b learned" }, "Set learned ✓"))
        assertEquals("Set learned ✓", learnedPillText(90, 90, { a, b -> "$a / $b learned" }, "Set learned ✓"))
        assertEquals("Set learned ✓", learnedPillText(100, 90, { a, b -> "$a / $b learned" }, "Set learned ✓"))
        assertEquals("0 / 10 learned", learnedPillText(-3, 10, { a, b -> "$a / $b learned" }, "Set learned ✓"))
        assertFalse(isSetLearned(0, 0))
        assertEquals(1f, learnedFraction(90, 90))
        assertEquals(0f, learnedFraction(0, 90))
    }

    @Test
    fun stripSummarySkipsABlankName() {
        assertEquals(
            "Studying 6, Right 1x 8",
            levelStripSummary(listOf("Studying", "", "Right 1x"), listOf(6, 9, 8)),
        )
    }
}
