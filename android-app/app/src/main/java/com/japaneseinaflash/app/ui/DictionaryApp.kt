package com.japaneseinaflash.app.ui

import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withLink
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.japaneseinaflash.app.R
import com.japaneseinaflash.app.data.CardDetail
import com.japaneseinaflash.app.data.CardSummary
import com.japaneseinaflash.app.data.DataVersions
import com.japaneseinaflash.app.data.ExampleSentence
import com.japaneseinaflash.app.data.SearchQuery
import com.japaneseinaflash.app.data.Sense

@Composable
fun DictionaryApp(viewModel: DictionaryViewModel = viewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    BackHandler(enabled = state.canGoBack) { viewModel.back() }
    PaperTheme {
        DictionaryScaffold(
            state = state,
            versionName = appVersionName(),
            onQueryChange = viewModel::onQueryChange,
            onSubmit = viewModel::submit,
            onCard = viewModel::openCard,
            onAbout = viewModel::openAbout,
            onBack = viewModel::back,
        )
    }
}

@Composable
private fun DictionaryScaffold(
    state: DictionaryUiState,
    versionName: String,
    onQueryChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onCard: (Long) -> Unit,
    onAbout: () -> Unit,
    onBack: () -> Unit,
) {
    val title = when (state.screen) {
        Screen.Search -> stringResource(R.string.app_name)
        Screen.About -> stringResource(R.string.about_title)
        is Screen.Detail -> state.card?.headword ?: stringResource(R.string.card_loading_title)
    }
    val showAbout = state.screen is Screen.Search
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        contentColor = MaterialTheme.colorScheme.onBackground,
    ) { padding ->
        Column(
            Modifier
                .padding(padding)
                .fillMaxSize()
                .imePadding(),
        ) {
            Masthead(
                title = title,
                showBack = state.canGoBack,
                showAbout = showAbout,
                onBack = onBack,
                onAbout = onAbout,
            )
            when (state.screen) {
                Screen.Search -> SearchBody(state, onQueryChange, onSubmit, onCard)
                Screen.About -> AboutBody(state.versions, versionName)
                is Screen.Detail -> DetailBody(state)
            }
        }
    }
}

@Composable
private fun Masthead(
    title: String,
    showBack: Boolean,
    showAbout: Boolean,
    onBack: () -> Unit,
    onAbout: () -> Unit,
) {
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 4.dp, end = 8.dp, top = 4.dp, bottom = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (showBack) {
                IconButton(onClick = onBack) {
                    Icon(
                        painter = painterResource(R.drawable.ic_arrow_back),
                        contentDescription = stringResource(R.string.back),
                        tint = MaterialTheme.colorScheme.onBackground,
                    )
                }
            }
            Text(
                text = title,
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.onBackground,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 12.dp, vertical = 8.dp),
            )
            if (showAbout) {
                TextButton(onClick = onAbout) {
                    Text(stringResource(R.string.about))
                }
            }
        }
        HorizontalDivider(color = MaterialTheme.colorScheme.outline)
    }
}

@Composable
private fun SearchBody(
    state: DictionaryUiState,
    onQueryChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onCard: (Long) -> Unit,
) {
    Column(Modifier.fillMaxSize().padding(horizontal = 20.dp)) {
        Spacer(Modifier.height(16.dp))
        val searchDescription = stringResource(R.string.cd_search_field)
        OutlinedTextField(
            value = state.query,
            onValueChange = onQueryChange,
            modifier = Modifier
                .fillMaxWidth()
                .semantics { contentDescription = searchDescription },
            placeholder = { Text(stringResource(R.string.search_hint)) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = { onSubmit() }),
            trailingIcon = if (state.query.isNotEmpty()) {
                {
                    TextButton(onClick = { onQueryChange("") }) {
                        Text(stringResource(R.string.clear_search))
                    }
                }
            } else {
                null
            },
            colors = paperFieldColors(),
        )
        Spacer(Modifier.height(12.dp))
        when (state.phase) {
            Phase.Preparing -> PreparingMessage()
            Phase.Failed -> ErrorText(state.error ?: DictionaryError.PrepareFailed)
            Phase.Ready -> ReadyResults(state, onCard)
        }
    }
}

@Composable
private fun SearchResults(
    results: List<CardSummary>,
    onCard: (Long) -> Unit,
) {
    if (results.size >= SearchQuery.DEFAULT_LIMIT) {
        Text(
            text = pluralStringResource(
                R.plurals.search_truncated,
                SearchQuery.DEFAULT_LIMIT,
                SearchQuery.DEFAULT_LIMIT,
            ),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = 8.dp),
        )
    }
    LazyColumn(modifier = Modifier.fillMaxSize()) {
        items(results, key = { it.id }) { card ->
            val description = stringResource(R.string.cd_result, card.headword, card.reading.ifEmpty { card.meaning })
            Column(
                Modifier
                    .fillMaxWidth()
                    .clickable { onCard(card.id) }
                    .semantics { contentDescription = description }
                    .padding(vertical = 12.dp),
            ) {
                Text(card.headword, style = MaterialTheme.typography.titleLarge)
                if (card.reading.isNotEmpty()) {
                    Text(
                        card.reading,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                if (card.meaning.isNotEmpty()) {
                    Text(
                        card.meaning,
                        style = MaterialTheme.typography.bodyMedium,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.6f))
        }
    }
}

@Composable
private fun ReadyResults(
    state: DictionaryUiState,
    onCard: (Long) -> Unit,
) {
    state.error?.let { ErrorText(it) }
    when {
        state.searching -> LoadingRow()
        state.query.isBlank() -> Hint(stringResource(R.string.search_prompt))
        state.results.isEmpty() -> Hint(stringResource(R.string.no_results))
        else -> SearchResults(state.results, onCard)
    }
}

@Composable
private fun DetailBody(state: DictionaryUiState) {
    when {
        state.error != null && state.card == null -> {
            Column(Modifier.padding(20.dp)) { ErrorText(state.error) }
        }
        state.card == null -> LoadingRow()
        else -> CardBody(state.card)
    }
}

@Composable
private fun CardBody(card: CardDetail) {
    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 16.dp),
    ) {
        Text(card.headword, style = MaterialTheme.typography.headlineMedium)
        val readingLine = when {
            card.reading.isNotEmpty() && card.romaji.isNotEmpty() ->
                stringResource(R.string.reading_and_romaji, card.reading, card.romaji)
            card.reading.isNotEmpty() -> card.reading
            card.romaji.isNotEmpty() -> card.romaji
            else -> null
        }
        if (readingLine != null) {
            Text(
                readingLine,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
        if (card.senses.isNotEmpty()) {
            SectionHeading(stringResource(R.string.meaning_heading))
            card.senses.forEach { sense -> SenseBlock(sense) }
        }
        SectionHeading(stringResource(R.string.examples_heading))
        if (card.sentences.isEmpty()) {
            Text(stringResource(R.string.no_examples), style = MaterialTheme.typography.bodyLarge)
        } else {
            card.sentences.forEach { sentence -> SentenceBlock(sentence) }
        }
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun SectionHeading(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(top = 20.dp, bottom = 8.dp),
    )
}

@Composable
private fun SenseBlock(sense: Sense) {
    Column(Modifier.padding(bottom = 10.dp)) {
        Text(sense.text, style = MaterialTheme.typography.bodyLarge)
        if (!sense.partOfSpeech.isNullOrEmpty()) {
            Text(
                sense.partOfSpeech,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.primary,
            )
        }
    }
}

@Composable
private fun SentenceBlock(sentence: ExampleSentence) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 10.dp),
        color = MaterialTheme.colorScheme.surface,
        shape = MaterialTheme.shapes.extraSmall,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline),
    ) {
        Column(Modifier.padding(12.dp)) {
            Text(sentence.japanese, style = MaterialTheme.typography.bodyLarge)
            if (sentence.english.isNotEmpty()) {
                Spacer(Modifier.height(4.dp))
                Text(
                    sentence.english,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun AboutBody(versions: DataVersions?, versionName: String) {
    SelectionContainer {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 16.dp),
        ) {
            Paragraph(stringResource(R.string.about_intro))
            Paragraph(stringResource(R.string.about_scope))
            if (versions != null && versions.cards.isNotEmpty()) {
                Paragraph(
                    stringResource(
                        R.string.about_versions,
                        versions.cards,
                        versions.search,
                        versions.examples,
                    ),
                )
            }
            SectionHeading(stringResource(R.string.licence_heading))
            Paragraph(stringResource(R.string.licence_jmdict))
            LicenceLink(R.string.link_cc_by_sa, R.string.url_cc_by_sa)
            LicenceLink(R.string.link_edrdg, R.string.url_edrdg)
            LicenceLink(R.string.link_jmdict, R.string.url_jmdict)
            LicenceLink(R.string.link_source, R.string.url_source)
            Spacer(Modifier.height(12.dp))
            Paragraph(stringResource(R.string.licence_core1000))
            Paragraph(stringResource(R.string.licence_tatoeba))
            LicenceLink(R.string.link_tatoeba, R.string.url_tatoeba)
            LicenceLink(R.string.link_cc_by, R.string.url_cc_by)
            Spacer(Modifier.height(12.dp))
            Paragraph(stringResource(R.string.licence_code))
            LicenceLink(R.string.link_privacy, R.string.url_privacy)
            Spacer(Modifier.height(20.dp))
            Text(
                stringResource(R.string.about_app_version, versionName),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun Paragraph(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.bodyLarge,
        modifier = Modifier.padding(bottom = 12.dp),
    )
}

@Composable
private fun LicenceLink(labelRes: Int, urlRes: Int) {
    val url = stringResource(urlRes)
    Text(
        text = buildAnnotatedString {
            withLink(
                LinkAnnotation.Url(
                    url,
                    TextLinkStyles(
                        SpanStyle(
                            color = MaterialTheme.colorScheme.primary,
                            textDecoration = TextDecoration.Underline,
                        ),
                    ),
                ),
            ) {
                append(stringResource(labelRes))
            }
        },
        style = MaterialTheme.typography.bodyLarge,
        modifier = Modifier.padding(vertical = 2.dp),
    )
}

@Composable
private fun PreparingMessage() {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        val loading = stringResource(R.string.cd_loading)
        CircularProgressIndicator(
            modifier = Modifier.semantics { contentDescription = loading },
            color = MaterialTheme.colorScheme.primary,
        )
        Spacer(Modifier.height(16.dp))
        Text(stringResource(R.string.preparing_dictionary), style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))
        Text(
            stringResource(R.string.preparing_dictionary_detail),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun LoadingRow() {
    val loading = stringResource(R.string.cd_loading)
    Row(
        Modifier.fillMaxWidth().padding(top = 24.dp),
        horizontalArrangement = Arrangement.Center,
    ) {
        CircularProgressIndicator(
            modifier = Modifier
                .size(32.dp)
                .semantics { contentDescription = loading },
            color = MaterialTheme.colorScheme.primary,
            strokeWidth = 3.dp,
        )
    }
}

@Composable
private fun Hint(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.bodyLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(top = 8.dp),
    )
}

@Composable
private fun ErrorText(error: DictionaryError) {
    val message = when (error) {
        DictionaryError.PrepareFailed -> stringResource(R.string.error_prepare)
        DictionaryError.SearchFailed -> stringResource(R.string.error_search)
        DictionaryError.CardFailed -> stringResource(R.string.error_card)
        DictionaryError.CardMissing -> stringResource(R.string.error_card_missing)
    }
    Text(
        text = message,
        style = MaterialTheme.typography.bodyLarge,
        color = MaterialTheme.colorScheme.error,
        modifier = Modifier.padding(bottom = 8.dp),
    )
}

@Composable
private fun paperFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = MaterialTheme.colorScheme.primary,
    unfocusedBorderColor = MaterialTheme.colorScheme.outline,
    focusedContainerColor = MaterialTheme.colorScheme.surface,
    unfocusedContainerColor = MaterialTheme.colorScheme.surface,
    cursorColor = MaterialTheme.colorScheme.primary,
    focusedTextColor = MaterialTheme.colorScheme.onSurface,
    unfocusedTextColor = MaterialTheme.colorScheme.onSurface,
)

@Composable
private fun appVersionName(): String {
    val context = LocalContext.current
    val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        context.packageManager.getPackageInfo(
            context.packageName,
            PackageManager.PackageInfoFlags.of(0),
        )
    } else {
        @Suppress("DEPRECATION")
        context.packageManager.getPackageInfo(context.packageName, 0)
    }
    return info.versionName.orEmpty()
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F1E7)
@Composable
private fun SearchPreview() {
    PaperTheme {
        DictionaryScaffold(
            state = DictionaryUiState(
                phase = Phase.Ready,
                query = "neko",
                results = listOf(
                    CardSummary(1, "猫", "ねこ", "cat"),
                    CardSummary(2, "猫背", "ねこせ", "stoop"),
                ),
            ),
            versionName = "0.1.0",
            onQueryChange = {},
            onSubmit = {},
            onCard = {},
            onAbout = {},
            onBack = {},
        )
    }
}

@Preview(showBackground = true, backgroundColor = 0xFFF6F1E7)
@Composable
private fun CardPreview() {
    PaperTheme {
        DictionaryScaffold(
            state = DictionaryUiState(
                phase = Phase.Ready,
                screen = Screen.Detail(1),
                canGoBack = true,
                card = CardDetail(
                    id = 1,
                    headword = "猫",
                    reading = "ねこ",
                    romaji = "neko",
                    senses = listOf(Sense("cat", "noun")),
                    sentences = listOf(ExampleSentence(1, "猫がのびをした。", "The cat stretched.")),
                ),
            ),
            versionName = "0.1.0",
            onQueryChange = {},
            onSubmit = {},
            onCard = {},
            onAbout = {},
            onBack = {},
        )
    }
}
