package com.japaneseinaflash.app.ui

import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType

internal enum class PracticeKey {
    ShowAnswer,
    Right,
    Wrong,
}

/** Hardware keyboard: Space shows the answer. Enter does too, and marks Right once it is showing. */
internal fun practiceKey(revealed: Boolean, type: KeyEventType, key: Key): PracticeKey? {
    if (type != KeyEventType.KeyUp) return null
    return when (key) {
        Key.Spacebar -> if (revealed) null else PracticeKey.ShowAnswer
        Key.Enter, Key.NumPadEnter -> if (revealed) PracticeKey.Right else PracticeKey.ShowAnswer
        Key.DirectionRight -> if (revealed) PracticeKey.Right else null
        Key.DirectionLeft -> if (revealed) PracticeKey.Wrong else null
        else -> null
    }
}
