package com.japaneseinaflash.app.data

import java.io.File

internal fun findUp(name: String): File {
    var dir = File(System.getProperty("user.dir") ?: ".")
    repeat(8) {
        val candidate = File(dir, name)
        if (candidate.isFile) return candidate
        dir = dir.parentFile ?: return@repeat
    }
    error("Could not find $name starting from ${System.getProperty("user.dir")}")
}

internal data class ListedSource(val role: String, val assetName: String, val file: File)

internal fun listedSources(): List<ListedSource> {
    val manifest = findUp("dictionary-sources.properties")
    val root = manifest.parentFile
    return manifest.readLines().mapNotNull { raw ->
        val line = raw.substringBefore("#").trim()
        if (line.isEmpty()) return@mapNotNull null
        val parts = line.split("=", limit = 3)
        check(parts.size == 3) { raw }
        ListedSource(parts[0].trim(), parts[1].trim(), File(root, parts[2].trim()).canonicalFile)
    }
}

internal fun sqliteHeader(file: File) {
    val header = ByteArray(16)
    file.inputStream().use { input ->
        check(input.read(header) == 16)
    }
    check(String(header, Charsets.ISO_8859_1) == "SQLite format 3\u0000") { file.path }
}

internal fun sqlite3(database: File, sql: String): String {
    val program = System.getenv("SQLITE3") ?: "sqlite3"
    val process = ProcessBuilder(program, database.absolutePath, sql)
        .redirectErrorStream(true)
        .start()
    val text = process.inputStream.bufferedReader().readText()
    val code = process.waitFor()
    check(code == 0) { "sqlite3 exited $code\n$text" }
    return text
}
