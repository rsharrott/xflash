package com.japaneseinaflash.app.help

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class HelpPagesTest {
    @Test
    fun shownPagesExistAndLeaveOutTheMissingFeatures() {
        val help = helpDirectory()
        HelpPages.shown.forEach { file ->
            assertTrue(file, File(help, file).isFile)
            assertTrue("ja/$file", File(help, "ja/$file").isFile)
        }
        HelpPages.omitted.forEach { file ->
            assertFalse(HelpPages.shown.contains(file))
            assertTrue(File(help, file).isFile)
        }
        assertFalse(HelpPages.shown.any {
            it.contains("browse") || it.contains("share") || it.contains("integration") || it.contains("corrections")
        })
    }

    @Test
    fun theAndroidCopyDropsIosOnlySectionsAndLeavesTheOriginals() {
        val ios = helpDirectory()
        val original = File(ios, "practice@2x.html").readText()
        assertTrue(original.contains("Tap <strong>Learned</strong>"))
        assertTrue(original.contains("Fix Card"))
        val copied = copiedHelp("practice@2x.html")
        assertFalse(copied.contains("Tap <strong>Learned</strong>"))
        assertFalse(copied.contains("Fix Card"))
        assertFalse(copied.contains("Actions"))
        assertTrue(copied.contains("Practice Mode"))
        assertTrue(copied.contains("<strong>Learned</strong>"))
        val japanese = copiedHelp("ja/practice@2x.html")
        assertFalse(japanese.contains("もう覚えた"))
        assertFalse(japanese.contains("誤りを報告"))
        assertTrue(japanese.contains("練習モード"))
        val sets = copiedHelp("studysets@2x.html")
        assertFalse(sets.contains("Actions"))
        assertTrue(sets.contains("<strong>Search</strong>"))
        val japaneseSets = copiedHelp("ja/studysets@2x.html")
        assertFalse(japaneseSets.contains("アクション"))
        assertTrue(japaneseSets.contains("検索"))
        val css = copiedHelp("help.css")
        assertFalse(css.contains("font: -apple-system-body"))
        assertTrue(css.contains("font-size: 17px"))
        val root = copiedHelpRoot()
        listOf("corrections@2x.html", "browse@2x.html", "share@2x.html", "integration@2x.html").forEach { name ->
            assertFalse(name, File(root, name).exists())
        }
        assertFalse(File(root, "img/share-users-en.png").exists())
        assertFalse(File(root, "img/corrections-fix-card-en.png").exists())
        assertTrue(File(root, "img/practice-progress-bar-en.png").isFile)
    }

    private fun copiedHelp(relative: String): String = File(copiedHelpRoot(), relative).readText()

    private fun copiedHelpRoot(): File {
        val build = File("build")
        val hits = build.walkTopDown()
            .maxDepth(6)
            .filter { it.isFile && it.name == "help.css" && it.parentFile.name == "help" }
            .map { it.parentFile ?: error("help.css has no parent") }
            .toList()
        return hits.firstOrNull() ?: error("Copied help was not under ${build.absolutePath}")
    }

    private fun helpDirectory(): File {
        var dir = File(System.getProperty("user.dir") ?: ".")
        repeat(6) {
            val candidate = File(dir, "jFlash/Assets/JFlash/help")
            if (candidate.isDirectory) return candidate
            dir = dir.parentFile ?: return@repeat
        }
        error("Could not find the bundled help pages")
    }
}
