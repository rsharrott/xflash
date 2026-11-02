package com.japaneseinaflash.app.ui

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.intl.LocaleList
import org.junit.Assert.assertEquals
import org.junit.Test

class JapaneseTextTest {
    @Test
    fun headwordStyleRequestsJapaneseGlyphs() {
        val style = TextStyle.Default.withJapaneseGlyphs()
        assertEquals(LocaleList(JapaneseGlyphLanguage), style.localeList)
    }
}
