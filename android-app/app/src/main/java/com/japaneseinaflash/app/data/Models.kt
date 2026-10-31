package com.japaneseinaflash.app.data

import java.io.File

data class InstalledDictionary(
    val userDatabase: File,
    val cardDatabase: File,
    val ftsDatabase: File,
    val exampleDatabase: File,
)

data class CardSummary(
    val id: Long,
    val headword: String,
    val reading: String,
    val meaning: String,
)

data class ExampleSentence(
    val id: Long,
    val japanese: String,
    val english: String,
)

data class CardDetail(
    val id: Long,
    val headword: String,
    val reading: String,
    val romaji: String,
    val senses: List<Sense>,
    val sentences: List<ExampleSentence> = emptyList(),
)

data class DataVersions(
    val cards: String,
    val search: String,
    val examples: String,
)
