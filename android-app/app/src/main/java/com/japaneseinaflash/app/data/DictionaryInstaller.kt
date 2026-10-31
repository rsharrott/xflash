package com.japaneseinaflash.app.data

import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream
import java.util.concurrent.CancellationException

/**
 * Copies the bundled databases out of assets, the way iOS copies `jFlash.db`
 * into Documents on first launch and then attaches the read-only plugins.
 *
 * The user database is copied only when it is missing, so a later launch does
 * not wipe anything written into it. CARD, FTS, and EX are copied again when
 * the asset manifest stamp changes. That stamp is a hash of the database
 * bytes, not the schema version "2.0". [beforeCopy] runs once, before the
 * first byte of a launch that actually needs to copy, so the caller can refuse
 * when there is not enough free space.
 *
 * Each copy is flushed with [syncPartial] before it is renamed into place, and
 * its length has to match the manifest. [opening] tries to open what was
 * installed and, on failure, deletes the read-only copies and the stamp and
 * copies them once more.
 */
class DictionaryInstaller(
    private val directory: File,
    private val openAsset: (String) -> InputStream,
    private val beforeCopy: () -> Unit = {},
    private val syncPartial: (FileOutputStream, File) -> Unit = { output, _ -> output.fd.sync() },
) {
    fun install(): InstalledDictionary {
        if (!directory.isDirectory && !directory.mkdirs()) {
            throw IOException("Could not create ${directory.path}")
        }
        val manifest = parseAssetManifest(
            openAsset(DictionaryFiles.MANIFEST).bufferedReader().use { it.readText() },
        )
        var notified = false
        fun copying(name: String, dest: File) {
            if (!notified) {
                beforeCopy()
                notified = true
            }
            val expected = manifest.sizes[name]
                ?: throw IOException("Manifest has no size for $name")
            copyAsset(name, dest, expected)
        }

        val user = File(directory, DictionaryFiles.USER_DB)
        if (!user.isFile) {
            copying(DictionaryFiles.USER_DB, user)
        }

        val plugins = DictionaryFiles.PLUGINS.map { File(directory, it) }
        val stamp = File(directory, DictionaryFiles.STAMP)
        val stampMatches = stamp.isFile && stamp.readText().trim() == manifest.stamp
        val pluginsReady = plugins.all { file ->
            val expected = manifest.sizes[file.name]
            file.isFile && expected != null && file.length() == expected
        }
        if (!stampMatches || !pluginsReady) {
            plugins.forEach { dest ->
                copying(dest.name, dest)
                dest.setReadOnly()
            }
            writeSynced(stamp, manifest.stamp)
        }

        return InstalledDictionary(
            userDatabase = user,
            cardDatabase = File(directory, DictionaryFiles.CARD_DB),
            ftsDatabase = File(directory, DictionaryFiles.FTS_DB),
            exampleDatabase = File(directory, DictionaryFiles.EX_DB),
        )
    }

    /**
     * Opens the installed databases. If that fails, the read-only copies and
     * the stamp are removed and the copy runs once more. A second failure is
     * returned to the caller. Cancellation is not treated as a bad copy.
     */
    fun <T> opening(open: (InstalledDictionary) -> T): T {
        val first = install()
        try {
            return open(first)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            discardReadOnlyCopies()
            val second = install()
            return open(second)
        }
    }

    fun discardReadOnlyCopies() {
        DictionaryFiles.PLUGINS.forEach { name ->
            val file = File(directory, name)
            if (!file.exists()) return@forEach
            file.setWritable(true)
            if (!file.delete()) throw IOException("Could not remove $name")
        }
        val stamp = File(directory, DictionaryFiles.STAMP)
        if (stamp.exists() && !stamp.delete()) {
            throw IOException("Could not remove ${DictionaryFiles.STAMP}")
        }
    }

    private fun copyAsset(name: String, dest: File, expectedSize: Long) {
        val partial = File(directory, "$name.partial")
        if (partial.exists()) {
            partial.setWritable(true)
            if (!partial.delete()) {
                throw IOException("Could not remove a partial copy of $name")
            }
        }
        try {
            openAsset(name).use { input ->
                FileOutputStream(partial).use { output ->
                    input.copyTo(output, bufferSize = COPY_BUFFER)
                    output.flush()
                    syncPartial(output, dest)
                }
            }
            if (partial.length() != expectedSize) {
                throw IOException("Asset $name was ${partial.length()} bytes, expected $expectedSize")
            }
            if (dest.exists()) {
                dest.setWritable(true)
                if (!dest.delete()) throw IOException("Could not replace $name")
            }
            if (!partial.renameTo(dest)) throw IOException("Could not move $name into place")
        } catch (e: Exception) {
            partial.delete()
            throw e
        }
    }

    private fun writeSynced(file: File, text: String) {
        FileOutputStream(file).use { output ->
            output.write(text.toByteArray(Charsets.UTF_8))
            output.flush()
            syncPartial(output, file)
        }
    }

    private companion object {
        const val COPY_BUFFER = 1024 * 1024
    }
}
