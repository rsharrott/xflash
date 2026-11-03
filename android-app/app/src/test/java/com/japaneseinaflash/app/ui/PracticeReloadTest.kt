package com.japaneseinaflash.app.ui

import android.app.Application
import androidx.test.core.app.ApplicationProvider
import com.japaneseinaflash.app.data.AppPreferencesStore
import com.japaneseinaflash.app.study.DarkMode
import com.japaneseinaflash.app.study.StudyTheme
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class PracticeReloadTest {
    @Test
    fun aThemeChangeDoesNotDealANewCard() = runBlocking {
        val app = ApplicationProvider.getApplicationContext<Application>()
        val store = AppPreferencesStore(app)
        var opens = 0
        PracticeViewModel(
            app,
            openRepository = {
                opens += 1
                error("practice does not need a dictionary for this count")
            },
            phase = kotlinx.coroutines.flow.flowOf(Phase.Ready),
            store = store,
        )
        store.update { it.copy(theme = StudyTheme.PAPER, darkMode = DarkMode.OFF, tagId = 11L) }
        idleUntil { opens >= 1 }
        val dealt = opens
        store.update { it.copy(theme = StudyTheme.FIRE, darkMode = DarkMode.ON) }
        repeat(15) {
            shadowOf(android.os.Looper.getMainLooper()).idle()
            Thread.sleep(20)
        }
        assertEquals(dealt, opens)
        store.update { it.copy(tagId = 12L) }
        idleUntil { opens > dealt }
        assertTrue(opens > dealt)
    }

    private fun idleUntil(ready: () -> Boolean) {
        val deadline = System.currentTimeMillis() + 5_000
        while (!ready() && System.currentTimeMillis() < deadline) {
            shadowOf(android.os.Looper.getMainLooper()).idle()
            Thread.sleep(20)
        }
    }
}
