package com.japaneseinaflash.app.data

/**
 * Asset names of the jFlash 2.0 databases. The Gradle copy task reads the same
 * names from `dictionary-sources.properties`; a unit test keeps the two lists aligned.
 *
 * Attach names match the iOS plugin keys (`CARD_DB`, `FTS_DB`, `EX_DB`), so an
 * unqualified table name resolves to the attached file. The user template has
 * none of those tables.
 */
object DictionaryFiles {
    const val PLUGIN_VERSION = "2.0"
    const val USER_DB = "jFlash.db"
    const val CARD_DB = "jFlash-CARD-2.0.db"
    const val FTS_DB = "jFlash-FTS-2.0.db"
    const val EX_DB = "jFlash-EX-2.0.db"
    const val STAMP = "dictionary-plugins.version"

    const val SCHEMA_CARD = "CARD_DB"
    const val SCHEMA_FTS = "FTS_DB"
    const val SCHEMA_EX = "EX_DB"

    val PLUGINS = listOf(CARD_DB, FTS_DB, EX_DB)
    val SCHEMAS = setOf(SCHEMA_CARD, SCHEMA_FTS, SCHEMA_EX)
}
