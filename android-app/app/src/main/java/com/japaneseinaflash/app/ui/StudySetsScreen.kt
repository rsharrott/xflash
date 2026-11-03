package com.japaneseinaflash.app.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.IconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.japaneseinaflash.app.R
import com.japaneseinaflash.app.data.GroupRecord
import com.japaneseinaflash.app.data.TagRecord
import com.japaneseinaflash.app.study.displayName
import com.japaneseinaflash.app.ui.theme.LocalStudyColors

@Composable
fun StudySetsScreen(
    state: SetsUiState,
    japanese: Boolean,
    onQuery: (String) -> Unit,
    onGroup: (Long) -> Unit,
    onTag: (TagRecord) -> Unit,
    onCreate: (String) -> Unit,
    onStartCreate: () -> Unit,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
    onPractice: () -> Unit,
    modifier: Modifier = Modifier,
    onBack: (() -> Unit)? = null,
) {
    var searchOpen by rememberSaveable { mutableStateOf(state.searchOnly) }
    Column(modifier.fillMaxSize()) {
        val title = if (state.title.isEmpty()) {
            stringResource(R.string.nav_study_sets)
        } else {
            displayName(state.title, state.titleJa, japanese)
        }
        Masthead(
            title = title,
            japaneseTitle = japanese && state.title.isNotEmpty(),
            onBack = onBack,
            action = {
                if (!state.searchOnly && !searchOpen) {
                    IconButton(onClick = { searchOpen = true }) {
                        Icon(painterResource(R.drawable.ic_search), contentDescription = stringResource(R.string.search_sets))
                    }
                }
            },
        )
        if (searchOpen || state.searchOnly) {
            val searchDescription = stringResource(R.string.cd_search_sets)
            OutlinedTextField(
                value = state.query,
                onValueChange = onQuery,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 8.dp)
                    .semantics { contentDescription = searchDescription },
                placeholder = { Text(stringResource(R.string.search_sets)) },
                singleLine = true,
                leadingIcon = { Icon(painterResource(R.drawable.ic_search), contentDescription = null) },
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(onSearch = { onQuery(state.query) }),
            )
        }
        if (state.createFailed) {
            Text(
                stringResource(R.string.error_create_set),
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
                color = MaterialTheme.colorScheme.error,
            )
        }
        when {
            state.loading -> Text(
                stringResource(R.string.cd_loading),
                modifier = Modifier.padding(20.dp),
            )
            state.loadFailed -> Text(
                stringResource(R.string.error_load_sets),
                modifier = Modifier.padding(20.dp),
                color = MaterialTheme.colorScheme.error,
            )
            state.searching -> Text(
                stringResource(R.string.cd_loading),
                modifier = Modifier.padding(20.dp),
            )
            state.searchFailed -> Text(
                stringResource(R.string.error_search),
                modifier = Modifier.padding(20.dp),
                color = MaterialTheme.colorScheme.error,
            )
            state.query.isNotBlank() -> TagList(state.results, state.activeId, japanese, onTag)
            state.searchOnly -> Text(
                stringResource(R.string.search_sets_prompt),
                modifier = Modifier.padding(20.dp),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            else -> Catalog(state, japanese, onGroup, onTag, onStartCreate, onPractice)
        }
    }
    state.confirm?.let { tag ->
        AlertDialog(
            onDismissRequest = onDismiss,
            title = { Text(displayName(tag.name, tag.nameJa, japanese)) },
            text = { Text(stringResource(R.string.start_set_message)) },
            confirmButton = {
                TextButton(onClick = onConfirm, modifier = Modifier.heightIn(min = 48.dp)) {
                    Text(stringResource(R.string.ok))
                }
            },
            dismissButton = {
                TextButton(onClick = onDismiss, modifier = Modifier.heightIn(min = 48.dp)) {
                    Text(stringResource(R.string.cancel))
                }
            },
        )
    }
    state.emptySet?.let {
        AlertDialog(
            onDismissRequest = onDismiss,
            title = { Text(stringResource(R.string.no_words_title)) },
            text = { Text(stringResource(R.string.empty_set_message)) },
            confirmButton = {
                TextButton(onClick = onDismiss, modifier = Modifier.heightIn(min = 48.dp)) {
                    Text(stringResource(R.string.ok))
                }
            },
        )
    }
    if (state.creating) {
        var name by rememberSaveable { mutableStateOf("") }
        AlertDialog(
            onDismissRequest = onDismiss,
            title = { Text(stringResource(R.string.create_set)) },
            text = {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    placeholder = { Text(stringResource(R.string.create_set_hint)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            },
            confirmButton = {
                TextButton(
                    onClick = { if (name.isNotBlank()) onCreate(name) },
                    enabled = name.isNotBlank(),
                    modifier = Modifier.heightIn(min = 48.dp),
                ) { Text(stringResource(R.string.ok)) }
            },
            dismissButton = {
                TextButton(onClick = onDismiss, modifier = Modifier.heightIn(min = 48.dp)) {
                    Text(stringResource(R.string.cancel))
                }
            },
        )
    }
}

@Composable
private fun Catalog(
    state: SetsUiState,
    japanese: Boolean,
    onGroup: (Long) -> Unit,
    onTag: (TagRecord) -> Unit,
    onCreate: () -> Unit,
    onPractice: () -> Unit,
) {
    val root = state.title.isEmpty()
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 24.dp)) {
        if (root && state.studying != null) {
            item {
                SectionLabel(stringResource(R.string.studying_now))
                val set = state.studying
                val name = displayName(set.name, set.nameJa, japanese)
                val words = pluralStringResource(R.plurals.word_count, set.count, set.count)
                val description = stringResource(R.string.cd_set_row, name, set.count)
                Surface(
                    modifier = Modifier
                        .padding(horizontal = 16.dp)
                        .fillMaxWidth()
                        .heightIn(min = 48.dp)
                        .clickable(role = Role.Button, onClick = onPractice)
                        .semantics { contentDescription = description },
                    shape = MaterialTheme.shapes.large,
                    color = MaterialTheme.colorScheme.surface,
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(name, style = MaterialTheme.typography.titleMedium)
                        Text(
                            words,
                            style = MaterialTheme.typography.bodyMedium,
                            color = LocalStudyColors.current.listSupporting,
                        )
                    }
                }
            }
        }
        if (root) {
            item { SectionLabel(stringResource(R.string.my_sets)) }
            items(state.mySets, key = { "my-${it.id}" }) { tag ->
                TagRow(tag, state.activeId, japanese, onTag)
            }
            item {
                ListItem(
                    headlineContent = { Text(stringResource(R.string.new_set)) },
                    leadingContent = { Icon(painterResource(R.drawable.ic_add), contentDescription = null) },
                    modifier = Modifier
                        .clickable(onClick = onCreate)
                        .heightIn(min = 48.dp),
                )
            }
            item { SectionLabel(stringResource(R.string.built_in_sets)) }
        }
        items(state.groups, key = { "g-${it.id}" }) { group ->
            GroupRow(group, japanese, onGroup)
        }
        items(state.tags, key = { "t-${it.id}" }) { tag ->
            TagRow(tag, state.activeId, japanese, onTag)
        }
    }
}

@Composable
private fun TagList(tags: List<TagRecord>, activeId: Long, japanese: Boolean, onTag: (TagRecord) -> Unit) {
    if (tags.isEmpty()) {
        Text(
            stringResource(R.string.no_results),
            modifier = Modifier.padding(20.dp),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        return
    }
    LazyColumn(Modifier.fillMaxSize()) {
        items(tags, key = { it.id }) { TagRow(it, activeId, japanese, onTag) }
    }
}

@Composable
private fun TagRow(tag: TagRecord, activeId: Long, japanese: Boolean, onTag: (TagRecord) -> Unit) {
    val name = displayName(tag.name, tag.nameJa, japanese)
    val description = stringResource(R.string.cd_set_row, name, tag.count)
    ListItem(
        headlineContent = { Text(name) },
        supportingContent = {
            Text(
                pluralStringResource(R.plurals.word_count, tag.count, tag.count),
                color = LocalStudyColors.current.listSupporting,
            )
        },
        trailingContent = if (tag.id == activeId) {
            { Icon(painterResource(R.drawable.ic_check), contentDescription = stringResource(R.string.current_set)) }
        } else {
            null
        },
        colors = ListItemDefaults.colors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier
            .clickable { onTag(tag) }
            .semantics { contentDescription = description }
            .heightIn(min = 48.dp),
    )
}

@Composable
private fun GroupRow(group: GroupRecord, japanese: Boolean, onGroup: (Long) -> Unit) {
    val name = displayName(group.name, group.nameJa, japanese)
    val detail = groupDetail(group.childGroups, group.setCount)
    ListItem(
        headlineContent = { Text(name) },
        supportingContent = {
            Text(detail, color = LocalStudyColors.current.listSupporting)
        },
        colors = ListItemDefaults.colors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.clickable { onGroup(group.id) }.heightIn(min = 48.dp),
    )
}

@Composable
private fun groupDetail(childGroups: Int, setCount: Int): String {
    val groups = if (childGroups > 0) {
        pluralStringResource(R.plurals.group_count, childGroups, childGroups)
    } else {
        null
    }
    val sets = if (setCount > 0 || childGroups == 0) {
        pluralStringResource(R.plurals.set_count, setCount, setCount)
    } else {
        null
    }
    return listOfNotNull(groups, sets).joinToString(" · ")
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(start = 20.dp, top = 20.dp, bottom = 8.dp),
    )
}
