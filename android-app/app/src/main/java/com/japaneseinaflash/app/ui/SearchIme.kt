@file:OptIn(androidx.compose.ui.ExperimentalComposeUiApi::class)

package com.japaneseinaflash.app.ui

import android.view.inputmethod.EditorInfo
import androidx.compose.ui.platform.PlatformTextInputInterceptor
import androidx.compose.ui.platform.PlatformTextInputMethodRequest

/**
 * Landscape IMEs otherwise open a fullscreen extract editor. That editor
 * shrinks the app's field to a sliver, swallows the search key, and then
 * restarts the input connection, which shows the keyboard again. These flags
 * keep the field inline so the Search action reaches it.
 */
internal fun EditorInfo.applySearchImeFlags() {
    imeOptions = imeOptions or EditorInfo.IME_FLAG_NO_EXTRACT_UI or EditorInfo.IME_FLAG_NO_FULLSCREEN
}

internal val searchFieldImeInterceptor = PlatformTextInputInterceptor { request, next ->
    next.startInputMethod(PlatformTextInputMethodRequest { outAttributes ->
        val connection = request.createInputConnection(outAttributes)
        outAttributes.applySearchImeFlags()
        connection
    })
}
