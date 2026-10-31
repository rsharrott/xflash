package com.japaneseinaflash.app.data

import java.io.File
import java.io.IOException
import java.io.InputStream

/**
 * Copies the bundled databases out of assets, the way iOS copies `jFlash.db`
 * into Documents on first launch and then attaches the read-only plugins.
 *
 * The user database is copied only when it is missing, so a later launch does
 * not wipe anything written into it. CARD, FTS, and EX are copied again when
 * [DictionaryFiles.PLUGIN_VERSION] changes. [beforeCopy] runs once, before the
 * first byte of a launch that actually needs to copy, so the caller can refuse
 * when there is not enough free space.
 */
class DictionaryInstaller(
    private val directory: File,
    private val openAsset: (String) -> InputStream,
    private val beforeCopy: () -> Unit = {},
) {
    fun install(): InstalledDictionary {
        if (!directory.isDirectory && !directory.mkdirs()) {
            throw IOException("Could not create ${directory.path}")
        }
        var notified = false
        fun copying(name: String, dest: File) {
            if (!notified) {
                beforeCopy()
                notified = true
            }
            copyAsset(name, dest)
        }

        val user = File(directory, DictionaryFiles.USER_DB)
        if (!user.isFile) {
            copying(DictionaryFiles.USER_DB, user)
        }

        val plugins = DictionaryFiles.PLUGINS.map { File(directory, it) }
        val stamp = File(directory, DictionaryFiles.STAMP)
        val stampMatches = stamp.isFile && stamp.readText().trim() == DictionaryFiles.PLUGIN_VERSION
        val pluginsReady = plugins.all { it.isFile && it.length() > 0L }
        if (!stampMatches || !pluginsReady) {
            plugins.forEach { dest ->
                copying(dest.name, dest)
                dest.setReadOnly()
            }
            stamp.writeText(DictionaryFiles.PLUGIN_VERSION)
        }

        return InstalledDictionary(
            userDatabase = user,
            cardDatabase = File(directory, DictionaryFiles.CARD_DB),
            ftsDatabase = File(directory, DictionaryFiles.FTS_DB),
            exampleDatabase = File(directory, DictionaryFiles.EX_DB),
        )
    }

    private fun copyAsset(name: String, dest: File) {
        val partial = File(directory, "$name.partial")
        if (partial.exists()) {
            partial.setWritable(true)
            if (!partial.delete()) {
                throw IOException("Could not remove a partial copy of $name")
            }
        }
        try {
            openAsset(name).use { input ->
                partial.outputStream().use { output ->
                    input.copyTo(output, bufferSize = COPY_BUFFER)
                }
            }
            if (partial.length() == 0L) {
                throw IOException("Asset $name was empty")
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

    private companion object {
        const val COPY_BUFFER = 1024 * 1024
    }
}
