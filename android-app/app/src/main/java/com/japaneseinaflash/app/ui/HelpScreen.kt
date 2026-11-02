package com.japaneseinaflash.app.ui

import android.webkit.WebView
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.japaneseinaflash.app.R
import com.japaneseinaflash.app.help.HelpPages

data class HelpTopic(val file: String, val title: Int)

val HelpTopics = listOf(
    HelpTopic("welcome@2x.html", R.string.help_welcome),
    HelpTopic("studysets@2x.html", R.string.help_sets),
    HelpTopic("practice@2x.html", R.string.help_practice),
    HelpTopic("search@2x.html", R.string.help_search),
    HelpTopic("corrections@2x.html", R.string.help_corrections),
    HelpTopic("algorithm@2x.html", R.string.help_algorithm),
    HelpTopic("tags@2x.html", R.string.help_tags),
)

@Composable
fun HelpList(onOpen: (HelpTopic) -> Unit, modifier: Modifier = Modifier) {
    LazyColumn(modifier.fillMaxSize()) {
        items(HelpTopics, key = { it.file }) { topic ->
            ListItem(
                headlineContent = { Text(stringResource(topic.title)) },
                modifier = Modifier
                    .clickable { onOpen(topic) }
                    .heightIn(min = 48.dp),
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HelpPage(topic: HelpTopic, japanese: Boolean, onBack: () -> Unit) {
    val url = HelpPages.assetPath(topic.file, japanese)
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(topic.title)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                },
            )
        },
    ) { padding ->
        AndroidView(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
            factory = { context ->
                WebView(context).apply {
                    settings.javaScriptEnabled = false
                    settings.allowFileAccess = true
                    setBackgroundColor(android.graphics.Color.TRANSPARENT)
                }
            },
            update = { webView ->
                if (webView.url != url) webView.loadUrl(url)
            },
        )
    }
}
