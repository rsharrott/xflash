package com.japaneseinaflash.app.data

/**
 * `dictionary-manifest.txt` in the APK assets:
 *
 * ```
 * stamp <sha256 hex of the database file names and bytes>
 * size <asset name> <byte length>
 * ```
 *
 * The Gradle copy task writes this. [DictionaryInstaller] compares `stamp` with
 * the file next to the installed copies and checks each copied file's length.
 */
data class AssetManifest(
    val stamp: String,
    val sizes: Map<String, Long>,
)

fun parseAssetManifest(text: String): AssetManifest {
    var stamp: String? = null
    val sizes = linkedMapOf<String, Long>()
    for (raw in text.lineSequence()) {
        val line = raw.trim()
        if (line.isEmpty() || line.startsWith("#")) continue
        val parts = line.split(' ')
        when (parts.firstOrNull()) {
            "stamp" -> {
                require(parts.size == 2 && parts[1].isNotEmpty()) { "Bad manifest line: $line" }
                stamp = parts[1]
            }
            "size" -> {
                require(parts.size == 3) { "Bad manifest line: $line" }
                sizes[parts[1]] = parts[2].toLong()
            }
            else -> throw IllegalArgumentException("Bad manifest line: $line")
        }
    }
    return AssetManifest(
        stamp = stamp ?: throw IllegalArgumentException("Manifest has no stamp"),
        sizes = sizes,
    )
}

fun formatAssetManifest(stamp: String, sizes: Map<String, Long>): String = buildString {
    append("stamp ").append(stamp).append('\n')
    sizes.toSortedMap().forEach { (name, size) ->
        append("size ").append(name).append(' ').append(size).append('\n')
    }
}
