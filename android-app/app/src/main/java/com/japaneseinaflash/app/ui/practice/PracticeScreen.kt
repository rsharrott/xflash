package com.japaneseinaflash.app.ui.practice

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.res.painterResource
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.japaneseinaflash.app.R
import com.japaneseinaflash.app.ui.PracticeKey
import com.japaneseinaflash.app.ui.practiceKey
import com.japaneseinaflash.app.study.AppPreferences
import com.japaneseinaflash.app.study.PracticeFace
import com.japaneseinaflash.app.study.cumulativeBarFractions
import com.japaneseinaflash.app.study.isSetLearned
import com.japaneseinaflash.app.study.learnedCount
import com.japaneseinaflash.app.study.learnedFraction
import com.japaneseinaflash.app.study.levelStripSummary
import com.japaneseinaflash.app.study.practiceFace
import com.japaneseinaflash.app.ui.PracticeUiState
import com.japaneseinaflash.app.ui.theme.LocalStudyColors
import com.japaneseinaflash.app.ui.withJapaneseGlyphs

private val ExpandedWidth = 840.dp

@Composable
fun PracticeScreen(
    state: PracticeUiState,
    preferences: AppPreferences,
    onShowAnswer: () -> Unit,
    onToggleReading: () -> Unit,
    onSpeak: () -> Unit,
    onMark: (Boolean) -> Unit,
    onLevels: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val study = LocalStudyColors.current
    val face = state.card?.let {
        practiceFace(it.detail, it.kanaOnly, preferences, state.revealed, state.showReading)
    }
    Column(
        modifier
            .fillMaxSize()
            .onPreviewKeyEvent { event ->
                when (practiceKey(state.revealed, event.type, event.key)) {
                    PracticeKey.ShowAnswer -> {
                        onShowAnswer()
                        true
                    }
                    PracticeKey.Right -> {
                        onMark(true)
                        true
                    }
                    PracticeKey.Wrong -> {
                        onMark(false)
                        true
                    }
                    null -> false
                }
            },
    ) {
        if (state.setName.isNotEmpty() || !state.loading) {
            LevelStrip(
                levels = state.levels,
                total = state.total,
                onClick = onLevels,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            )
        }
        when {
            state.loading && state.card == null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
            }
            state.failed -> Text(
                stringResource(R.string.error_card),
                modifier = Modifier.padding(20.dp),
                color = MaterialTheme.colorScheme.error,
            )
            state.empty || face == null -> Text(
                stringResource(R.string.empty_set_message),
                modifier = Modifier.padding(20.dp),
                style = MaterialTheme.typography.bodyLarge,
            )
            else -> {
                BoxWithPracticeLayout { expanded ->
                    if (expanded) {
                        Row(Modifier.fillMaxSize().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                            FlashCard(face, Modifier.weight(1f).fillMaxHeight())
                            Column(Modifier.weight(1f).fillMaxHeight().verticalScroll(rememberScrollState())) {
                                AnswerActions(state, study.showAnswer, onShowAnswer, onToggleReading, onSpeak, onMark)
                            }
                        }
                    } else {
                        Column(
                            Modifier
                                .fillMaxSize()
                                .verticalScroll(rememberScrollState())
                                .padding(horizontal = 16.dp),
                        ) {
                            FlashCard(face, Modifier.fillMaxWidth().heightIn(min = 180.dp))
                            Spacer(Modifier.height(16.dp))
                            AnswerActions(state, study.showAnswer, onShowAnswer, onToggleReading, onSpeak, onMark)
                            Spacer(Modifier.height(24.dp))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun BoxWithPracticeLayout(content: @Composable (expanded: Boolean) -> Unit) {
    androidx.compose.foundation.layout.BoxWithConstraints(Modifier.fillMaxSize()) {
        content(maxWidth >= ExpandedWidth)
    }
}

@Composable
private fun AnswerActions(
    state: PracticeUiState,
    showAnswer: Color,
    onShowAnswer: () -> Unit,
    onToggleReading: () -> Unit,
    onSpeak: () -> Unit,
    onMark: (Boolean) -> Unit,
) {
    val study = LocalStudyColors.current
    if (!state.revealed) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FilledTonalButton(
                onClick = onToggleReading,
                modifier = Modifier
                    .weight(1f)
                    .height(48.dp)
                    .semantics { selected = state.showReading },
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.filledTonalButtonColors(
                    containerColor = study.toggleFill,
                    contentColor = study.toggleLabel,
                ),
            ) {
                Text(stringResource(R.string.show_reading))
            }
            FilledTonalIconButton(
                onClick = onSpeak,
                modifier = Modifier.size(48.dp),
                colors = androidx.compose.material3.IconButtonDefaults.filledTonalIconButtonColors(
                    containerColor = study.toggleFill,
                    contentColor = study.toggleLabel,
                ),
            ) {
                Icon(painterResource(R.drawable.ic_volume), contentDescription = stringResource(R.string.cd_speak))
            }
        }
        Spacer(Modifier.height(12.dp))
        Button(
            onClick = onShowAnswer,
            modifier = Modifier.fillMaxWidth().height(64.dp),
            shape = RoundedCornerShape(24.dp),
            colors = ButtonDefaults.buttonColors(containerColor = showAnswer, contentColor = study.onShowAnswer),
        ) {
            Icon(painterResource(R.drawable.ic_visibility), contentDescription = null)
            Spacer(Modifier.width(8.dp))
            Text(stringResource(R.string.show_answer), style = MaterialTheme.typography.titleMedium)
        }
    } else {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            MarkButton(
                label = stringResource(R.string.wrong),
                fill = study.wrongFill,
                labelColor = study.wrongLabel,
                outline = study.wrongOutline,
                badge = study.wrongBadge,
                badgeIcon = R.drawable.ic_close,
                badgeIconTint = study.onWrongBadge,
                outlined = true,
                onClick = { onMark(false) },
                modifier = Modifier.weight(1f),
            )
            MarkButton(
                label = stringResource(R.string.right),
                fill = study.rightFill,
                labelColor = study.rightLabel,
                outline = study.rightFill,
                badge = study.rightBadge,
                badgeIcon = R.drawable.ic_check,
                badgeIconTint = study.onRightBadge,
                outlined = false,
                onClick = { onMark(true) },
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun MarkButton(
    label: String,
    fill: Color,
    labelColor: Color,
    outline: Color,
    badge: Color,
    badgeIcon: Int,
    badgeIconTint: Color,
    outlined: Boolean,
    onClick: () -> Unit,
    modifier: Modifier,
) {
    val shape = RoundedCornerShape(20.dp)
    val content: @Composable () -> Unit = {
        Box(
            Modifier
                .size(32.dp)
                .clip(CircleShape)
                .then(Modifier),
            contentAlignment = Alignment.Center,
        ) {
            Canvas(Modifier.matchParentSize()) { drawCircle(color = badge) }
            Icon(painterResource(badgeIcon), contentDescription = null, tint = badgeIconTint, modifier = Modifier.size(18.dp))
        }
        Spacer(Modifier.width(8.dp))
        Text(label, color = labelColor, style = MaterialTheme.typography.titleMedium)
    }
    if (outlined) {
        OutlinedButton(
            onClick = onClick,
            modifier = modifier.height(64.dp),
            shape = shape,
            border = BorderStroke(1.5.dp, outline),
            colors = ButtonDefaults.outlinedButtonColors(containerColor = fill, contentColor = labelColor),
            content = { content() },
        )
    } else {
        Button(
            onClick = onClick,
            modifier = modifier.height(64.dp),
            shape = shape,
            colors = ButtonDefaults.buttonColors(containerColor = fill, contentColor = labelColor),
            content = { content() },
        )
    }
}

@Composable
fun LevelStrip(
    levels: IntArray,
    total: Int,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    asButton: Boolean = true,
) {
    val study = LocalStudyColors.current
    val names = listOf(
        stringResource(R.string.level_studying),
        stringResource(R.string.level_right_1),
        stringResource(R.string.level_right_2),
        stringResource(R.string.level_right_3),
        stringResource(R.string.level_learned),
    )
    val counts = (1..5).map { levels.getOrElse(it) { 0 } }
    val summary = levelStripSummary(names, counts)
    val learned = learnedCount(levels)
    val complete = isSetLearned(learned, total)
    val pill = if (complete) {
        stringResource(R.string.pill_complete)
    } else {
        stringResource(R.string.pill_learned, learned.coerceAtLeast(0), total.coerceAtLeast(0))
    }
    val pillDescription = if (complete) {
        stringResource(R.string.pill_complete_cd)
    } else {
        stringResource(R.string.pill_cd, learned.coerceAtLeast(0), total.coerceAtLeast(0))
    }
    val bars = cumulativeBarFractions(levels)
    Surface(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp)
            .semantics(mergeDescendants = true) {
                if (asButton) role = Role.Button
                contentDescription = "$summary. $pillDescription"
            }
            .then(if (asButton) Modifier.clickable(onClick = onClick) else Modifier),
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
    ) {
        Column(Modifier.padding(horizontal = 8.dp, vertical = 10.dp)) {
            Row(Modifier.fillMaxWidth()) {
                names.forEachIndexed { index, name ->
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            name,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface,
                            textAlign = TextAlign.Center,
                            maxLines = 2,
                        )
                        Canvas(Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 4.dp).height(4.dp)) {
                            levelBar(bars[index], study.bar, study.track)
                        }
                        Text(
                            counts[index].toString(),
                            style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold, fontSize = 13.sp),
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                    }
                }
            }
            HorizontalDivider(Modifier.padding(vertical = 8.dp), color = MaterialTheme.colorScheme.outlineVariant)
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(horizontal = 8.dp)) {
                CircularProgressIndicator(
                    progress = { learnedFraction(learned, total) },
                    modifier = Modifier.size(18.dp),
                    strokeWidth = 2.25.dp,
                    color = study.bar,
                    trackColor = study.track,
                )
                Spacer(Modifier.width(8.dp))
                Text(pill, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
                Spacer(Modifier.weight(1f))
                Icon(
                    painterResource(R.drawable.ic_chevron_right),
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
fun FlashCard(face: PracticeFace, modifier: Modifier = Modifier) {
    val study = LocalStudyColors.current
    Surface(
        modifier = modifier.cardTexture(study.texture, study.headword),
        shape = RoundedCornerShape(28.dp),
        color = study.card,
        shadowElevation = 8.dp,
    ) {
        Column(Modifier.padding(horizontal = 24.dp, vertical = 28.dp)) {
            Text(
                face.prompt,
                color = study.headword,
                style = MaterialTheme.typography.headlineMedium.copy(
                    fontSize = 56.sp,
                    lineHeight = 64.sp,
                    fontWeight = FontWeight.Bold,
                ).let { if (face.promptIsJapanese) it.withJapaneseGlyphs() else it },
            )
            face.answerJapanese?.let { word ->
                Text(
                    word,
                    color = study.reading,
                    style = MaterialTheme.typography.titleLarge.withJapaneseGlyphs(),
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
            face.reading?.let { reading ->
                Text(
                    reading,
                    color = study.reading,
                    style = MaterialTheme.typography.titleMedium.withJapaneseGlyphs(),
                    modifier = Modifier.padding(top = 6.dp),
                )
            }
            face.romaji?.let { romaji ->
                Text(
                    romaji,
                    color = study.romaji,
                    style = MaterialTheme.typography.bodyLarge,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
            face.partOfSpeech?.let { pos ->
                Surface(
                    modifier = Modifier.padding(top = 12.dp),
                    shape = RoundedCornerShape(8.dp),
                    color = study.posFill,
                ) {
                    Text(
                        pos,
                        color = study.posInk,
                        style = MaterialTheme.typography.labelLarge,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                    )
                }
            }
            face.senses.forEachIndexed { index, (text, _) ->
                Text(
                    "${index + 1}. $text",
                    color = study.meaning,
                    style = MaterialTheme.typography.bodyLarge,
                    modifier = Modifier.padding(top = 10.dp),
                )
            }
            face.example?.let { example ->
                Text(
                    example.japanese,
                    color = study.meaning,
                    style = MaterialTheme.typography.bodyLarge.withJapaneseGlyphs(),
                    modifier = Modifier.padding(top = 16.dp),
                )
                if (example.english.isNotBlank()) {
                    Text(
                        example.english,
                        color = study.romaji,
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
        }
    }
}
