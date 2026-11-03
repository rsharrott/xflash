package com.japaneseinaflash.app.study

import com.japaneseinaflash.app.data.CardDetail
import com.japaneseinaflash.app.data.ExampleSentence

/**
 * The card face. Reading stays off the question until Show reading or Show answer.
 * An English prompt's answer is the Japanese word.
 */
data class PracticeFace(
    val cardId: Long,
    val prompt: String,
    val promptIsJapanese: Boolean,
    val answerJapanese: String?,
    val reading: String?,
    val romaji: String?,
    val senses: List<Pair<String, String?>>,
    val partOfSpeech: String?,
    val example: ExampleSentence?,
)

fun practiceFace(
    card: CardDetail,
    kanaOnly: Boolean,
    preferences: AppPreferences,
    revealed: Boolean,
    showReading: Boolean,
): PracticeFace {
    val headword = displayedHeadword(card.headword, card.reading, kanaOnly, preferences.kanaHeadword)
    val englishPrompt = preferences.language == StudyLanguage.ENGLISH
    val meaning = card.senses.firstOrNull()?.text?.takeIf { it.isNotBlank() }
    val prompt = if (englishPrompt) meaning ?: headword else headword
    val showKana = !englishPrompt && (revealed || showReading)
    val (reading, romaji) = if (showKana || (englishPrompt && revealed)) {
        readingLines(preferences.reading, card.reading, card.romaji, skipKana = headword)
    } else {
        null to null
    }
    return PracticeFace(
        cardId = card.id,
        prompt = prompt,
        promptIsJapanese = !englishPrompt,
        answerJapanese = if (englishPrompt && revealed) headword else null,
        reading = reading,
        romaji = romaji,
        senses = if (revealed && !englishPrompt) card.senses.map { it.text to it.partOfSpeech } else emptyList(),
        partOfSpeech = if (revealed) card.senses.firstOrNull()?.partOfSpeech?.takeIf { it.isNotBlank() } else null,
        example = if (revealed) card.sentences.firstOrNull() else null,
    )
}

fun displayedHeadword(headword: String, reading: String, kanaOnly: Boolean, kanaHeadword: KanaHeadword): String =
    if (kanaOnly && kanaHeadword == KanaHeadword.PREFER_KANA && reading.isNotBlank()) reading else headword

private fun readingLines(
    mode: ReadingMode,
    reading: String,
    romaji: String,
    skipKana: String,
): Pair<String?, String?> {
    val kana = reading.takeIf { it.isNotBlank() && it != skipKana }
    val latin = romaji.takeIf { it.isNotBlank() }
    return when (mode) {
        ReadingMode.KANA -> kana to null
        ReadingMode.ROMAJI -> null to latin
        ReadingMode.BOTH -> kana to latin
    }
}
