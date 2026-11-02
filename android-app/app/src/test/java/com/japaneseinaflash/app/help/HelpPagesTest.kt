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
        assertFalse(HelpPages.shown.any { it.contains("browse") || it.contains("share") || it.contains("integration") })
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
