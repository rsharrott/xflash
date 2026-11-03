package com.japaneseinaflash.app.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import com.japaneseinaflash.app.R
import com.japaneseinaflash.app.study.StudyTheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ThemeSheet(
    selected: StudyTheme,
    dark: Boolean,
    onSelect: (StudyTheme) -> Unit,
    onDismiss: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(Modifier.selectableGroup().padding(horizontal = 20.dp, vertical = 8.dp)) {
            Text(stringResource(R.string.theme), style = MaterialTheme.typography.titleLarge)
            Text(
                stringResource(R.string.theme_applies),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 4.dp, bottom = 16.dp),
            )
            StudyTheme.entries.chunked(3).forEach { row ->
                Row(
                    Modifier.fillMaxWidth().padding(bottom = 12.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    row.forEach { theme ->
                        MiniThemeCard(
                            theme = theme,
                            selected = theme == selected,
                            dark = dark && theme == StudyTheme.PAPER,
                            onClick = { onSelect(theme) },
                            modifier = Modifier.weight(1f),
                        )
                    }
                    repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
            Spacer(Modifier.height(12.dp))
        }
    }
}

@Composable
private fun MiniThemeCard(
    theme: StudyTheme,
    selected: Boolean,
    dark: Boolean,
    onClick: () -> Unit,
    modifier: Modifier,
) {
    val colors = studyColors(theme, dark)
    val shape = RoundedCornerShape(16.dp)
    val border = if (selected) {
        Modifier.border(2.dp, MaterialTheme.colorScheme.primary, shape)
    } else {
        Modifier
    }
    Column(
        modifier
            .height(96.dp)
            .clip(shape)
            .then(border)
            .selectable(selected = selected, role = Role.RadioButton, onClick = onClick),
    ) {
        Text(
            stringResource(theme.label()),
            color = colors.headword,
            style = MaterialTheme.typography.labelLarge,
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .background(colors.card)
                .padding(10.dp),
        )
        Spacer(
            Modifier
                .fillMaxWidth()
                .height(10.dp)
                .background(colors.showAnswer),
        )
    }
}

fun StudyTheme.label(): Int = when (this) {
    StudyTheme.PAPER -> R.string.theme_paper
    StudyTheme.FIRE -> R.string.theme_fire
    StudyTheme.WATER -> R.string.theme_water
    StudyTheme.KIMONO -> R.string.theme_kimono
    StudyTheme.KUTANI -> R.string.theme_kutani
}
