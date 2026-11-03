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
        val ids = try {
            rankedIds(prepared)
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

    private fun rankedIds(prepared: PreparedSearch): List<Long> {
        val match = prepared.matchArgument
        val exact = prepared.exactTerm
        if (SearchRank.isPrefixQuery(match, exact)) {
            return readIds(DictionarySql.PREFIX, arrayOf(exact, match, prepared.limit.toString()))
        }
        if (SearchRank.isSingleToken(match, exact)) {
            return tokenIds(exact, prepared.limit)
        }
        return readIds(prepared.sql, prepared.arguments.toTypedArray())
    }

    /**
     * Ranks a single token from one stored copy of each hit.
     *
     * A single SELECT rebuilds the gloss on every sort comparison. The stage
     * table stores it once. It is TEMP, so it belongs to this connection, and
     * [search] holds [lock]. The work is wrapped in a transaction: SQLite only
     * has to write `temp`, and the read-only dictionary attachments stay
     * read-only. Android's [SQLiteDatabase.beginTransaction] is exclusive and
     * some builds then reject the lock, so that rejection falls back to the
     * repository lock.
     */
    private fun tokenIds(term: String, limit: Int): List<Long> {
        val transaction = startStageTransaction()
        var primary: Throwable? = null
        try {
            db.execSQL(DictionarySql.TOKEN_STAGE_DROP)
            db.execSQL(DictionarySql.TOKEN_STAGE, arrayOf<Any>(term, term))
            val ids = readIds(DictionarySql.TOKEN_RANKED, arrayOf(limit.toString()))
            if (transaction) db.setTransactionSuccessful()
            return ids
        } catch (thrown: Throwable) {
            primary = thrown
            throw thrown
        } finally {
            if (transaction) {
                try {
                    db.endTransaction()
                } catch (end: Exception) {
                    if (primary != null) primary.addSuppressed(end) else throw end
                }
            }
            dropSearchStage(db, primary)
        }
    }

    private fun startStageTransaction(): Boolean = try {
        db.beginTransactionNonExclusive()
        true
    } catch (_: SQLException) {
        false
    }

    private fun readIds(sql: String, args: Array<String>): List<Long> =
        readRows(sql, args) { it.getLong(0) }

    private fun <T> readRows(sql: String, args: Array<String>, read: (android.database.Cursor) -> T): List<T> {
        val rows = mutableListOf<T>()
        db.rawQuery(sql, args).use { cursor ->
            while (cursor.moveToNext()) rows.add(read(cursor))
        }
        return rows
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

    internal fun <T> query(sql: String, args: Array<String>, read: (android.database.Cursor) -> T): List<T> =
        synchronized(lock) { readRows(sql, args, read) }

    internal fun exec(sql: String, vararg args: Any) = synchronized(lock) {
        db.execSQL(sql, args)
    }

    internal fun <T> transaction(block: () -> T): T = synchronized(lock) {
        db.beginTransaction()
        try {
            val value = block()
            db.setTransactionSuccessful()
            value
        } finally {
            db.endTransaction()
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
/** A failed cleanup must not replace the search error that caused it. */
internal fun dropSearchStage(db: SQLiteDatabase, primary: Throwable?) {
    try {
        db.execSQL(DictionarySql.TOKEN_STAGE_DROP)
    } catch (drop: Exception) {
        if (primary != null) primary.addSuppressed(drop) else throw drop
    }
}

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
    return message.contains("malformed MATCH", ignoreCase = true)
}

private fun android.database.Cursor.string(column: String): String =
    getString(getColumnIndexOrThrow(column)).orEmpty()

private fun android.database.Cursor.stringAt(index: Int): String = getString(index).orEmpty()
