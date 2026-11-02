package com.japaneseinaflash.app.ui

import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PracticeKeysTest {
    @Test
    fun spaceAndEnterShowTheAnswerUntilItIsShowing() {
        assertEquals(PracticeKey.ShowAnswer, practiceKey(false, KeyEventType.KeyUp, Key.Spacebar))
        assertEquals(PracticeKey.ShowAnswer, practiceKey(false, KeyEventType.KeyUp, Key.Enter))
        assertNull(practiceKey(true, KeyEventType.KeyUp, Key.Spacebar))
        assertEquals(PracticeKey.Right, practiceKey(true, KeyEventType.KeyUp, Key.Enter))
    }

    @Test
    fun arrowsMarkRightAndWrongOnlyAfterTheAnswer() {
        assertNull(practiceKey(false, KeyEventType.KeyUp, Key.DirectionRight))
        assertNull(practiceKey(false, KeyEventType.KeyUp, Key.DirectionLeft))
        assertEquals(PracticeKey.Right, practiceKey(true, KeyEventType.KeyUp, Key.DirectionRight))
        assertEquals(PracticeKey.Wrong, practiceKey(true, KeyEventType.KeyUp, Key.DirectionLeft))
        assertNull(practiceKey(true, KeyEventType.KeyDown, Key.DirectionRight))
    }
}
