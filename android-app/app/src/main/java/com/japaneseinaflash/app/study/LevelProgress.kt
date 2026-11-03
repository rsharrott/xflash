package com.japaneseinaflash.app.study

/** Level 0 is unseen. 1 Studying, 2 Right 1x, 3 Right 2x, 4 Right 3x, 5 Learned. */
const val LEVEL_COUNT = 6
const val LEARNED_LEVEL = 5
const val STUDYING_LEVEL = 1

fun emptyLevels(): IntArray = IntArray(LEVEL_COUNT)

/** Next level after Wrong or Right. Unseen and right lands on Right 1x. Wrong returns to Studying. */
fun nextLevel(level: Int, right: Boolean): Int {
    if (!right) return STUDYING_LEVEL
    return when {
        level <= 0 -> 2
        level >= LEARNED_LEVEL -> LEARNED_LEVEL
        else -> level + 1
    }
}

fun learnedCount(levels: IntArray): Int =
    levels.getOrElse(LEARNED_LEVEL) { 0 }.coerceAtLeast(0)

fun setTotal(levels: IntArray): Int = levels.sum().coerceAtLeast(0)

fun learnedFraction(learned: Int, total: Int): Float {
    if (total <= 0 || learned <= 0) return 0f
    if (learned >= total) return 1f
    return learned.toFloat() / total.toFloat()
}

fun isSetLearned(learned: Int, total: Int): Boolean = total > 0 && learned >= total

/**
 * Visible pill. [complete] is "Set learned ✓"; [inProgress] is "%d / %d learned"
 * with learned then total.
 */
fun learnedPillText(
    learned: Int,
    total: Int,
    inProgress: (Int, Int) -> String,
    complete: String,
): String {
    if (isSetLearned(learned, total)) return complete
    return inProgress(learned.coerceAtLeast(0), total.coerceAtLeast(0))
}

/**
 * Bars are cumulative over cards that have been seen.
 * Column i (1–5) is cards at level >= i, divided by the seen total.
 */
fun cumulativeBarFractions(levels: IntArray): FloatArray {
    val seen = (1 until LEVEL_COUNT).sumOf { levels.getOrElse(it) { 0 }.coerceAtLeast(0) }
    val fractions = FloatArray(5)
    if (seen <= 0) return fractions
    var atOrAbove = seen
    for (column in 1..5) {
        if (column > 1) atOrAbove -= levels.getOrElse(column - 1) { 0 }.coerceAtLeast(0)
        fractions[column - 1] = (atOrAbove.coerceAtLeast(0).toFloat() / seen.toFloat()).coerceIn(0f, 1f)
    }
    return fractions
}

/** "Studying 6, Right 1x 8, …". A blank name is skipped. */
fun levelStripSummary(names: List<String>, counts: List<Int>): String =
    names.mapIndexedNotNull { index, name ->
        if (name.isBlank()) return@mapIndexedNotNull null
        val count = counts.getOrElse(index) { 0 }
        if (count.toString().isEmpty()) name else "$name $count"
    }.joinToString(", ")
