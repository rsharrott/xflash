package com.japaneseinaflash.app.theme

/**
 * Colour tokens shared by the five study themes and dark Paper.
 * Values are opaque ARGB. Compose colours are built from these so tests can
 * check the same numbers the screens paint.
 */
object TokenColors {
    const val PAPER = 0xFFFBF8F3.toInt()
    const val PAPER_2 = 0xFFE7E1D6.toInt()
    const val PAPER_RAISED = 0xFFFFFDF9.toInt()
    const val PAPER_BUTTON = 0xFFEDE6DA.toInt()
    const val INK = 0xFF1D1A16.toInt()
    const val INK_2 = 0xFF3A352E.toInt()
    const val MUTED = 0xFF6F665B.toInt()
    const val LINE = 0xFFCFC6B8.toInt()
    const val FADED = 0xFF9A8F80.toInt()
    const val WHITE = 0xFFFFFFFF.toInt()

    const val FIRE = 0xFFC01B00.toInt()
    const val FIRE_DEEP = 0xFF8E1400.toInt()
    const val FIRE_DARK = 0xFFD8381C.toInt()
    const val FIRE_WASH = 0xFFF6E7E1.toInt()
    const val YELLOW = 0xFFFFD60A.toInt()
    const val YELLOW_INK = 0xFF3A2A00.toInt()

    const val WATER = 0xFF1356A7.toInt()
    const val WATER_DEEP = 0xFF0E407D.toInt()
    const val WATER_WASH = 0xFFE3ECF7.toInt()

    const val KIMONO_AI = 0xFF1F3558.toInt()
    const val KIMONO_KAKI = 0xFFEEA57A.toInt()
    const val KIMONO_WASH = 0xFFFBE6D8.toInt()

    const val KUTANI_AUBERGINE = 0xFF553366.toInt()
    const val KUTANI_GREEN = 0xFF1E4A3A.toInt()
    const val KUTANI_OCHRE = 0xFFE2B13A.toInt()
    const val KUTANI_WASH = 0xFFE3EDE5.toInt()

    const val DARK_SURFACE = 0xFF29241F.toInt()
    const val DARK_TRACK = 0xFF4A433B.toInt()
    const val DARK_ACCENT = 0xFFF2826E.toInt()

    const val WRONG_INK = 0xFF7E1400.toInt()
    const val WRONG_FILL_DARK_BADGE = 0xFFF9DCD5.toInt()
    const val RIGHT_FILL = 0xFFD3EEDC.toInt()
    const val RIGHT_INK = 0xFF0B5A2C.toInt()

    /** Composited toggle pairs (label on fill) measured for AA. */
    const val TOGGLE_PAPER_FILL = 0xFFE0DDD7.toInt()
    const val TOGGLE_FIRE_FILL = 0xFF9E3524.toInt()
    const val TOGGLE_FIRE_LABEL = 0xFFF7EFED.toInt()
    const val TOGGLE_WATER_FILL = 0xFF346EB3.toInt()
    const val TOGGLE_WATER_LABEL = 0xFFEFF3F9.toInt()
    const val TOGGLE_KIMONO_FILL = 0xFFD19575.toInt()
    const val TOGGLE_KUTANI_FILL = 0xFF3E6356.toInt()
    const val TOGGLE_KUTANI_LABEL = 0xFFF0F3F1.toInt()
    const val TOGGLE_DARK_FILL = 0xFF423D38.toInt()

    const val ROMAJI_FIRE = 0xFFF1E3E0.toInt()
    const val ROMAJI_WATER = 0xFFE3EBF4.toInt()
    const val ROMAJI_KUTANI = 0xFFE4E9E7.toInt()
}

/** WCAG contrast ratio. Channels are 0–255. */
fun contrastRatio(foreground: Int, background: Int): Double {
    val lighter = maxOf(relativeLuminance(foreground), relativeLuminance(background))
    val darker = minOf(relativeLuminance(foreground), relativeLuminance(background))
    return (lighter + 0.05) / (darker + 0.05)
}

private fun relativeLuminance(argb: Int): Double {
    fun channel(value: Int): Double {
        val s = value / 255.0
        return if (s <= 0.04045) s / 12.92 else Math.pow((s + 0.055) / 1.055, 2.4)
    }
    val r = channel((argb shr 16) and 0xFF)
    val g = channel((argb shr 8) and 0xFF)
    val b = channel(argb and 0xFF)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
}
