package com.japaneseinaflash.app.ui

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.intl.LocaleList

/** Language used so CJK headwords keep Japanese glyph forms in any UI locale. */
internal const val JapaneseGlyphLanguage = "ja"

internal fun TextStyle.withJapaneseGlyphs(): TextStyle =
    copy(localeList = LocaleList(JapaneseGlyphLanguage))
