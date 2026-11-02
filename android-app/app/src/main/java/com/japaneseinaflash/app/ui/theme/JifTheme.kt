package com.japaneseinaflash.app.ui.theme

import android.app.Activity
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.japaneseinaflash.app.study.StudyTheme
import com.japaneseinaflash.app.theme.TokenColors

val LocalStudyColors = staticCompositionLocalOf { studyColors(StudyTheme.PAPER, dark = false) }

private val JifTypography = Typography(
    headlineMedium = TextStyle(
        fontFamily = FontFamily.Serif,
        fontWeight = FontWeight.SemiBold,
        fontSize = 28.sp,
        lineHeight = 34.sp,
    ),
    titleLarge = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.SemiBold,
        fontSize = 22.sp,
        lineHeight = 28.sp,
    ),
    titleMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Medium,
        fontSize = 18.sp,
        lineHeight = 24.sp,
    ),
    bodyLarge = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 17.sp,
        lineHeight = 24.sp,
    ),
    bodyMedium = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontSize = 15.sp,
        lineHeight = 22.sp,
    ),
    labelLarge = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.Medium,
        fontSize = 14.sp,
        lineHeight = 18.sp,
    ),
    labelSmall = TextStyle(
        fontFamily = FontFamily.SansSerif,
        fontWeight = FontWeight.SemiBold,
        fontSize = 11.sp,
        lineHeight = 14.sp,
    ),
)

fun jifColorScheme(theme: StudyTheme, dark: Boolean): ColorScheme {
    val study = studyColors(theme, dark)
    val tint = study.bar
    return if (dark) {
        darkColorScheme(
            primary = tint,
            onPrimary = Color(TokenColors.INK),
            primaryContainer = Color(TokenColors.INK_2),
            onPrimaryContainer = Color(TokenColors.PAPER),
            secondary = tint,
            onSecondary = Color(TokenColors.INK),
            secondaryContainer = Color(TokenColors.INK_2),
            onSecondaryContainer = Color(TokenColors.PAPER),
            background = Color(TokenColors.INK),
            onBackground = Color(TokenColors.PAPER),
            surface = Color(TokenColors.DARK_SURFACE),
            onSurface = Color(TokenColors.PAPER),
            surfaceVariant = Color(TokenColors.INK_2),
            onSurfaceVariant = Color(TokenColors.LINE),
            surfaceContainerHigh = Color(TokenColors.INK_2),
            surfaceContainer = Color(TokenColors.DARK_SURFACE),
            outline = Color(TokenColors.FADED),
            outlineVariant = Color(TokenColors.DARK_TRACK),
            error = tint,
            onError = Color(TokenColors.INK),
        )
    } else {
        lightColorScheme(
            primary = tint,
            onPrimary = Color(TokenColors.WHITE),
            primaryContainer = Color(TokenColors.PAPER_BUTTON),
            onPrimaryContainer = Color(TokenColors.INK),
            secondary = tint,
            onSecondary = Color(TokenColors.WHITE),
            secondaryContainer = Color(TokenColors.PAPER_BUTTON),
            onSecondaryContainer = Color(TokenColors.INK_2),
            background = Color(TokenColors.PAPER_2),
            onBackground = Color(TokenColors.INK),
            surface = Color(TokenColors.PAPER),
            onSurface = Color(TokenColors.INK),
            surfaceVariant = Color(TokenColors.PAPER_BUTTON),
            onSurfaceVariant = Color(TokenColors.INK_2),
            surfaceContainerHigh = Color(TokenColors.PAPER_RAISED),
            surfaceContainer = Color(TokenColors.PAPER),
            outline = Color(TokenColors.MUTED),
            outlineVariant = Color(TokenColors.LINE),
            error = tint,
            onError = Color(TokenColors.WHITE),
        )
    }
}

@Composable
fun JifTheme(
    theme: StudyTheme,
    dark: Boolean,
    content: @Composable () -> Unit,
) {
    val scheme = jifColorScheme(theme, dark)
    val study = studyColors(theme, dark)
    SystemBars(dark)
    CompositionLocalProvider(LocalStudyColors provides study) {
        MaterialTheme(
            colorScheme = scheme,
            typography = JifTypography,
            content = content,
        )
    }
}

@Composable
private fun SystemBars(dark: Boolean) {
    val view = LocalView.current
    if (view.isInEditMode) return
    val paper = Color(TokenColors.PAPER_2).toArgb()
    val ink = Color(TokenColors.INK).toArgb()
    SideEffect {
        val activity = view.context as? ComponentActivity ?: (view.context as? Activity) ?: return@SideEffect
        if (activity is ComponentActivity) {
            activity.enableEdgeToEdge(
                statusBarStyle = if (dark) SystemBarStyle.dark(ink) else SystemBarStyle.light(paper, paper),
                navigationBarStyle = if (dark) SystemBarStyle.dark(ink) else SystemBarStyle.light(paper, paper),
            )
        }
    }
}

@Composable
fun rememberAppDark(theme: StudyTheme, mode: com.japaneseinaflash.app.study.DarkMode): Boolean =
    com.japaneseinaflash.app.study.usesDarkChrome(theme, mode, isSystemInDarkTheme())
