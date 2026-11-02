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
        idleUntil { opens == 1 }
        assertEquals(1, opens)
        store.update { it.copy(theme = StudyTheme.FIRE, darkMode = DarkMode.ON) }
        idleUntil { true }
        assertEquals(1, opens)
        store.update { it.copy(tagId = 2L) }
        idleUntil { opens >= 2 }
        assertTrue(opens >= 2)
    }

    private fun idleUntil(ready: () -> Boolean) {
        val deadline = System.currentTimeMillis() + 5_000
        while (!ready() && System.currentTimeMillis() < deadline) {
            shadowOf(android.os.Looper.getMainLooper()).idle()
            Thread.sleep(20)
        }
    }
}
