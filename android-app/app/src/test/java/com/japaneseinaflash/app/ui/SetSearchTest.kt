package com.japaneseinaflash.app.ui

import com.japaneseinaflash.app.data.TagRecord
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class SetSearchTest {
    @Test
    fun aSlowOlderQueryDoesNotReplaceNewerResults() = runTest {
        val queries = MutableStateFlow("")
        val seen = mutableListOf<String>()
        backgroundScope.watchSetSearch(queries, debounceMs = 20, find = { query ->
            if (query == "a") kotlinx.coroutines.awaitCancellation()
            listOf(tag(query))
        }) { rows, _ ->
            seen += rows.joinToString(",") { it.name }
        }
        queries.value = "a"
        advanceTimeBy(50)
        runCurrent()
        queries.value = "ab"
        advanceTimeBy(50)
        runCurrent()
        assertEquals(listOf("ab"), seen.filter { it.isNotEmpty() })
    }

    private fun tag(name: String) = TagRecord(1, name, "", 1, true)
}
