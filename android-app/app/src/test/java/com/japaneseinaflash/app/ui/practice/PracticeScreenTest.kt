package com.japaneseinaflash.app.ui.practice

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.activity.ComponentActivity
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.pressKey
import androidx.compose.ui.test.requestFocus
import androidx.compose.ui.unit.dp
import com.japaneseinaflash.app.data.CardDetail
import com.japaneseinaflash.app.data.ExampleSentence
import com.japaneseinaflash.app.data.PracticeCard
import com.japaneseinaflash.app.data.Sense
import com.japaneseinaflash.app.study.AppPreferences
import com.japaneseinaflash.app.study.StudyTheme
import com.japaneseinaflash.app.ui.PracticeUiState
import com.japaneseinaflash.app.ui.theme.JifTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@OptIn(ExperimentalTestApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], qualifiers = "w412dp-h2000dp")
class PracticeScreenTest {
    @get:Rule
    val compose = createAndroidComposeRule<ComponentActivity>()

    @Test
    fun showAnswerIsFullWidthThenWrongAndRight() {
        var marked: Boolean? = null
        var revealed by mutableStateOf(false)
        compose.setContent {
            JifTheme(StudyTheme.PAPER, dark = false) {
                PracticeScreen(
                    state = sample(revealed),
                    preferences = AppPreferences(),
                    onShowAnswer = { revealed = true },
                    onToggleReading = {},
                    onSpeak = {},
                    onMark = { marked = it },
                    onLevels = {},
                )
            }
        }
        compose.onNodeWithText("Show reading").assertIsDisplayed().assertHeightIsAtLeast(48.dp)
        compose.onNodeWithText("Show answer").assertIsDisplayed().assertHeightIsAtLeast(48.dp).performClick()
        compose.onNodeWithText("Wrong").assertIsDisplayed().performClick()
        assertEquals(false, marked)
        compose.onNodeWithText("Right").assertIsDisplayed().assertHeightIsAtLeast(48.dp)
        compose.onNodeWithText("1. tea").assertIsDisplayed()
        assertTrue(compose.onAllNodesWithText("Show answer").fetchSemanticsNodes().isEmpty())
    }

    @Test
    fun enterOnTheFocusedWrongButtonMarksWrong() {
        val marks = mutableListOf<Boolean>()
        compose.setContent {
            JifTheme(StudyTheme.PAPER, dark = false) {
                PracticeScreen(
                    state = sample(revealed = true),
                    preferences = AppPreferences(),
                    onShowAnswer = {},
                    onToggleReading = {},
                    onSpeak = {},
                    onMark = { marks.add(it) },
                    onLevels = {},
                )
            }
        }
        compose.onNodeWithText("Wrong").requestFocus().performKeyInput { pressKey(Key.Enter) }
        compose.waitForIdle()
        assertEquals(listOf(false), marks)
    }

    private fun sample(revealed: Boolean) = PracticeUiState(
        setName = "Hiragana (1 Basic)",
        levels = intArrayOf(40, 6, 0, 0, 0, 0),
        total = 46,
        revealed = revealed,
        loading = false,
        card = PracticeCard(
            detail = CardDetail(
                id = 1,
                headword = "あ",
                reading = "あ",
                romaji = "a",
                senses = listOf(Sense("tea", "noun")),
                sentences = listOf(ExampleSentence(1, "ああ", "Ah.")),
            ),
            kanaOnly = true,
            level = 0,
            rightCount = 0,
            wrongCount = 0,
        ),
    )
}
