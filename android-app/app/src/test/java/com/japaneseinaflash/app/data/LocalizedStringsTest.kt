package com.japaneseinaflash.app.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class LocalizedStringsTest {
    @Test
    fun japaneseResourcesCoverEveryDefaultString() {
        val english = resourceNames("values")
        val japanese = resourceNames("values-ja")
        assertEquals(english, japanese)
        assertTrue(english.strings.contains("search_too_long"))
        assertTrue(japanese.strings.contains("app_name"))
    }

    @Test
    fun perAppLanguageListsEnglishAndJapanese() {
        val manifest = sourceFile("src/main/AndroidManifest.xml").readText()
        assertTrue(manifest.contains("android:localeConfig=\"@xml/locales_config\""))
        val locales = sourceFile("src/main/res/xml/locales_config.xml").readText()
        assertTrue(locales.contains("android:name=\"en\""))
        assertTrue(locales.contains("android:name=\"ja\""))
    }

    private data class Names(val strings: Set<String>, val plurals: Set<String>)

    private fun resourceNames(folder: String): Names {
        val xml = sourceFile("src/main/res/$folder/strings.xml").readText()
        val strings = Regex("<string name=\"([^\"]+)\"").findAll(xml).map { it.groupValues[1] }.toSet()
        val plurals = Regex("<plurals name=\"([^\"]+)\"").findAll(xml).map { it.groupValues[1] }.toSet()
        assertTrue(strings.isNotEmpty())
        return Names(strings, plurals)
    }

    private fun sourceFile(relative: String): File {
        val direct = File(relative)
        if (direct.isFile) return direct
        val fromApp = File("app/$relative")
        if (fromApp.isFile) return fromApp
        error("Could not find $relative from ${File(".").absolutePath}")
    }
}
