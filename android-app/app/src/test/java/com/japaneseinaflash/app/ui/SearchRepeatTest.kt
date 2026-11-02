package com.japaneseinaflash.app.ui

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SearchRepeatTest {
    @Test
    fun aSuccessfulQueryIsNotRunAgain() {
        assertFalse(shouldRunSearch("neko", lastSuccess = "neko", error = null))
    }

    @Test
    fun enterAfterAnErrorSearchesAgain() {
        assertTrue(shouldRunSearch("neko", lastSuccess = "neko", error = DictionaryError.SearchFailed))
        assertTrue(shouldRunSearch("neko", lastSuccess = null, error = DictionaryError.PrepareFailed))
    }

    @Test
    fun aDifferentQueryStillRuns() {
        assertTrue(shouldRunSearch("inu", lastSuccess = "neko", error = null))
        assertTrue(shouldRunSearch("neko", lastSuccess = null, error = null))
    }
}
