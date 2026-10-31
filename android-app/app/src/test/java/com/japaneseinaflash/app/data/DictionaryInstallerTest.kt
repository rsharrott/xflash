package com.japaneseinaflash.app.data

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.File
import java.nio.file.Files

class DictionaryInstallerTest {
    private val assets = mapOf(
        DictionaryFiles.USER_DB to "user-db".toByteArray(),
        DictionaryFiles.CARD_DB to "card-db".toByteArray(),
        DictionaryFiles.FTS_DB to "fts-db".toByteArray(),
        DictionaryFiles.EX_DB to "ex-db".toByteArray(),
    )

    @Test
    fun firstInstallCopiesEveryDatabaseAndASecondInstallLeavesTheUserFileAlone() {
        val dir = tempDir()
        var copies = 0
        val installer = installer(dir) { copies++ }

        val installed = installer.install()
        assertEquals(1, copies)
        assertArrayEquals(assets.getValue(DictionaryFiles.USER_DB), installed.userDatabase.readBytes())
        assertArrayEquals(assets.getValue(DictionaryFiles.CARD_DB), installed.cardDatabase.readBytes())
        assertFalse(installed.cardDatabase.canWrite())
        assertFalse(installed.ftsDatabase.canWrite())
        assertFalse(installed.exampleDatabase.canWrite())
        assertTrue(installed.userDatabase.canWrite())
        assertEquals(
            DictionaryFiles.PLUGIN_VERSION,
            File(dir, DictionaryFiles.STAMP).readText().trim(),
        )

        installed.userDatabase.writeBytes("progress".toByteArray())
        installed.cardDatabase.setWritable(true)
        installed.cardDatabase.writeBytes("stale".toByteArray())
        installer.install()
        assertEquals(1, copies)
        assertArrayEquals("progress".toByteArray(), installed.userDatabase.readBytes())
        assertArrayEquals("stale".toByteArray(), installed.cardDatabase.readBytes())
    }

    @Test
    fun aNewPluginVersionReplacesTheReadOnlyDatabasesOnly() {
        val dir = tempDir()
        val installer = installer(dir)
        val installed = installer.install()
        installed.userDatabase.writeBytes("progress".toByteArray())
        File(dir, DictionaryFiles.STAMP).writeText("1.0")
        installed.cardDatabase.setWritable(true)
        installed.cardDatabase.writeBytes("stale".toByteArray())

        installer.install()
        assertArrayEquals("progress".toByteArray(), installed.userDatabase.readBytes())
        assertArrayEquals(assets.getValue(DictionaryFiles.CARD_DB), installed.cardDatabase.readBytes())
        assertEquals(DictionaryFiles.PLUGIN_VERSION, File(dir, DictionaryFiles.STAMP).readText().trim())
    }

    @Test
    fun aFailedCopyDoesNotLeaveTheUserDatabaseBehind() {
        val dir = tempDir()
        val broken = DictionaryInstaller(dir, { throw java.io.IOException("no asset") })
        val error = runCatching { broken.install() }.exceptionOrNull()
        assertTrue(error is java.io.IOException)
        assertFalse(File(dir, DictionaryFiles.USER_DB).exists())
        assertFalse(File(dir, DictionaryFiles.USER_DB + ".partial").exists())
    }

    private fun installer(dir: File, beforeCopy: () -> Unit = {}): DictionaryInstaller {
        return DictionaryInstaller(
            directory = dir,
            openAsset = { name ->
                ByteArrayInputStream(assets[name] ?: error("unexpected asset $name"))
            },
            beforeCopy = beforeCopy,
        )
    }

    private fun tempDir(): File = Files.createTempDirectory("jflash-install").toFile()
}
