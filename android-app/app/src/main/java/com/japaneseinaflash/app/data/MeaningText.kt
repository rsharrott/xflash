package com.japaneseinaflash.app.data

/**
 * Card meanings are stored as the 1.x HTML shape: an `<ol>` of `<li>` senses,
 * each with an optional `<dfn>` part of speech, or a single plain string.
 */
data class Sense(
    val text: String,
    val partOfSpeech: String?,
)

private val liPattern = Regex("(?is)<li>(.*?)</li>")
private val dfnPattern = Regex("(?is)<dfn>(.*?)</dfn>")
private val tagPattern = Regex("<[^>]+>")
private val hexEntity = Regex("&#x([0-9A-Fa-f]+);")
private val decEntity = Regex("&#([0-9]+);")
private val whitespace = Regex("\\s+")

fun parseMeaning(html: String?): List<Sense> {
    if (html.isNullOrBlank()) return emptyList()
    val blocks = liPattern.findAll(html).map { it.groupValues[1] }.toList().ifEmpty { listOf(html) }
    return blocks.mapNotNull { block ->
        val partOfSpeech = dfnPattern.findAll(block)
            .map { cleanInline(it.groupValues[1]) }
            .filter { it.isNotEmpty() }
            .joinToString(", ")
            .ifEmpty { null }
        val text = cleanInline(dfnPattern.replace(block, " "))
        if (text.isEmpty()) null else Sense(text, partOfSpeech)
    }
}

private fun cleanInline(value: String): String = unescape(stripTags(value)).replace(whitespace, " ").trim()

private fun stripTags(value: String): String = tagPattern.replace(value, " ")

private fun unescape(value: String): String {
    val withNumeric = decEntity.replace(
        hexEntity.replace(value) { decodeCodePoint(it.groupValues[1].toInt(16)) },
    ) { decodeCodePoint(it.groupValues[1].toInt()) }
    return withNumeric
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&apos;", "'")
        .replace("&amp;", "&")
}

private fun decodeCodePoint(code: Int): String {
    if (code <= 0 || code > 0x10FFFF) return ""
    return String(Character.toChars(code))
}
