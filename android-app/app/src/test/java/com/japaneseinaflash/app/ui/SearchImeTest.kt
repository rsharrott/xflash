@file:OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)

package com.japaneseinaflash.app.ui

import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import androidx.compose.ui.platform.PlatformTextInputMethodRequest
import androidx.compose.ui.platform.PlatformTextInputSession
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.lang.reflect.Proxy

class SearchImeTest {
    @Test
    fun searchFieldRefusesTheLandscapeExtractEditor() {
        val info = EditorInfo()
        info.imeOptions = EditorInfo.IME_ACTION_SEARCH
        info.applySearchImeFlags()
        assertEquals(
            EditorInfo.IME_ACTION_SEARCH or EditorInfo.IME_FLAG_NO_EXTRACT_UI or EditorInfo.IME_FLAG_NO_FULLSCREEN,
            info.imeOptions,
        )
        assertTrue(info.imeOptions and EditorInfo.IME_FLAG_NO_EXTRACT_UI != 0)
        assertTrue(info.imeOptions and EditorInfo.IME_FLAG_NO_FULLSCREEN != 0)
        assertTrue(info.inputType and EditorInfo.TYPE_TEXT_FLAG_NO_SUGGESTIONS != 0)
        assertEquals(
            EditorInfo.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD,
            info.inputType and EditorInfo.TYPE_MASK_VARIATION,
        )
        assertTrue(info.inputType and EditorInfo.TYPE_TEXT_FLAG_AUTO_CORRECT == 0)
        assertEquals(EditorInfo.TYPE_CLASS_TEXT, info.inputType and EditorInfo.TYPE_MASK_CLASS)
    }

    @Test
    fun suggestionsStayOffWhenComposeAskedForAutocorrect() {
        val info = EditorInfo()
        info.inputType = EditorInfo.TYPE_CLASS_TEXT or
            EditorInfo.TYPE_TEXT_FLAG_CAP_SENTENCES or
            EditorInfo.TYPE_TEXT_FLAG_AUTO_CORRECT or
            EditorInfo.TYPE_TEXT_FLAG_AUTO_COMPLETE
        info.applySearchImeFlags()
        assertTrue(info.inputType and EditorInfo.TYPE_TEXT_FLAG_NO_SUGGESTIONS != 0)
        assertTrue(info.inputType and EditorInfo.TYPE_TEXT_FLAG_AUTO_CORRECT == 0)
        assertTrue(info.inputType and EditorInfo.TYPE_TEXT_FLAG_AUTO_COMPLETE == 0)
        assertTrue(info.inputType and EditorInfo.TYPE_TEXT_FLAG_CAP_SENTENCES != 0)
        assertEquals(
            EditorInfo.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD,
            info.inputType and EditorInfo.TYPE_MASK_VARIATION,
        )
    }

    @Test
    fun enterRunsASearch() {
        assertTrue(isSearchEnter(KeyEvent.KEYCODE_ENTER))
        assertTrue(isSearchEnter(KeyEvent.KEYCODE_NUMPAD_ENTER))
        assertTrue(!isSearchEnter(KeyEvent.KEYCODE_SEARCH))
        assertTrue(!isSearchEnter(KeyEvent.KEYCODE_SPACE))
    }

    @Test
    fun theSearchFieldInterceptorAppliesThoseFlags() {
        val info = EditorInfo()
        info.imeOptions = EditorInfo.IME_ACTION_SEARCH
        val connection = Proxy.newProxyInstance(
            InputConnection::class.java.classLoader,
            arrayOf(InputConnection::class.java),
        ) { _, _, _ -> null } as InputConnection
        val request = PlatformTextInputMethodRequest { out ->
            out.imeOptions = info.imeOptions
            connection
        }
        val connected = CompletableDeferred<Unit>()
        val session = object : PlatformTextInputSession {
            override val view: View get() = error("the search field does not read the view")

            override suspend fun startInputMethod(request: PlatformTextInputMethodRequest): Nothing {
                request.createInputConnection(info)
                connected.complete(Unit)
                kotlinx.coroutines.awaitCancellation()
            }
        }
        runBlocking {
            val job = launch {
                searchFieldImeInterceptor.interceptStartInputMethod(request, session)
            }
            withTimeout(5_000) { connected.await() }
            job.cancel()
        }
        assertTrue(info.imeOptions and EditorInfo.IME_FLAG_NO_EXTRACT_UI != 0)
        assertTrue(info.imeOptions and EditorInfo.IME_FLAG_NO_FULLSCREEN != 0)
        assertEquals(EditorInfo.IME_ACTION_SEARCH, info.imeOptions and EditorInfo.IME_MASK_ACTION)
        assertTrue(info.inputType and EditorInfo.TYPE_TEXT_FLAG_NO_SUGGESTIONS != 0)
        assertEquals(
            EditorInfo.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD,
            info.inputType and EditorInfo.TYPE_MASK_VARIATION,
        )
    }
}
