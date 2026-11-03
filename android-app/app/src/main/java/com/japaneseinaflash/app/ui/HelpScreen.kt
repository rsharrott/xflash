package com.japaneseinaflash.app.ui

import android.content.Intent
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.webkit.WebViewAssetLoader
import com.japaneseinaflash.app.R
import com.japaneseinaflash.app.help.HELP_DARK_CSS
import com.japaneseinaflash.app.help.HelpPages
import java.io.ByteArrayInputStream
import kotlin.math.roundToInt

data class HelpTopic(val file: String, val title: Int)

val HelpTopics = listOf(
    HelpTopic("welcome@2x.html", R.string.help_welcome),
    HelpTopic("studysets@2x.html", R.string.help_sets),
    HelpTopic("practice@2x.html", R.string.help_practice),
    HelpTopic("search@2x.html", R.string.help_search),
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
fun HelpPage(
    topic: HelpTopic,
    japanese: Boolean,
    dark: Boolean,
    fontScale: Float,
    onBack: () -> Unit,
) {
    val url = HelpPages.assetPath(topic.file, japanese)
    val darkNow = rememberUpdatedState(dark)
    val zoom = (fontScale * 100f).roundToInt().coerceIn(1, 500)
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(topic.title)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(painterResource(R.drawable.ic_arrow_back), contentDescription = stringResource(R.string.back))
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
                val assetLoader = WebViewAssetLoader.Builder()
                    .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(context))
                    .build()
                WebView(context).apply {
                    lockDown(zoom)
                    setBackgroundColor(android.graphics.Color.TRANSPARENT)
                    webViewClient = object : WebViewClient() {
                        override fun shouldInterceptRequest(
                            view: WebView,
                            request: WebResourceRequest,
                        ): WebResourceResponse? {
                            val response = assetLoader.shouldInterceptRequest(request.url) ?: return null
                            val path = request.url.path.orEmpty()
                            if (!darkNow.value || !path.endsWith("/help.css")) return response
                            val css = response.data.bufferedReader(Charsets.UTF_8).use { it.readText() } + HELP_DARK_CSS
                            return WebResourceResponse(
                                "text/css",
                                "utf-8",
                                ByteArrayInputStream(css.toByteArray(Charsets.UTF_8)),
                            )
                        }

                        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                            val uri = request.url
                            if (uri.host == HelpPages.ASSET_HOST) return false
                            if (HelpPages.opensOutside(uri.scheme)) {
                                val intent = Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                runCatching { view.context.startActivity(intent) }
                            }
                            return true
                        }
                    }
                }
            },
            update = { webView ->
                webView.settings.textZoom = zoom
                val key = "$url|dark=$dark|zoom=$zoom"
                if (webView.tag != key) {
                    webView.tag = key
                    webView.loadUrl(url)
                }
            },
        )
    }
}

@Suppress("DEPRECATION")
private fun WebView.lockDown(zoom: Int) {
    settings.javaScriptEnabled = false
    settings.allowFileAccess = false
    settings.allowContentAccess = false
    settings.allowFileAccessFromFileURLs = false
    settings.allowUniversalAccessFromFileURLs = false
    settings.textZoom = zoom
    settings.cacheMode = WebSettings.LOAD_NO_CACHE
}
