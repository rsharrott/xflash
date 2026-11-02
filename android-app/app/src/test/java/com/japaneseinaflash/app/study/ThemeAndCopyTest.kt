package com.japaneseinaflash.app.study

import androidx.compose.ui.graphics.Color
import com.japaneseinaflash.app.theme.TokenColors
import com.japaneseinaflash.app.ui.theme.studyColors
import com.japaneseinaflash.app.theme.contrastRatio
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class ThemeAndCopyTest {
    @Test
    fun darkChromeIsPaperOnlyAndFollowsTheSystemByDefault() {
        assertTrue(usesDarkChrome(StudyTheme.PAPER, DarkMode.FOLLOW_SYSTEM, systemDark = true))
        assertFalse(usesDarkChrome(StudyTheme.PAPER, DarkMode.FOLLOW_SYSTEM, systemDark = false))
        assertFalse(usesDarkChrome(StudyTheme.PAPER, DarkMode.OFF, systemDark = true))
        assertTrue(usesDarkChrome(StudyTheme.PAPER, DarkMode.ON, systemDark = false))
        StudyTheme.entries.filter { it != StudyTheme.PAPER }.forEach { theme ->
            assertFalse(usesDarkChrome(theme, DarkMode.ON, systemDark = true))
        }
        assertEquals(DarkMode.FOLLOW_SYSTEM, AppPreferences().darkMode)
        assertEquals(StudyTheme.PAPER, AppPreferences().theme)
    }

    @Test
    fun showAnswerMeetsTheContrastTable() {
        assertTrue(contrastRatio(TokenColors.WHITE, TokenColors.FIRE) >= 4.5)
        assertTrue(contrastRatio(TokenColors.FIRE, TokenColors.PAPER_2) >= 3.0)
        assertTrue(contrastRatio(TokenColors.WHITE, TokenColors.WATER_DEEP) >= 4.5)
        assertTrue(contrastRatio(TokenColors.WATER_DEEP, TokenColors.PAPER_2) >= 3.0)
        assertTrue(contrastRatio(TokenColors.WHITE, TokenColors.KIMONO_AI) >= 4.5)
        assertTrue(contrastRatio(TokenColors.WHITE, TokenColors.KUTANI_AUBERGINE) >= 4.5)
        assertTrue(contrastRatio(TokenColors.WHITE, TokenColors.FIRE_DARK) >= 4.5)
        assertTrue(contrastRatio(TokenColors.FIRE_DARK, TokenColors.INK) >= 3.0)
        assertEquals(0xFF1356A7.toInt(), TokenColors.WATER)
        assertFalse(TokenColors.WATER == 0xFF134685.toInt())
    }

    @Test
    fun wrongStaysALightFill() {
        val lightFills = listOf(
            TokenColors.PAPER_RAISED,
            TokenColors.FIRE_WASH,
            TokenColors.WATER_WASH,
            TokenColors.KIMONO_WASH,
            TokenColors.KUTANI_WASH,
            TokenColors.DARK_SURFACE,
        )
        assertTrue(lightFills.none { it == TokenColors.FIRE || it == TokenColors.WRONG_INK })
    }

    @Test
    fun colorsXmlDropsTheOldPaletteAndTokensStayInCode() {
        val xml = source("src/main/res/values/colors.xml").readText()
        listOf("F6F1E7", "FFFBF4", "1E1A16", "5C5348", "6B2D3C", "F3E1D4", "3D4F3A", "C9BBA8").forEach {
            assertFalse(xml.contains(it, ignoreCase = true))
        }
        assertTrue(xml.contains("E7E1D6", ignoreCase = true))
        val tokens = source("src/main/java/com/japaneseinaflash/app/theme/TokenColors.kt").readText()
        listOf("FBF8F3", "C01B00", "1356A7", "0E407D", "1F3558", "553366", "29241F", "F2826E", "D8381C").forEach {
            assertTrue(tokens.contains(it, ignoreCase = true))
        }
        assertEquals(TokenColors.FIRE, 0xFFC01B00.toInt())
        assertEquals(TokenColors.WATER_DEEP, 0xFF0E407D.toInt())
        assertEquals(TokenColors.KIMONO_AI, 0xFF1F3558.toInt())
        assertEquals(TokenColors.KUTANI_AUBERGINE, 0xFF553366.toInt())
        assertEquals(TokenColors.FIRE_DEEP, 0xFF8E1400.toInt())
        val paper = studyColors(StudyTheme.PAPER, dark = false)
        assertEquals(Color(TokenColors.FIRE), paper.bar)
        assertEquals(Color(TokenColors.FIRE), paper.toggleLabel)
        assertEquals(Color(TokenColors.WATER_DEEP), studyColors(StudyTheme.WATER, dark = false).bar)
    }

    @Test
    fun inAppCopyAvoidsSchedulingClaimsAndStudyCounts() {
        val xml = source("src/main/res/values/strings.xml").readText().lowercase()
        listOf("reminder", "offline", "srs", "streak", "spaced", "schedule", "browse mode").forEach {
            assertFalse(xml.contains(it))
        }
    }

    @Test
    fun catalogOrderMatchesIos() {
        assertTrue(compareSetNames("Beginner 1 (≈N5) Full Set", "Beginner 1 (≈N5) 01") < 0)
        assertTrue(compareSetNames("Beginner 1 (≈N5) 02", "Beginner 1 (≈N5) 01") > 0)
        assertTrue(compareGroups(1, "Survival Japanese", 1, "Recommended") > 0)
        assertTrue(compareGroups(1, "Recommended", 0, "Common Words") < 0)
        assertTrue(userOwnsMembership(0, editable = false))
        assertFalse(userOwnsMembership(95, editable = false))
        assertTrue(opensAsSearch("Common Words"))
        assertFalse(opensAsSearch("Nouns"))
    }

    private fun source(relative: String): File {
        val direct = File(relative)
        if (direct.isFile) return direct
        val fromApp = File("app/$relative")
        if (fromApp.isFile) return fromApp
        error(relative)
    }
}
