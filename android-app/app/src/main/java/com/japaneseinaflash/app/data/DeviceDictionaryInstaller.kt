package com.japaneseinaflash.app.data

import android.content.Context
import android.os.StatFs
import java.io.IOException

internal object DeviceDictionaryInstaller {
    /** Uncompressed dictionary plus the largest file while it is still a partial copy. */
    const val REQUIRED_FREE_BYTES = 180L * 1024 * 1024

    fun install(context: Context): InstalledDictionary = installer(context).install()

    fun open(context: Context): DictionaryRepository {
        return installer(context).opening { installed -> DictionaryRepository.open(installed) }
    }

    private fun installer(context: Context): DictionaryInstaller {
        val dir = context.getDatabasePath(DictionaryFiles.USER_DB).parentFile
            ?: throw IOException("No database directory")
        if (!dir.isDirectory && !dir.mkdirs()) {
            throw IOException("Could not create ${dir.path}")
        }
        return DictionaryInstaller(
            directory = dir,
            openAsset = { name -> context.assets.open(name) },
            beforeCopy = {
                val available = StatFs(dir.absolutePath).availableBytes
                if (available < REQUIRED_FREE_BYTES) {
                    throw IOException("Not enough free space to copy the dictionary")
                }
            },
        )
    }
}
