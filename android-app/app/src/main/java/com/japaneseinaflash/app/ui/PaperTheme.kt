package com.japaneseinaflash.app.ui

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.colorResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.japaneseinaflash.app.R

@Composable
private fun paperColorScheme(): ColorScheme = lightColorScheme(
    primary = colorResource(R.color.seal),
    onPrimary = colorResource(R.color.paper),
    primaryContainer = colorResource(R.color.seal_soft),
    onPrimaryContainer = colorResource(R.color.ink),
    secondary = colorResource(R.color.moss),
    onSecondary = colorResource(R.color.paper),
    background = colorResource(R.color.paper),
    onBackground = colorResource(R.color.ink),
    surface = colorResource(R.color.paper_raised),
    onSurface = colorResource(R.color.ink),
    surfaceVariant = colorResource(R.color.seal_soft),
    onSurfaceVariant = colorResource(R.color.ink_muted),
    outline = colorResource(R.color.rule),
    error = colorResource(R.color.seal),
    onError = colorResource(R.color.paper),
)

private val PaperTypography = Typography(
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
)

@Composable
fun PaperTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = paperColorScheme(),
        typography = PaperTypography,
        content = content,
    )
}
