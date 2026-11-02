@file:OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)

package com.japaneseinaflash.app.ui

import android.view.KeyEvent
import android.view.inputmethod.EditorInfo
import androidx.compose.ui.platform.PlatformTextInputInterceptor
import androidx.compose.ui.platform.PlatformTextInputMethodRequest

/**
 * Landscape IMEs otherwise open a fullscreen extract editor. That editor
 * shrinks the app's field to a sliver, swallows the search key, and then
 * restarts the input connection, which shows the keyboard again. These flags
 * keep the field inline so the Search action reaches it.
 *
 * Suggestions are turned off with [EditorInfo.TYPE_TEXT_FLAG_NO_SUGGESTIONS]
 * and by clearing autocorrect. The visible-password variation is not set:
 * Gboard and Google Japanese Input treat it as a password field and lock the
 * keyboard to the alphabet, so a search for ねこ cannot be composed.
 * The field's `hintLocales` are Japanese, then English, so the IME is not
 * left guessing.
 */
internal fun EditorInfo.applySearchImeFlags() {
    imeOptions = imeOptions or EditorInfo.IME_FLAG_NO_EXTRACT_UI or EditorInfo.IME_FLAG_NO_FULLSCREEN
    val keptFlags = inputType and EditorInfo.TYPE_MASK_FLAGS and
        EditorInfo.TYPE_TEXT_FLAG_AUTO_CORRECT.inv() and
        EditorInfo.TYPE_TEXT_FLAG_AUTO_COMPLETE.inv()
    inputType = EditorInfo.TYPE_CLASS_TEXT or
        EditorInfo.TYPE_TEXT_FLAG_NO_SUGGESTIONS or
        keptFlags
}

/** Hardware Enter and the numeric-pad Enter, as opposed to the IME search key. */
internal fun isSearchEnter(keyCode: Int): Boolean =
    keyCode == KeyEvent.KEYCODE_ENTER || keyCode == KeyEvent.KEYCODE_NUMPAD_ENTER

internal val searchFieldImeInterceptor = PlatformTextInputInterceptor { request, next ->
    next.startInputMethod(PlatformTextInputMethodRequest { outAttributes ->
        val connection = request.createInputConnection(outAttributes)
        outAttributes.applySearchImeFlags()
        connection
    })
}
