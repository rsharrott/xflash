package com.japaneseinaflash.app.ui

import android.app.Application
import android.database.sqlite.SQLiteDatabase
import androidx.lifecycle.SavedStateHandle
import androidx.test.core.app.ApplicationProvider
import com.japaneseinaflash.app.data.DictionaryFiles
import com.japaneseinaflash.app.data.DictionaryRepository
import com.japaneseinaflash.app.data.InstalledDictionary
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.nio.file.Files

@OptIn(ExperimentalCoroutinesApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class SearchSpinnerTest {
    @After
    fun resetDispatcher() {
        Dispatchers.resetMain()
    }

    @Test
    fun backingUpToAFinishedQueryClearsTheSpinner() = runTest {
        Dispatchers.setMain(StandardTestDispatcher(testScheduler))
        val hold = CompletableDeferred<Unit>()
        val vm = DictionaryViewModel(
            ApplicationProvider.getApplicationContext(),
            SavedStateHandle(),
            openInstalled = { repository() },
            runQuery = { _, query ->
                if (query.endsWith("?")) hold.await()
                emptyList()
            },
        )
        waitUntilReady(vm)
        runCurrent()

        vm.onQueryChange("co")
        advanceTimeBy(300)
        runCurrent()
        assertFalse(vm.state.value.searching)

        vm.onQueryChange("co?")
        advanceTimeBy(300)
        runCurrent()
        assertTrue(vm.state.value.searching)

        vm.onQueryChange("co")
        advanceTimeBy(300)
        runCurrent()
        assertEquals("co", vm.state.value.query)
        assertFalse(vm.state.value.searching)
    }

    private fun waitUntilReady(vm: DictionaryViewModel) {
        val deadline = System.currentTimeMillis() + 5_000
        while (vm.state.value.phase == Phase.Preparing && System.currentTimeMillis() < deadline) {
            Thread.sleep(20)
        }
        assertEquals(Phase.Ready, vm.state.value.phase)
    }

    private fun repository(): DictionaryRepository {
        val dir = Files.createTempDirectory("jflash-spinner").toFile()
        listOf(DictionaryFiles.USER_DB, DictionaryFiles.CARD_DB, DictionaryFiles.FTS_DB, DictionaryFiles.EX_DB).forEach { name ->
            val db = SQLiteDatabase.openOrCreateDatabase(File(dir, name), null)
            try {
                db.execSQL("CREATE TABLE version (version TEXT)")
                db.execSQL("INSERT INTO version VALUES ('2.0')")
            } finally {
                db.close()
            }
        }
        return DictionaryRepository.open(
            InstalledDictionary(
                File(dir, DictionaryFiles.USER_DB),
                File(dir, DictionaryFiles.CARD_DB),
                File(dir, DictionaryFiles.FTS_DB),
                File(dir, DictionaryFiles.EX_DB),
            ),
        )
    }
}
