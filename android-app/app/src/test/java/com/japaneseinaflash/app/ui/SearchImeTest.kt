package com.japaneseinaflash.app.ui

import android.view.inputmethod.EditorInfo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

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
    }
}
