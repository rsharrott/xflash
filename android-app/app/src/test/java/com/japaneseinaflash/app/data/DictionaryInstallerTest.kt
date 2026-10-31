package com.japaneseinaflash.app.data

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.file.Files
import java.util.concurrent.CancellationException

class DictionaryInstallerTest {
    private val assets = mapOf(
        DictionaryFiles.USER_DB to "user-db".toByteArray(),
        DictionaryFiles.CARD_DB to "card-db".toByteArray(),
        DictionaryFiles.FTS_DB to "fts-db".toByteArray(),
        DictionaryFiles.EX_DB to "ex-db".toByteArray(),
    )

    @Test
    fun manifestRoundTrip() {
        val text = formatAssetManifest("abc", mapOf("b.db" to 2L, "a.db" to 1L))
        val parsed = parseAssetManifest(text)
        assertEquals("abc", parsed.stamp)
        assertEquals(mapOf("a.db" to 1L, "b.db" to 2L), parsed.sizes)
    }

    @Test
    fun firstInstallCopiesEveryDatabaseAndASecondInstallLeavesTheUserFileAlone() {
        val dir = tempDir()
        var copies = 0
        val installer = installer(dir, stamp = "hash-a", beforeCopy = { copies++ })

        val installed = installer.install()
        assertEquals(1, copies)
        assertArrayEquals(assets.getValue(DictionaryFiles.USER_DB), installed.userDatabase.readBytes())
        assertArrayEquals(assets.getValue(DictionaryFiles.CARD_DB), installed.cardDatabase.readBytes())
        assertFalse(installed.cardDatabase.canWrite())
        assertFalse(installed.ftsDatabase.canWrite())
        assertFalse(installed.exampleDatabase.canWrite())
        assertTrue(installed.userDatabase.canWrite())
        assertEquals("hash-a", File(dir, DictionaryFiles.STAMP).readText().trim())

        installed.userDatabase.writeBytes("progress".toByteArray())
        installed.cardDatabase.setWritable(true)
        installed.cardDatabase.writeBytes(ByteArray(assets.getValue(DictionaryFiles.CARD_DB).size) { 7 })
        installer.install()
        assertEquals(1, copies)
        assertArrayEquals("progress".toByteArray(), installed.userDatabase.readBytes())
        assertArrayEquals(ByteArray(assets.getValue(DictionaryFiles.CARD_DB).size) { 7 }, installed.cardDatabase.readBytes())
    }

    @Test
    fun aChangedAssetStampRecopiesPluginsAndKeepsTheUserDatabase() {
        val dir = tempDir()
        val installed = installer(dir, stamp = "hash-old").install()
        installed.userDatabase.writeBytes("progress".toByteArray())
        installed.cardDatabase.setWritable(true)
        installed.cardDatabase.writeBytes(ByteArray(assets.getValue(DictionaryFiles.CARD_DB).size) { 9 })

        installer(dir, stamp = "hash-new").install()

        assertArrayEquals("progress".toByteArray(), installed.userDatabase.readBytes())
        assertArrayEquals(assets.getValue(DictionaryFiles.CARD_DB), installed.cardDatabase.readBytes())
        assertEquals("hash-new", File(dir, DictionaryFiles.STAMP).readText().trim())
        assertFalse(installed.cardDatabase.canWrite())
    }

    @Test
    fun syncRunsBeforeTheDestinationExistsAndAShortCopyIsDiscarded() {
        val dir = tempDir()
        val synced = mutableListOf<String>()
        val installer = installer(dir, stamp = "hash-a", sync = { output, dest ->
            if (dest.name != DictionaryFiles.STAMP) {
                assertFalse(dest.name, dest.exists())
            }
            assertTrue(output.channel.size() > 0)
            synced += dest.name
            output.fd.sync()
        })
        installer.install()
        assertEquals(
            listOf(
                DictionaryFiles.USER_DB,
                DictionaryFiles.CARD_DB,
                DictionaryFiles.FTS_DB,
                DictionaryFiles.EX_DB,
                DictionaryFiles.STAMP,
            ),
            synced,
        )

        val shortDir = tempDir()
        val short = DictionaryInstaller(
            directory = shortDir,
            openAsset = { name ->
                val bytes = if (name == DictionaryFiles.USER_DB) {
                    byteArrayOf(1)
                } else {
                    assetBytes(name, "hash-a")
                }
                ByteArrayInputStream(bytes)
            },
        )
        val error = runCatching { short.install() }.exceptionOrNull()
        assertTrue(error is IOException)
        assertFalse(File(shortDir, DictionaryFiles.USER_DB).exists())
        assertFalse(File(shortDir, DictionaryFiles.USER_DB + ".partial").exists())
    }

    @Test
    fun aFailedOpenDeletesPluginsAndCopiesThemOnceMore() {
        val dir = tempDir()
        val installer = installer(dir, stamp = "hash-a")
        val installed = installer.install()
        installed.userDatabase.writeBytes("progress".toByteArray())
        val cardBytes = assets.getValue(DictionaryFiles.CARD_DB)
        installed.cardDatabase.setWritable(true)
        installed.cardDatabase.writeBytes(ByteArray(cardBytes.size) { 0 })

        var opens = 0
        val result = installer.opening { files ->
            opens++
            if (opens == 1) {
                assertArrayEquals(ByteArray(cardBytes.size) { 0 }, files.cardDatabase.readBytes())
                throw IOException("cannot open")
            }
            assertArrayEquals(cardBytes, files.cardDatabase.readBytes())
            "opened"
        }
        assertEquals("opened", result)
        assertEquals(2, opens)
        assertArrayEquals("progress".toByteArray(), installed.userDatabase.readBytes())
        assertEquals("hash-a", File(dir, DictionaryFiles.STAMP).readText().trim())
    }

    @Test
    fun cancellationDoesNotDiscardTheInstalledCopies() {
        val dir = tempDir()
        val installer = installer(dir, stamp = "hash-a")
        val installed = installer.install()
        val error = runCatching {
            installer.opening<Unit> { throw CancellationException("stop") }
        }.exceptionOrNull()
        assertTrue(error is CancellationException)
        assertArrayEquals(assets.getValue(DictionaryFiles.CARD_DB), installed.cardDatabase.readBytes())
        assertTrue(File(dir, DictionaryFiles.STAMP).isFile)
    }

    @Test
    fun aFailedCopyDoesNotLeaveTheUserDatabaseBehind() {
        val dir = tempDir()
        val broken = DictionaryInstaller(dir, { throw IOException("no asset") })
        val error = runCatching { broken.install() }.exceptionOrNull()
        assertTrue(error is IOException)
        assertFalse(File(dir, DictionaryFiles.USER_DB).exists())
        assertFalse(File(dir, DictionaryFiles.USER_DB + ".partial").exists())
    }

    private fun installer(
        dir: File,
        stamp: String,
        beforeCopy: () -> Unit = {},
        sync: (FileOutputStream, File) -> Unit = { output, _ -> output.fd.sync() },
    ): DictionaryInstaller {
        return DictionaryInstaller(
            directory = dir,
            openAsset = { name -> ByteArrayInputStream(assetBytes(name, stamp)) },
            beforeCopy = beforeCopy,
            syncPartial = sync,
        )
    }

    private fun assetBytes(name: String, stamp: String): ByteArray {
        if (name == DictionaryFiles.MANIFEST) {
            return formatAssetManifest(stamp, assets.mapValues { it.value.size.toLong() }).toByteArray()
        }
        return assets[name] ?: error("unexpected asset $name")
    }

    private fun tempDir(): File = Files.createTempDirectory("jflash-install").toFile()
}
