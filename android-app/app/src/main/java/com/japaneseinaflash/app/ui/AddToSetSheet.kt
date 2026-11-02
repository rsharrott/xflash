package com.japaneseinaflash.app.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.clickable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import com.japaneseinaflash.app.R
import com.japaneseinaflash.app.ui.withJapaneseGlyphs

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddToSetSheet(
    state: AddToSetUi,
    onToggle: (Long, Boolean) -> Unit,
    onCreate: (String) -> Unit,
    onStartCreate: () -> Unit,
    onCancelCreate: () -> Unit,
    onDone: () -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDone) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(bottom = 24.dp),
        ) {
            Text(
                stringResource(R.string.add_to_set),
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
            )
            Text(
                state.headword,
                style = MaterialTheme.typography.titleLarge.withJapaneseGlyphs(),
                modifier = Modifier.padding(horizontal = 20.dp),
            )
            if (state.reading.isNotBlank()) {
                Text(
                    state.reading,
                    style = MaterialTheme.typography.bodyLarge.withJapaneseGlyphs(),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 2.dp),
                )
            }
            state.sets.forEach { tag ->
                val checked = tag.id in state.checked
                ListItem(
                    headlineContent = { Text(tag.name) },
                    leadingContent = { Checkbox(checked = checked, onCheckedChange = null) },
                    modifier = Modifier
                        .toggleable(value = checked, role = Role.Checkbox) { onToggle(tag.id, !checked) }
                        .heightIn(min = 48.dp),
                )
            }
            ListItem(
                headlineContent = { Text(stringResource(R.string.new_set)) },
                leadingContent = { Icon(Icons.Filled.Add, contentDescription = null) },
                modifier = Modifier
                    .clickable(role = Role.Button, onClick = onStartCreate)
                    .heightIn(min = 48.dp),
            )
            if (state.builtIn.isNotEmpty()) {
                Text(
                    stringResource(R.string.built_in_with_card),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.padding(start = 20.dp, top = 16.dp, bottom = 4.dp),
                )
                state.builtIn.forEach { name ->
                    ListItem(headlineContent = { Text(name) })
                }
            }
            Button(
                onClick = onDone,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 12.dp)
                    .heightIn(min = 48.dp),
            ) {
                Text(stringResource(R.string.done))
            }
        }
    }
    if (state.creating) {
        var name by rememberSaveable { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = onCancelCreate,
            title = { Text(stringResource(R.string.create_set)) },
            text = {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            },
            confirmButton = {
                TextButton(onClick = { if (name.isNotBlank()) onCreate(name) }, enabled = name.isNotBlank()) {
                    Text(stringResource(R.string.ok))
                }
            },
            dismissButton = {
                TextButton(onClick = onCancelCreate) { Text(stringResource(R.string.cancel)) }
            },
        )
    }
}
