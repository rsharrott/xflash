package com.japaneseinaflash.app.ui

import android.content.Context
import android.provider.Settings
import android.speech.tts.TextToSpeech
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconToggleButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.adaptive.currentWindowAdaptiveInfo
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteScaffold
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteScaffoldDefaults
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteScope
import androidx.compose.material3.adaptive.navigationsuite.NavigationSuiteType
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.japaneseinaflash.app.R
import com.japaneseinaflash.app.ui.practice.LevelStrip
import com.japaneseinaflash.app.ui.practice.PracticeScreen
import com.japaneseinaflash.app.ui.theme.JifTheme
import com.japaneseinaflash.app.ui.theme.ThemeSheet
import com.japaneseinaflash.app.ui.theme.rememberAppDark
import java.util.Locale

private object Routes {
    const val Practice = "practice"
    const val Sets = "sets"
    const val Search = "search"
    const val Card = "card/{cardId}"
    const val Settings = "settings"
    const val About = "about"
    const val Group = "sets/group/{groupId}"
    const val Difficulty = "settings/difficulty"
    const val Help = "settings/help"
    const val HelpPage = "settings/help/{index}"
    fun card(id: Long) = "card/$id"
    fun group(id: Long) = "sets/group/$id"
    fun helpPage(index: Int) = "settings/help/$index"
}

@Composable
fun JapaneseApp(
    session: DictionaryViewModel = viewModel(),
    preferencesModel: PreferencesViewModel = viewModel(),
    actions: CardActionsViewModel = viewModel(
        factory = CardActionsViewModel.factory(session, preferencesModel.store),
    ),
) {
    val preferences by preferencesModel.preferences.collectAsStateWithLifecycle()
    val dark = rememberAppDark(preferences.theme, preferences.darkMode)
    val nav = rememberNavController()
    val current = nav.currentBackStackEntryAsState().value?.destination?.route
    val topLevel = current == null || current in setOf(Routes.Practice, Routes.Sets, Routes.Search, Routes.Settings)
    var themesOpen by rememberSaveable { mutableStateOf(false) }
    val suite = if (!topLevel) {
        NavigationSuiteType.None
    } else {
        NavigationSuiteScaffoldDefaults.calculateFromAdaptiveInfo(currentWindowAdaptiveInfo())
    }
    JifTheme(theme = preferences.theme, dark = dark) {
        NavigationSuiteScaffold(
            layoutType = suite,
            navigationSuiteItems = {
                suiteItem(nav, Routes.Practice, current, R.string.nav_practice, R.drawable.ic_practice)
                suiteItem(nav, Routes.Sets, current, R.string.nav_study_sets, R.drawable.ic_sets)
                suiteItem(nav, Routes.Search, current, R.string.nav_search, R.drawable.ic_search)
                suiteItem(nav, Routes.Settings, current, R.string.nav_settings, R.drawable.ic_settings)
            },
        ) {
            AppNavHost(
                nav = nav,
                session = session,
                preferencesModel = preferencesModel,
                actions = actions,
                onTheme = { themesOpen = true },
            )
        }
        val sheet by actions.sheet.collectAsStateWithLifecycle()
        sheet?.let { addState ->
            AddToSetSheet(
                state = addState,
                onToggle = actions::toggle,
                onCreate = actions::create,
                onStartCreate = actions::startCreate,
                onCancelCreate = actions::cancelCreate,
                onDone = actions::dismiss,
            )
        }
        val lastCard by actions.lastCard.collectAsStateWithLifecycle()
        if (lastCard) {
            AlertDialog(
                onDismissRequest = actions::dismissLastCard,
                text = { Text(stringResource(R.string.last_card_message)) },
                confirmButton = {
                    TextButton(onClick = actions::dismissLastCard) {
                        Text(stringResource(R.string.ok))
                    }
                },
            )
        }
        if (themesOpen) {
            ThemeSheet(
                selected = preferences.theme,
                dark = dark,
                onSelect = preferencesModel::setTheme,
                onDismiss = { themesOpen = false },
            )
        }
    }
}

private fun NavigationSuiteScope.suiteItem(
    nav: NavHostController,
    route: String,
    current: String?,
    label: Int,
    icon: Int,
) {
    item(
        selected = current == route || (route == Routes.Search && current?.startsWith("card/") == true),
        onClick = {
            nav.navigate(route) {
                popUpTo(nav.graph.findStartDestination().id) { saveState = true }
                launchSingleTop = true
                restoreState = true
            }
        },
        icon = { Icon(painterResource(icon), contentDescription = null) },
        label = { Text(stringResource(label)) },
    )
}

@Composable
private fun AppNavHost(
    nav: NavHostController,
    session: DictionaryViewModel,
    preferencesModel: PreferencesViewModel,
    actions: CardActionsViewModel,
    onTheme: () -> Unit,
) {
    val reduceMotion = reducedMotion()
    NavHost(
        navController = nav,
        startDestination = Routes.Practice,
        enterTransition = { if (reduceMotion) androidx.compose.animation.EnterTransition.None else androidx.compose.animation.fadeIn() },
        exitTransition = { if (reduceMotion) androidx.compose.animation.ExitTransition.None else androidx.compose.animation.fadeOut() },
        popEnterTransition = { if (reduceMotion) androidx.compose.animation.EnterTransition.None else androidx.compose.animation.fadeIn() },
        popExitTransition = {
            if (reduceMotion) {
                androidx.compose.animation.ExitTransition.None
            } else {
                androidx.compose.animation.scaleOut(targetScale = 0.92f) + androidx.compose.animation.fadeOut()
            }
        },
    ) {
        composable(Routes.Practice) {
            PracticeRoute(session, preferencesModel, onTheme) { id -> actions.open(id) }
        }
        composable(Routes.Sets) {
            SetsRoute(groupId = null, nav = nav, session = session, preferencesModel = preferencesModel)
        }
        composable(
            route = Routes.Group,
            arguments = listOf(navArgument("groupId") { type = NavType.StringType }),
        ) { entry ->
            val id = entry.arguments?.getString("groupId")?.toLongOrNull()
            SetsRoute(groupId = id, nav = nav, session = session, preferencesModel = preferencesModel)
        }
        composable(Routes.Search) {
            val state by session.state.collectAsStateWithLifecycle()
            Centered {
                SearchPane(
                    state = state,
                    onQueryChange = session::onQueryChange,
                    onSubmit = session::submit,
                    onCard = { id -> nav.navigate(Routes.card(id)) },
                    onAdd = { actions.open(it.id) },
                    onRetry = session::retry,
                )
            }
        }
        composable(
            route = Routes.Card,
            arguments = listOf(navArgument("cardId") { type = NavType.StringType }),
        ) { entry ->
            val id = entry.arguments?.getString("cardId")?.toLongOrNull()
            DetailRoute(session, actions, id, onBack = { nav.popBackStack() })
        }
        composable(Routes.Settings) {
            val preferences by preferencesModel.preferences.collectAsStateWithLifecycle()
            SettingsScreen(
                preferences = preferences,
                onTheme = onTheme,
                onLanguage = preferencesModel::setLanguage,
                onReading = preferencesModel::setReading,
                onKana = preferencesModel::setKana,
                onDark = preferencesModel::setDarkMode,
                onDifficulty = { nav.navigate(Routes.Difficulty) },
                onHelp = { nav.navigate(Routes.Help) },
                onAbout = { nav.navigate(Routes.About) },
            )
        }
        composable(Routes.Difficulty) {
            val preferences by preferencesModel.preferences.collectAsStateWithLifecycle()
            DifficultyScreen(
                preferences = preferences,
                onDifficulty = preferencesModel::setDifficulty,
                onCustom = preferencesModel::setCustom,
                onHide = preferencesModel::setHideLearned,
                onBack = { nav.popBackStack() },
            )
        }
        composable(Routes.Help) {
            Column(Modifier.fillMaxSize()) {
                Masthead(stringResource(R.string.help), onBack = { nav.popBackStack() })
                HelpList(onOpen = { topic ->
                    val index = HelpTopics.indexOf(topic)
                    if (index >= 0) nav.navigate(Routes.helpPage(index))
                })
            }
        }
        composable(
            route = Routes.HelpPage,
            arguments = listOf(navArgument("index") { type = NavType.StringType }),
        ) { entry ->
            val index = entry.arguments?.getString("index")?.toIntOrNull() ?: 0
            val topic = HelpTopics.getOrElse(index) { HelpTopics.first() }
            val japanese = LocalConfiguration.current.locales[0].language == "ja"
            val pagePreferences by preferencesModel.preferences.collectAsStateWithLifecycle()
            val pageDark = rememberAppDark(pagePreferences.theme, pagePreferences.darkMode)
            HelpPage(
                topic,
                japanese,
                dark = pageDark,
                fontScale = LocalDensity.current.fontScale,
                onBack = { nav.popBackStack() },
            )
        }
        composable(Routes.About) {
            val state by session.state.collectAsStateWithLifecycle()
            AboutRoute(state.versions, onBack = { nav.popBackStack() })
        }
    }
}

@Composable
private fun SetsRoute(
    groupId: Long?,
    nav: NavHostController,
    session: DictionaryViewModel,
    preferencesModel: PreferencesViewModel,
) {
    val dictionary by session.state.collectAsStateWithLifecycle()
    val model: StudySetsViewModel = viewModel(
        factory = StudySetsViewModel.factory(session, preferencesModel.store, groupId),
    )
    val state by model.state.collectAsStateWithLifecycle()
    // Built-in names follow the device locale, as iOS LWEBuiltInCatalogUsesJapanese does.
    val japanese = LocalConfiguration.current.locales[0].language == "ja"
    when (dictionary.phase) {
        Phase.Preparing -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text(stringResource(R.string.preparing_dictionary))
        }
        Phase.Failed -> Box(Modifier.padding(20.dp)) {
            Text(stringResource(R.string.error_prepare), color = MaterialTheme.colorScheme.error)
        }
        Phase.Ready -> StudySetsScreen(
            state = state,
            japanese = japanese,
            onQuery = model::onQuery,
            onGroup = { nav.navigate(Routes.group(it)) },
            onTag = model::askToStart,
            onCreate = model::create,
            onStartCreate = model::startCreate,
            onConfirm = {
                model.confirmStart {
                    nav.navigate(Routes.Practice) {
                        popUpTo(nav.graph.findStartDestination().id) { saveState = true }
                        launchSingleTop = true
                        restoreState = true
                    }
                }
            },
            onDismiss = model::dismissDialogs,
            onPractice = {
                nav.navigate(Routes.Practice) {
                    popUpTo(nav.graph.findStartDestination().id) { saveState = true }
                    launchSingleTop = true
                    restoreState = true
                }
            },
            onBack = if (groupId != null) {
                { nav.popBackStack() }
            } else {
                null
            },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PracticeRoute(
    session: DictionaryViewModel,
    preferencesModel: PreferencesViewModel,
    onTheme: () -> Unit,
    onAdd: (Long) -> Unit,
) {
    val practice: PracticeViewModel = viewModel(
        factory = PreferencesViewModel.practiceFactory(session, preferencesModel.store),
    )
    val state by practice.state.collectAsStateWithLifecycle()
    val dictionary by session.state.collectAsStateWithLifecycle()
    val preferences by preferencesModel.preferences.collectAsStateWithLifecycle()
    var progress by rememberSaveable { mutableStateOf(false) }
    val speaker = rememberSpeaker()
    var menu by remember { mutableStateOf(false) }
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text(state.setName.ifBlank { stringResource(R.string.nav_practice) }) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                    titleContentColor = MaterialTheme.colorScheme.onBackground,
                ),
                actions = {
                    IconButton(onClick = onTheme) {
                        Icon(painterResource(R.drawable.ic_palette), contentDescription = stringResource(R.string.cd_palette))
                    }
                    IconButton(onClick = { menu = true }) {
                        Icon(painterResource(R.drawable.ic_more), contentDescription = stringResource(R.string.cd_more))
                    }
                    DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.add_to_set)) },
                            enabled = state.card != null,
                            onClick = {
                                menu = false
                                state.card?.detail?.id?.let(onAdd)
                            },
                        )
                    }
                },
            )
        },
    ) { padding ->
        when (dictionary.phase) {
            Phase.Preparing -> Box(Modifier.padding(padding).fillMaxSize()) { PreparingCopy() }
            Phase.Failed -> Box(Modifier.padding(padding).padding(20.dp)) {
                Text(stringResource(R.string.error_prepare), color = MaterialTheme.colorScheme.error)
            }
            Phase.Ready -> PracticeScreen(
                state = state,
                preferences = preferences,
                onShowAnswer = practice::showAnswer,
                onToggleReading = practice::toggleReading,
                onSpeak = { state.card?.detail?.headword?.let(speaker::speak) },
                onMark = practice::mark,
                onLevels = { progress = true },
                modifier = Modifier.padding(padding),
            )
        }
        if (progress) {
            ProgressSheet(state, onDismiss = { progress = false })
        }
        if (state.allLearned) {
            AlertDialog(
                onDismissRequest = practice::dismissAllLearned,
                title = { Text(stringResource(R.string.study_set_learned)) },
                text = { Text(stringResource(R.string.study_set_learned_message)) },
                confirmButton = {
                    TextButton(onClick = practice::dismissAllLearned) {
                        Text(stringResource(R.string.ok))
                    }
                },
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ProgressSheet(state: PracticeUiState, onDismiss: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Text(
            stringResource(R.string.study_progress),
            style = MaterialTheme.typography.titleLarge,
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
        )
        LevelStrip(
            levels = state.levels,
            total = state.total,
            onClick = {},
            asButton = false,
            modifier = Modifier.padding(16.dp),
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DetailRoute(
    session: DictionaryViewModel,
    actions: CardActionsViewModel,
    cardId: Long?,
    onBack: () -> Unit,
) {
    val state by session.state.collectAsStateWithLifecycle()
    val starred by actions.starred.collectAsStateWithLifecycle()
    val scroll = rememberScrollState()
    LaunchedEffect(cardId) {
        if (cardId != null) {
            session.loadCard(cardId)
            actions.refreshStar(cardId)
        }
    }
    val title = state.card?.headword ?: stringResource(R.string.card_loading_title)
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        title,
                        style = MaterialTheme.typography.titleLarge.withJapaneseGlyphs(),
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(painterResource(R.drawable.ic_arrow_back), contentDescription = stringResource(R.string.back))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                    titleContentColor = MaterialTheme.colorScheme.onBackground,
                ),
                actions = {
                    if (cardId != null) {
                        IconToggleButton(
                            checked = starred[cardId] == true,
                            onCheckedChange = { actions.setStar(cardId, it) },
                        ) {
                            Icon(
                                painterResource(if (starred[cardId] == true) R.drawable.ic_star else R.drawable.ic_star_border),
                                contentDescription = stringResource(
                                    if (starred[cardId] == true) R.string.cd_starred else R.string.cd_not_starred,
                                ),
                            )
                        }
                    }
                },
            )
        },
        floatingActionButton = {
            if (cardId != null && state.card != null) {
                ExtendedFloatingActionButton(
                    expanded = !scroll.isScrollInProgress,
                    onClick = { actions.open(cardId) },
                    icon = { Icon(painterResource(R.drawable.ic_playlist_add), contentDescription = null) },
                    text = { Text(stringResource(R.string.add_to_set)) },
                )
            }
        },
    ) { padding ->
        Box(Modifier.padding(padding).fillMaxSize(), contentAlignment = Alignment.TopCenter) {
            Box(Modifier.widthIn(max = 640.dp).fillMaxSize()) {
                DetailPane(state, scroll)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AboutRoute(versions: com.japaneseinaflash.app.data.DataVersions?, onBack: () -> Unit) {
    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.about_title)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(painterResource(R.drawable.ic_arrow_back), contentDescription = stringResource(R.string.back))
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.background),
            )
        },
    ) { padding ->
        Box(Modifier.padding(padding).fillMaxSize(), contentAlignment = Alignment.TopCenter) {
            Box(Modifier.widthIn(max = 640.dp).fillMaxSize()) {
                AboutPane(versions, appVersionName())
            }
        }
    }
}

@Composable
private fun Centered(content: @Composable () -> Unit) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.TopCenter) {
        Box(Modifier.widthIn(max = 640.dp).fillMaxSize()) { Column(Modifier.fillMaxSize()) { content() } }
    }
}

@Composable
private fun PreparingCopy() {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(stringResource(R.string.preparing_dictionary), style = MaterialTheme.typography.titleMedium)
    }
}

@Composable
private fun reducedMotion(): Boolean {
    val context = LocalContext.current
    return remember {
        val scale = Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f)
        scale == 0f
    }
}

@Composable
private fun rememberSpeaker(): Speaker {
    val context = LocalContext.current
    val speaker = remember { Speaker(context) }
    DisposableEffect(speaker) {
        onDispose { speaker.close() }
    }
    return speaker
}

private class Speaker(context: Context) : AutoCloseable {
    private var ready = false
    private val tts: TextToSpeech = TextToSpeech(context.applicationContext) { status: Int ->
        ready = status == TextToSpeech.SUCCESS
    }

    fun speak(text: String) {
        if (!ready || text.isBlank()) return
        tts.setLanguage(Locale.JAPANESE)
        tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "card")
    }

    override fun close() {
        tts.shutdown()
    }
}

@Composable
private fun appVersionName(): String {
    val context = LocalContext.current
    return remember(context.packageName) {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        info.versionName.orEmpty()
    }
}
