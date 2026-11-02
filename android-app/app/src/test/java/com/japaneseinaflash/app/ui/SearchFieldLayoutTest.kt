package com.japaneseinaflash.app.ui

import androidx.activity.ComponentActivity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.assertHeightIsAtLeast
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsFocused
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.pressKey
import androidx.compose.ui.unit.dp
import androidx.compose.ui.graphics.Color
import com.japaneseinaflash.app.data.CardSummary
import com.japaneseinaflash.app.study.StudyTheme
import com.japaneseinaflash.app.theme.TokenColors
import com.japaneseinaflash.app.ui.theme.JifTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@OptIn(ExperimentalTestApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28], qualifiers = "w800dp-h800dp-mdpi")
class SearchFieldLayoutTest {
    @get:Rule
    val rule = createAndroidComposeRule<ComponentActivity>()

    @Test
    fun enterMovesFocusToTheResults() {
        var submits = 0
        rule.setContent {
            JifTheme(StudyTheme.PAPER, dark = false) {
                SearchPane(
                    state = readyState(),
                    onQueryChange = {},
                    onSubmit = { submits++ },
                    onCard = {},
                    onAdd = {},
                    onRetry = {},
                )
            }
        }
        rule.onNodeWithText("neko").performClick()
        rule.onNodeWithText("neko").performKeyInput { pressKey(Key.Enter) }
        rule.waitForIdle()
        rule.onNodeWithTag(SearchResultsTag).assertIsFocused()
        rule.onNodeWithTag(SearchResultsTag).performKeyInput { pressKey(Key.Enter) }
        rule.waitForIdle()
        assertEquals(1, submits)
    }

    @Test
    fun focusedResultsDrawAPrimaryRing() {
        rule.setContent {
            JifTheme(StudyTheme.PAPER, dark = false) {
                SearchPane(
                    state = readyState(),
                    onQueryChange = {},
                    onSubmit = {},
                    onCard = {},
                    onRetry = {},
                )
            }
        }
        assertEquals(Color.Transparent, ringColor())
        rule.onNodeWithText("neko").performClick()
        rule.onNodeWithText("neko").performKeyInput { pressKey(Key.Enter) }
        rule.waitForIdle()
        rule.onNodeWithTag(SearchResultsTag).assertIsFocused()
        assertEquals(Color(TokenColors.FIRE), ringColor())
    }

    private fun ringColor(): Color =
        rule.onNodeWithTag(SearchResultsTag).fetchSemanticsNode().config[ResultsRing]

    @Test
    fun theSearchFieldKeepsItsMinimumHeightWhenTheWindowIsShort() {
        rule.setContent {
            JifTheme(StudyTheme.PAPER, dark = false) {
                Box(Modifier.requiredSize(width = 800.dp, height = 240.dp)) {
                    SearchPane(
                        state = readyState(),
                        onQueryChange = {},
                        onSubmit = {},
                        onCard = {},
                        onAdd = {},
                        onRetry = {},
                    )
                }
            }
        }
        rule.onNodeWithText("neko").assertHeightIsAtLeast(56.dp)
        rule.onNodeWithText("neko").assertIsDisplayed()
        rule.onNodeWithText("Clear", useUnmergedTree = true).assertIsDisplayed()
    }

    private fun readyState() = DictionaryUiState(
        phase = Phase.Ready,
        query = "neko",
        results = listOf(CardSummary(1, "猫", "ねこ", "cat")),
    )
}
