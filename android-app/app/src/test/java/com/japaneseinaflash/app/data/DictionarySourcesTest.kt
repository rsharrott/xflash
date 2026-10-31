package com.japaneseinaflash.app.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class DictionarySourcesTest {
    @Test
    fun manifestMatchesTheAssetNamesAndPointsAtRealSqliteFiles() {
        val sources = listedSources()
        val user = sources.filter { it.role == "user" }
        assertEquals(listOf(DictionaryFiles.USER_DB), user.map { it.assetName })
        assertEquals(DictionaryFiles.PLUGINS, sources.filter { it.role == "plugin" }.map { it.assetName })
        sources.forEach { source ->
            assertTrue("${source.file} is missing", source.file.isFile)
            sqliteHeader(source.file)
            assertEquals(source.assetName, source.file.name)
        }
        assertTrue(user.single().file.length() > 100_000)
        sources.filter { it.role == "plugin" }.forEach { source ->
            assertTrue(source.file.length() > 1_000_000)
        }
    }

    @Test
    fun pluginVersionStampMatchesTheBundledDatabases() {
        listedSources().filter { it.role == "plugin" }.forEach { source ->
            val version = sqlite3(source.file, "SELECT version FROM version;").trim()
            assertEquals(source.assetName, DictionaryFiles.PLUGIN_VERSION, version)
        }
    }

    @Test
    fun userTemplateDoesNotShadowAttachedTables() {
        val user = listedSources().single { it.role == "user" }.file
        val tables = sqlite3(user, "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;")
            .lines()
            .map { it.trim() }
            .filter { it.isNotEmpty() }
        val attached = listOf(
            "cards",
            "cards_html",
            "cards_search_content",
            "sentences",
            "card_sentence_link",
        )
        assertTrue(tables.intersect(attached).isEmpty())
        assertTrue(tables.contains("version"))
    }

    @Test
    fun databasesAreNotCopiedIntoTheAppTree() {
        val root = findUp("dictionary-sources.properties").parentFile
        val vendored = ArrayList<File>()
        root.walkTopDown().onEnter { dir ->
            dir.name != "build" && dir.name != ".gradle" && dir.name != ".kotlin"
        }.forEach { file ->
            if (file.isFile && file.extension == "db") vendored.add(file)
        }
        assertTrue(vendored.toString(), vendored.isEmpty())
    }
}
