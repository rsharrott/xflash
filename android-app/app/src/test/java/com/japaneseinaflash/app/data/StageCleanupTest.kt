package com.japaneseinaflash.app.data

import android.database.sqlite.SQLiteDatabase
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.nio.file.Files

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class StageCleanupTest {
    @Test
    fun aThrowingDropIsAddedToTheOriginalException() {
        val file = File(Files.createTempDirectory("jflash-drop").toFile(), "stage.db")
        val db = SQLiteDatabase.openOrCreateDatabase(file, null)
        db.execSQL("CREATE TABLE search_token_stage (id INTEGER)")
        db.close()
        val primary = IllegalStateException("search failed")
        dropSearchStage(db, primary)
        assertEquals(1, primary.suppressed.size)
        assertTrue(primary.suppressed[0] is Exception)
    }
}
