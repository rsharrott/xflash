package com.japaneseinaflash.app.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.compose.material3.ExperimentalMaterial3Api
import com.japaneseinaflash.app.R
import com.japaneseinaflash.app.study.AppPreferences
import com.japaneseinaflash.app.study.DarkMode
import com.japaneseinaflash.app.study.Difficulty
import com.japaneseinaflash.app.study.KanaHeadword
import com.japaneseinaflash.app.study.ReadingMode
import com.japaneseinaflash.app.study.StudyLanguage
import com.japaneseinaflash.app.study.StudyTheme
import com.japaneseinaflash.app.ui.theme.label

private enum class ChoiceDialog { Language, Reading, Kana, Dark }

@Composable
fun SettingsScreen(
    preferences: AppPreferences,
    onTheme: () -> Unit,
    onLanguage: (StudyLanguage) -> Unit,
    onReading: (ReadingMode) -> Unit,
    onKana: (KanaHeadword) -> Unit,
    onDark: (DarkMode) -> Unit,
    onDifficulty: () -> Unit,
    onHelp: () -> Unit,
    onAbout: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var dialog by remember { androidx.compose.runtime.mutableStateOf<ChoiceDialog?>(null) }
    val paper = preferences.theme == StudyTheme.PAPER
    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        Masthead(stringResource(R.string.nav_settings))
        Section(stringResource(R.string.settings_studying))
        ChoiceRow(stringResource(R.string.study_language), languageLabel(preferences.language)) {
            dialog = ChoiceDialog.Language
        }
        ChoiceRow(
            stringResource(R.string.furigana),
            readingLabel(preferences.reading),
            supporting = stringResource(R.string.furigana_help),
        ) { dialog = ChoiceDialog.Reading }
        ChoiceRow(stringResource(R.string.common_kana), kanaLabel(preferences.kanaHeadword)) {
            dialog = ChoiceDialog.Kana
        }
        ChoiceRow(stringResource(R.string.difficulty), difficultyLabel(preferences)) { onDifficulty() }
        Section(stringResource(R.string.settings_appearance))
        ChoiceRow(stringResource(R.string.theme), stringResource(preferences.theme.label())) { onTheme() }
        ChoiceRow(
            headline = stringResource(R.string.dark_mode),
            value = darkLabel(preferences.darkMode),
            supporting = if (paper) {
                stringResource(R.string.dark_mode_paper)
            } else {
                stringResource(R.string.dark_mode_unavailable)
            },
            enabled = paper,
        ) { if (paper) dialog = ChoiceDialog.Dark }
        Section(stringResource(R.string.settings_about))
        ChoiceRow(stringResource(R.string.help), "") { onHelp() }
        ChoiceRow(stringResource(R.string.about), "") { onAbout() }
    }
    when (dialog) {
        ChoiceDialog.Language -> RadioDialog(
            title = stringResource(R.string.study_language),
            options = StudyLanguage.entries.map { it to languageLabel(it) },
            selected = preferences.language,
            onSelect = { onLanguage(it); dialog = null },
            onDismiss = { dialog = null },
        )
        ChoiceDialog.Reading -> RadioDialog(
            title = stringResource(R.string.furigana),
            options = ReadingMode.entries.map { it to readingLabel(it) },
            selected = preferences.reading,
            onSelect = { onReading(it); dialog = null },
            onDismiss = { dialog = null },
        )
        ChoiceDialog.Kana -> RadioDialog(
            title = stringResource(R.string.common_kana),
            options = KanaHeadword.entries.map { it to kanaLabel(it) },
            selected = preferences.kanaHeadword,
            onSelect = { onKana(it); dialog = null },
            onDismiss = { dialog = null },
        )
        ChoiceDialog.Dark -> RadioDialog(
            title = stringResource(R.string.dark_mode),
            options = DarkMode.entries.map { it to darkLabel(it) },
            selected = preferences.darkMode,
            onSelect = { onDark(it); dialog = null },
            onDismiss = { dialog = null },
        )
        null -> Unit
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DifficultyScreen(
    preferences: AppPreferences,
    onDifficulty: (Difficulty) -> Unit,
    onCustom: (Int, Int) -> Unit,
    onHide: (Boolean) -> Unit,
    onBack: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.difficulty)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
                    }
                },
            )
        },
    ) { padding ->
        Column(
            Modifier
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .selectableGroup(),
        ) {
            Difficulty.entries.forEach { difficulty ->
                val selected = preferences.difficulty == difficulty
                ListItem(
                    headlineContent = { Text(difficultyName(difficulty)) },
                    supportingContent = { Text(difficultyDetail(difficulty, preferences)) },
                    leadingContent = { RadioButton(selected = selected, onClick = null) },
                    modifier = Modifier
                        .selectable(selected, role = Role.RadioButton) { onDifficulty(difficulty) }
                        .heightIn(min = 48.dp),
                )
            }
            if (preferences.difficulty == Difficulty.CUSTOM) {
                var pool by remember(preferences.customMax) { mutableIntStateOf(preferences.customMax) }
                var frequency by remember(preferences.customFrequency) { mutableIntStateOf(preferences.customFrequency) }
                Text(
                    stringResource(R.string.pool_size),
                    modifier = Modifier.padding(start = 20.dp, top = 16.dp),
                )
                Text("$pool", modifier = Modifier.padding(horizontal = 20.dp), style = MaterialTheme.typography.titleMedium)
                Slider(
                    value = pool.toFloat(),
                    onValueChange = { pool = it.toInt() },
                    onValueChangeFinished = { onCustom(pool, frequency) },
                    valueRange = AppPreferences.MIN_POOL.toFloat()..AppPreferences.MAX_POOL.toFloat(),
                    steps = AppPreferences.MAX_POOL - AppPreferences.MIN_POOL - 1,
                    modifier = Modifier.padding(horizontal = 20.dp),
                )
                Text(stringResource(R.string.pool_range), modifier = Modifier.padding(horizontal = 20.dp))
                Text(
                    stringResource(R.string.new_card_frequency),
                    modifier = Modifier.padding(start = 20.dp, top = 12.dp),
                )
                Text("$frequency", modifier = Modifier.padding(horizontal = 20.dp), style = MaterialTheme.typography.titleMedium)
                Slider(
                    value = frequency.toFloat(),
                    onValueChange = { frequency = it.toInt() },
                    onValueChangeFinished = { onCustom(pool, frequency) },
                    valueRange = 1f..4f,
                    steps = 2,
                    modifier = Modifier.padding(horizontal = 20.dp),
                )
                Text(stringResource(R.string.frequency_range), modifier = Modifier.padding(horizontal = 20.dp))
            }
            HorizontalDivider(Modifier.padding(vertical = 8.dp))
            ListItem(
                headlineContent = { Text(stringResource(R.string.hide_learned)) },
                trailingContent = {
                    Switch(checked = preferences.hideLearned, onCheckedChange = onHide)
                },
                modifier = Modifier.heightIn(min = 48.dp),
            )
        }
    }
}

@Composable
private fun <T> RadioDialog(
    title: String,
    options: List<Pair<T, String>>,
    selected: T,
    onSelect: (T) -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Column(Modifier.selectableGroup()) {
                options.forEach { (value, label) ->
                    val isSelected = value == selected
                    ListItem(
                        headlineContent = { Text(label) },
                        leadingContent = { RadioButton(selected = isSelected, onClick = null) },
                        modifier = Modifier
                            .selectable(isSelected, role = Role.RadioButton) { onSelect(value) }
                            .heightIn(min = 48.dp),
                    )
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss, modifier = Modifier.heightIn(min = 48.dp)) {
                Text(stringResource(R.string.cancel))
            }
        },
    )
}

@Composable
private fun ChoiceRow(
    headline: String,
    value: String,
    supporting: String? = null,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    ListItem(
        headlineContent = { Text(headline) },
        supportingContent = {
            val line = listOfNotNull(value.ifBlank { null }, supporting).joinToString(" · ")
            if (line.isNotBlank()) {
                Text(line, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        },
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .then(if (enabled) Modifier.clickable(onClick = onClick) else Modifier),
    )
}

@Composable
private fun Section(title: String) {
    Text(
        title,
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(start = 20.dp, top = 20.dp, bottom = 4.dp),
    )
}

@Composable
private fun languageLabel(language: StudyLanguage): String = when (language) {
    StudyLanguage.JAPANESE -> stringResource(R.string.language_japanese)
    StudyLanguage.ENGLISH -> stringResource(R.string.language_english)
}

@Composable
private fun readingLabel(mode: ReadingMode): String = when (mode) {
    ReadingMode.KANA -> stringResource(R.string.reading_kana)
    ReadingMode.ROMAJI -> stringResource(R.string.reading_romaji)
    ReadingMode.BOTH -> stringResource(R.string.reading_both)
}

@Composable
private fun kanaLabel(mode: KanaHeadword): String = when (mode) {
    KanaHeadword.PREFER_KANA -> stringResource(R.string.prefer_kana)
    KanaHeadword.PREFER_KANJI -> stringResource(R.string.prefer_kanji)
}

@Composable
private fun darkLabel(mode: DarkMode): String = when (mode) {
    DarkMode.FOLLOW_SYSTEM -> stringResource(R.string.dark_follow)
    DarkMode.OFF -> stringResource(R.string.dark_off)
    DarkMode.ON -> stringResource(R.string.dark_on)
}

@Composable
private fun difficultyLabel(preferences: AppPreferences): String = difficultyName(preferences.difficulty)

@Composable
private fun difficultyName(difficulty: Difficulty): String = when (difficulty) {
    Difficulty.EASY -> stringResource(R.string.difficulty_easy)
    Difficulty.MEDIUM -> stringResource(R.string.difficulty_medium)
    Difficulty.HARD -> stringResource(R.string.difficulty_hard)
    Difficulty.CUSTOM -> stringResource(R.string.difficulty_custom)
}

@Composable
private fun difficultyDetail(difficulty: Difficulty, preferences: AppPreferences): String {
    val (pool, frequency) = when (difficulty) {
        Difficulty.EASY -> AppPreferences.EASY_POOL to AppPreferences.EASY_FREQUENCY
        Difficulty.MEDIUM -> AppPreferences.MEDIUM_POOL to AppPreferences.MEDIUM_FREQUENCY
        Difficulty.HARD -> AppPreferences.HARD_POOL to AppPreferences.HARD_FREQUENCY
        Difficulty.CUSTOM -> preferences.customMax to preferences.customFrequency
    }
    return stringResource(R.string.difficulty_values, pool, frequency)
}
