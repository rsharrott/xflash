package com.japaneseinaflash.app.study

/** iOS `APP_THEME` values. */
enum class StudyTheme(val key: String) {
    PAPER("PAPER"),
    FIRE("FIRE"),
    WATER("WATER"),
    KIMONO("KIMONO"),
    KUTANI("KUTANI"),
    ;

    companion object {
        fun fromKey(key: String?): StudyTheme =
            entries.firstOrNull { it.key == key } ?: PAPER
    }
}

enum class DarkMode(val key: String) {
    FOLLOW_SYSTEM("FOLLOW_SYSTEM"),
    OFF("OFF"),
    ON("ON"),
    ;

    companion object {
        fun fromKey(key: String?): DarkMode =
            entries.firstOrNull { it.key == key } ?: FOLLOW_SYSTEM
    }
}

enum class ReadingMode(val key: String) {
    KANA("KANA"),
    ROMAJI("ROMAJI"),
    BOTH("BOTH"),
    ;

    companion object {
        fun fromKey(key: String?): ReadingMode =
            entries.firstOrNull { it.key == key } ?: BOTH
    }
}

enum class StudyLanguage(val key: String) {
    JAPANESE("JPN"),
    ENGLISH("ENG"),
    ;

    companion object {
        fun fromKey(key: String?): StudyLanguage =
            entries.firstOrNull { it.key == key } ?: JAPANESE
    }
}

enum class KanaHeadword(val key: String) {
    PREFER_KANA("ON"),
    PREFER_KANJI("OFF"),
    ;

    companion object {
        fun fromKey(key: String?): KanaHeadword =
            entries.firstOrNull { it.key == key } ?: PREFER_KANA
    }
}

enum class Difficulty(val key: Int) {
    EASY(0),
    MEDIUM(1),
    HARD(2),
    CUSTOM(3),
    ;

    companion object {
        fun fromKey(key: Int): Difficulty =
            entries.firstOrNull { it.key == key } ?: MEDIUM
    }
}

data class Pool(
    val maxCards: Int,
    val frequency: Int,
)

data class AppPreferences(
    val theme: StudyTheme = StudyTheme.PAPER,
    val darkMode: DarkMode = DarkMode.FOLLOW_SYSTEM,
    val reading: ReadingMode = ReadingMode.BOTH,
    val language: StudyLanguage = StudyLanguage.JAPANESE,
    val kanaHeadword: KanaHeadword = KanaHeadword.PREFER_KANA,
    val difficulty: Difficulty = Difficulty.MEDIUM,
    val customMax: Int = MEDIUM_POOL,
    val customFrequency: Int = MEDIUM_FREQUENCY,
    val hideLearned: Boolean = false,
    val tagId: Long = DEFAULT_TAG_ID,
    val userId: Long = DEFAULT_USER_ID,
) {
    /** Cards in the study pool, and how often a new card is introduced (1–4). */
    fun pool(): Pool = when (difficulty) {
        Difficulty.EASY -> Pool(EASY_POOL, EASY_FREQUENCY)
        Difficulty.MEDIUM -> Pool(MEDIUM_POOL, MEDIUM_FREQUENCY)
        Difficulty.HARD -> Pool(HARD_POOL, HARD_FREQUENCY)
        Difficulty.CUSTOM -> Pool(
            customMax.coerceIn(MIN_POOL, MAX_POOL),
            customFrequency.coerceIn(MIN_FREQUENCY, MAX_FREQUENCY),
        )
    }

    /** What forces a new card. Reading and theme do not. */
    fun cardKey(): String = listOf(
        tagId,
        userId,
        difficulty,
        customMax,
        customFrequency,
        hideLearned,
    ).joinToString("|")

    companion object {
        const val DEFAULT_TAG_ID = 200L
        const val DEFAULT_USER_ID = 1L
        const val EASY_POOL = 10
        const val EASY_FREQUENCY = 1
        const val MEDIUM_POOL = 30
        const val MEDIUM_FREQUENCY = 2
        const val HARD_POOL = 40
        const val HARD_FREQUENCY = 3
        const val MIN_POOL = 5
        const val MAX_POOL = 50
        const val MIN_FREQUENCY = 1
        const val MAX_FREQUENCY = 4
    }
}

/** Dark chrome is Paper only. Other themes keep the light paper screen. */
fun usesDarkChrome(theme: StudyTheme, mode: DarkMode, systemDark: Boolean): Boolean {
    if (theme != StudyTheme.PAPER) return false
    return when (mode) {
        DarkMode.FOLLOW_SYSTEM -> systemDark
        DarkMode.OFF -> false
        DarkMode.ON -> true
    }
}

/** Only Common Words is too long to list. Nouns and the other groups stay as lists. */
fun opensAsSearch(englishName: String): Boolean = englishName == "Common Words"

const val STARRED_TAG_ID = 0L
const val TOP_OWNER_ID = -1L

fun displayName(name: String, nameJa: String?, japanese: Boolean): String =
    if (japanese && !nameJa.isNullOrBlank()) nameJa else name

/** Full Set before the numbered chunks. The comparison is the English name. */
fun compareSetNames(a: String, b: String): Int {
    val aFull = if (a.endsWith(FULL_SET_SUFFIX)) 0 else 1
    val bFull = if (b.endsWith(FULL_SET_SUFFIX)) 0 else 1
    if (aFull != bFull) return aFull - bFull
    return a.compareTo(b)
}

fun compareGroups(recommendedA: Int, nameA: String, recommendedB: Int, nameB: String): Int {
    val byRecommended = recommendedB.compareTo(recommendedA)
    if (byRecommended != 0) return byRecommended
    return nameA.compareTo(nameB)
}

/** Membership lives on the user database for sets the learner can edit, including Starred. */
fun userOwnsMembership(tagId: Long, editable: Boolean): Boolean =
    tagId == STARRED_TAG_ID || editable

private const val FULL_SET_SUFFIX = " Full Set"
