package com.japaneseinaflash.app.study

import com.japaneseinaflash.app.data.CardDetail
import com.japaneseinaflash.app.data.ExampleSentence
import com.japaneseinaflash.app.data.Sense
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PracticeFaceTest {
    private val card = CardDetail(
        id = 1,
        headword = "お茶",
        reading = "おちゃ",
        romaji = "ocha",
        senses = listOf(Sense("tea", "noun")),
        sentences = listOf(ExampleSentence(1, "お茶をどうぞ。", "Have some tea.")),
    )

    @Test
    fun questionHidesTheReadingUntilAsked() {
        val hidden = practiceFace(card, kanaOnly = false, AppPreferences(), revealed = false, showReading = false)
        assertEquals("お茶", hidden.prompt)
        assertNull(hidden.reading)
        assertNull(hidden.romaji)
        assertTrue(hidden.senses.isEmpty())
        val shown = practiceFace(card, kanaOnly = false, AppPreferences(), revealed = false, showReading = true)
        assertEquals("おちゃ", shown.reading)
        assertEquals("ocha", shown.romaji)
        assertTrue(shown.senses.isEmpty())
    }

    @Test
    fun answerShowsReadingSensesAndOneExample() {
        val face = practiceFace(card, kanaOnly = false, AppPreferences(), revealed = true, showReading = false)
        assertEquals("おちゃ", face.reading)
        assertEquals("ocha", face.romaji)
        assertEquals("noun", face.partOfSpeech)
        assertEquals(listOf("tea" to "noun"), face.senses)
        assertEquals(1L, face.example?.id)
    }

    @Test
    fun readingModeDropsTheOtherScript() {
        val kana = practiceFace(
            card,
            kanaOnly = false,
            AppPreferences(reading = ReadingMode.KANA),
            revealed = true,
            showReading = false,
        )
        assertEquals("おちゃ", kana.reading)
        assertNull(kana.romaji)
        val romaji = practiceFace(
            card,
            kanaOnly = false,
            AppPreferences(reading = ReadingMode.ROMAJI),
            revealed = true,
            showReading = false,
        )
        assertNull(romaji.reading)
        assertEquals("ocha", romaji.romaji)
    }

    @Test
    fun kanaOnlyHeadwordUsesTheReading() {
        assertEquals(
            "おちゃ",
            displayedHeadword("お茶", "おちゃ", kanaOnly = true, KanaHeadword.PREFER_KANA),
        )
        assertEquals(
            "お茶",
            displayedHeadword("お茶", "おちゃ", kanaOnly = true, KanaHeadword.PREFER_KANJI),
        )
    }

    @Test
    fun englishPromptAnswersWithJapanese() {
        val hidden = practiceFace(
            card,
            kanaOnly = false,
            AppPreferences(language = StudyLanguage.ENGLISH),
            revealed = false,
            showReading = true,
        )
        assertEquals("tea", hidden.prompt)
        assertNull(hidden.reading)
        val shown = practiceFace(
            card,
            kanaOnly = false,
            AppPreferences(language = StudyLanguage.ENGLISH),
            revealed = true,
            showReading = false,
        )
        assertEquals("tea", shown.prompt)
        assertEquals("お茶", shown.answerJapanese)
        assertEquals("おちゃ", shown.reading)
        assertEquals("ocha", shown.romaji)
    }
}
