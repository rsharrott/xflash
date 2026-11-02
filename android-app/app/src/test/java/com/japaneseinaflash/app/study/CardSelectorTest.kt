package com.japaneseinaflash.app.study

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

class CardSelectorTest {
    @Test
    fun anEmptySetAsksForANewCardAndAFullPoolDoesNot() {
        assertEquals(1.0, probabilityOfUnseen(0, 10, 0, 0, 30, 2), 0.0001)
        assertEquals(0.0, probabilityOfUnseen(30, 40, 60, 30, 30, 2), 0.0001)
        assertEquals(0.0, probabilityOfUnseen(10, 10, 20, 0, 30, 2), 0.0001)
    }

    @Test
    fun mediumFrequencyKeepsTheOldExponent() {
        assertEquals(2.0, unseenExponent(2), 0.0001)
        assertTrue(unseenExponent(4) < unseenExponent(1))
    }

    @Test
    fun roulettePrefersTheLessKnownLevel() {
        val levels = intArrayOf(0, 1, 10, 0, 0, 0)
        val low = pickCardLevel(levels, numLevels = 5, unseenProbability = 0.0, random = 0.01)
        assertEquals(1, low)
        val unseen = pickCardLevel(intArrayOf(4, 0, 0, 0, 0, 0), 5, 1.0, 0.5)
        assertEquals(0, unseen)
        assertEquals(-1, pickCardLevel(IntArray(6), 5, 0.0, 0.2))
    }

    @Test
    fun learnedStaysHiddenUntilItIsAllThatIsLeft() {
        assertEquals(4, selectableLevelCount(intArrayOf(3, 1, 0, 0, 0, 9), hideLearned = true))
        assertEquals(5, selectableLevelCount(intArrayOf(0, 0, 0, 0, 0, 9), hideLearned = true))
        assertEquals(5, selectableLevelCount(intArrayOf(3, 1, 0, 0, 0, 9), hideLearned = false))
        assertTrue(abs(levelTimesCount(intArrayOf(0, 2, 1, 0, 0, 0), 5) - 4) == 0)
    }
}
