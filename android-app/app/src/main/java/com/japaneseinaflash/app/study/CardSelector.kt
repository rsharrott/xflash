package com.japaneseinaflash.app.study

import kotlin.math.pow

/**
 * The iOS practice-card math (`PracticeCardSelectorMath.h`), kept as plain
 * functions so the level choice can be tested without a database.
 */
fun unseenExponent(frequency: Int): Double {
    val clamped = frequency.coerceIn(1, 4)
    return 4.0 / clamped.toDouble()
}

fun probabilityOfUnseen(
    cardsSeen: Int,
    totalCards: Int,
    levelTimesCount: Int,
    studyingCount: Int,
    maxCards: Int,
    frequency: Int,
): Double {
    if (cardsSeen >= totalCards || maxCards <= 0 || studyingCount >= maxCards) return 0.0
    if (cardsSeen <= 0) return 1.0
    val mean = levelTimesCount.toDouble() / cardsSeen.toDouble()
    val known = ((mean - 1.0) / 4.0).coerceIn(0.0, 1.0)
    var unseen = known.pow(unseenExponent(frequency))
    val roomLeft = (maxCards - cardsSeen).coerceAtLeast(0)
    val room = roomLeft.toDouble().pow(0.25) / maxCards.toDouble().pow(0.25)
    unseen += (1.0 - unseen) * room
    return unseen.coerceIn(0.0, 1.0)
}

/**
 * Roulette over levels. [levels] is indexed by level, including unseen at 0.
 * [numLevels] is 5, or 4 when Learned is hidden. [random] is in `[0, 1)`.
 * Returns -1 when every considered level is empty.
 */
fun pickCardLevel(levels: IntArray, numLevels: Int, unseenProbability: Double, random: Double): Int {
    val maxLevel = numLevels.coerceIn(0, LEARNED_LEVEL)
    val unseen = if (unseenProbability.isNaN()) 0.0 else unseenProbability.coerceIn(0.0, 1.0)
    var weightTotal = 0L
    for (level in 1..maxLevel) {
        weightTotal += levels.getOrElse(level) { 0 }.coerceAtLeast(0).toLong() * (maxLevel - level + 1)
    }
    if (weightTotal > 0) {
        var cumulative = 0.0
        for (level in 1..maxLevel) {
            val count = levels.getOrElse(level) { 0 }.coerceAtLeast(0)
            val weight = count.toDouble() * (maxLevel - level + 1) / weightTotal.toDouble()
            cumulative += (1.0 - unseen) * weight
            if (count > 0 && cumulative > random) return level
        }
    }
    if (levels.getOrElse(0) { 0 } > 0) return 0
    for (level in maxLevel downTo 1) {
        if (levels.getOrElse(level) { 0 } > 0) return level
    }
    return -1
}

/** Sum of (count at level * level) for levels 1..[numLevels], the mean's numerator. */
fun levelTimesCount(levels: IntArray, numLevels: Int): Int {
    var sum = 0
    for (level in 1..numLevels.coerceIn(0, LEARNED_LEVEL)) {
        sum += levels.getOrElse(level) { 0 }.coerceAtLeast(0) * level
    }
    return sum
}

fun seenCount(levels: IntArray, numLevels: Int): Int {
    var sum = 0
    for (level in 1..numLevels.coerceIn(0, LEARNED_LEVEL)) {
        sum += levels.getOrElse(level) { 0 }.coerceAtLeast(0)
    }
    return sum
}

/** 4 when Learned cards are hidden, otherwise 5. An all-learned set is handled by the caller. */
fun selectableLevelCount(levels: IntArray, hideLearned: Boolean): Int =
    if (hideLearned) LEARNED_LEVEL - 1 else LEARNED_LEVEL
