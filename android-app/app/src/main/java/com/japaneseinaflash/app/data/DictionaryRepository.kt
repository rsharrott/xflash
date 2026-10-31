package com.japaneseinaflash.app.data

import android.database.SQLException
import android.database.sqlite.SQLiteDatabase
import java.io.Closeable
import java.io.File

class DictionaryRepository internal constructor(
    private val db: SQLiteDatabase,
) : Closeable {
    private val lock = Any()

    fun search(raw: String, limit: Int = SearchQuery.DEFAULT_LIMIT): List<CardSummary> = synchronized(lock) {
        val prepared = SearchQuery.prepare(raw, limit) ?: return emptyList()
        val ids = mutableListOf<Long>()
        try {
            db.rawQuery(prepared.sql, arrayOf(prepared.matchArgument, prepared.limit.toString())).use { cursor ->
                while (cursor.moveToNext()) {
                    ids.add(cursor.getLong(0))
                }
            }
        } catch (e: SQLException) {
            if (isMatchSyntaxError(e)) return emptyList()
            throw e
        }
        if (ids.isEmpty()) return emptyList()
        val byId = linkedMapOf<Long, CardSummary>()
        val args = ids.map { it.toString() }.toTypedArray()
        db.rawQuery(DictionarySql.summaries(ids.size), args).use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getLong(cursor.getColumnIndexOrThrow("card_id"))
                byId[id] = CardSummary(
                    id = id,
                    headword = cursor.string("headword"),
                    reading = cursor.string("reading"),
                    meaning = parseMeaning(cursor.getString(cursor.getColumnIndexOrThrow("meaning")))
                        .firstOrNull()
                        ?.text
                        .orEmpty(),
                )
            }
        }
        ids.mapNotNull { byId[it] }
    }

    fun loadCard(cardId: Long): CardDetail? = synchronized(lock) {
        val base = db.rawQuery(DictionarySql.CARD, arrayOf(cardId.toString())).use { cursor ->
            if (!cursor.moveToFirst()) return null
            CardDetail(
                id = cursor.getLong(0),
                headword = cursor.stringAt(1),
                reading = cursor.stringAt(2),
                romaji = cursor.stringAt(3),
                senses = parseMeaning(cursor.getString(4)),
            )
        }
        val sentences = mutableListOf<ExampleSentence>()
        db.rawQuery(DictionarySql.SENTENCES, arrayOf(cardId.toString())).use { cursor ->
            while (cursor.moveToNext()) {
                sentences.add(
                    ExampleSentence(
                        id = cursor.getLong(0),
                        japanese = cursor.stringAt(1),
                        english = cursor.stringAt(2),
                    ),
                )
            }
        }
        base.copy(sentences = sentences)
    }

    fun databaseVersion(schema: String): String? = synchronized(lock) {
        db.rawQuery(DictionarySql.version(schema), null).use { cursor ->
            if (!cursor.moveToFirst()) null else cursor.getString(0)
        }
    }

    override fun close() = synchronized(lock) {
        db.close()
    }

    companion object {
        fun open(installed: InstalledDictionary): DictionaryRepository =
            DictionaryRepository(openDictionary(installed))
    }
}

internal fun openDictionary(installed: InstalledDictionary): SQLiteDatabase {
    val db = SQLiteDatabase.openDatabase(
        installed.userDatabase.absolutePath,
        null,
        SQLiteDatabase.OPEN_READWRITE or SQLiteDatabase.NO_LOCALIZED_COLLATORS,
    )
    try {
        attachReadOnly(db, DictionaryFiles.SCHEMA_CARD, installed.cardDatabase)
        attachReadOnly(db, DictionaryFiles.SCHEMA_FTS, installed.ftsDatabase)
        attachReadOnly(db, DictionaryFiles.SCHEMA_EX, installed.exampleDatabase)
    } catch (e: RuntimeException) {
        db.close()
        throw e
    }
    return db
}

/**
 * CARD, FTS, and EX are dictionary data. SQLite's `file:…?mode=ro` URI is not
 * usable here: Robolectric's SQLite (code 14) refuses it, and a URI that only
 * works on some devices is a bad default. The file is marked read-only instead,
 * then attached by path, which is what the iOS app does. A quote or newline in
 * the path is refused; the path is one of our own files, never user input.
 */
internal fun attachReadOnly(db: SQLiteDatabase, schema: String, file: File) {
    require(schema in DictionaryFiles.SCHEMAS)
    val path = file.canonicalPath
    require(path.none { it == '\'' || it == '\n' || it == '\r' }) {
        "Refusing to attach $path"
    }
    file.setReadOnly()
    db.execSQL("ATTACH DATABASE '$path' AS $schema")
}

private fun isMatchSyntaxError(error: SQLException): Boolean {
    val message = error.message.orEmpty()
    return message.contains("MATCH", ignoreCase = true) || message.contains("fts", ignoreCase = true)
}

private fun android.database.Cursor.string(column: String): String =
    getString(getColumnIndexOrThrow(column)).orEmpty()

private fun android.database.Cursor.stringAt(index: Int): String = getString(index).orEmpty()
