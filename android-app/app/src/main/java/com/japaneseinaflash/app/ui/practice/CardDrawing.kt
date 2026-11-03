package com.japaneseinaflash.app.ui.practice

import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import com.japaneseinaflash.app.ui.theme.CardTexture

internal fun Modifier.cardTexture(texture: CardTexture, ink: Color): Modifier =
    drawBehind {
        when (texture) {
            CardTexture.None -> Unit
            CardTexture.Seigaiha -> drawSeigaiha(ink.copy(alpha = 0.45f))
            CardTexture.KutaniRim -> drawKutaniRim(ink.copy(alpha = 0.7f))
        }
    }

private fun DrawScope.drawSeigaiha(ink: Color) {
    val radius = 16.dp.toPx()
    var row = 0
    var y = radius
    while (y < size.height + radius) {
        var x = if (row % 2 == 0) radius else radius * 2
        while (x < size.width + radius) {
            drawArc(
                color = ink,
                startAngle = 200f,
                sweepAngle = 140f,
                useCenter = false,
                topLeft = Offset(x - radius, y - radius),
                size = Size(radius * 2, radius * 2),
                style = Stroke(width = 1.dp.toPx()),
            )
            x += radius * 2
        }
        y += radius
        row++
    }
}

private fun DrawScope.drawKutaniRim(ink: Color) {
    val outer = 3.dp.toPx()
    val inner = 6.dp.toPx()
    val corner = 28.dp.toPx()
    drawRoundRect(
        color = ink,
        topLeft = Offset(outer, outer),
        size = Size(size.width - outer * 2, size.height - outer * 2),
        cornerRadius = CornerRadius(corner),
        style = Stroke(width = 1.25.dp.toPx()),
    )
    drawRoundRect(
        color = ink,
        topLeft = Offset(inner, inner),
        size = Size(size.width - inner * 2, size.height - inner * 2),
        cornerRadius = CornerRadius(corner),
        style = Stroke(width = 0.75.dp.toPx()),
    )
}

internal fun DrawScope.levelBar(fraction: Float, fill: Color, track: Color) {
    val radius = CornerRadius(size.height / 2f)
    drawRoundRect(color = track, cornerRadius = radius)
    if (fraction > 0f) {
        drawRoundRect(
            color = fill,
            size = Size(size.width * fraction.coerceIn(0f, 1f), size.height),
            cornerRadius = radius,
        )
    }
}
