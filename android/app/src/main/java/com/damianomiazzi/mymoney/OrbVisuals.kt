package com.damianomiazzi.mymoney

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.*

/** Capsule B: only the selected section has a label; the add button is separate. */
@Composable
fun OrbNavigationBar(selected: Int, p: OrbPalette, select: (Int) -> Unit, onAdd: () -> Unit) {
    Box(Modifier.fillMaxWidth().navigationBarsPadding(), contentAlignment = Alignment.Center) {
        BoxWithConstraints(
            Modifier.widthIn(max = 508.dp)
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            // Reflow at narrow widths or accessibility text sizes instead of shrinking text.
            val showLabel =
                maxWidth >= (300 + 50 * LocalDensity.current.fontScale).dp &&
                    LocalDensity.current.fontScale < 1.5f
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Row(
                    Modifier.weight(1f)
                        .height(60.dp)
                        .background(p.card, CircleShape)
                        .border(1.dp, p.line, CircleShape)
                        .padding(horizontal = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    val labels = listOf("Home", "Bilancio", "Oggi", "Resoconto", "More")
                    labels.forEachIndexed { index, label ->
                        Row(
                            Modifier.height(48.dp)
                                .widthIn(min = 40.dp)
                                .background(
                                    if (selected == index) p.primary
                                    else androidx.compose.ui.graphics.Color.Transparent,
                                    CircleShape,
                                )
                                .selectable(
                                    selected == index,
                                    role = Role.Tab,
                                    onClick = { select(index) },
                                )
                                .padding(
                                    horizontal = if (selected == index && showLabel) 8.dp else 0.dp
                                ),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.Center,
                        ) {
                            OrbSectionIcon(index, label, if (selected == index) p.on else p.muted)
                            if (selected == index && showLabel) {
                                Spacer(Modifier.width(5.dp))
                                Text(label, fontSize = 11.sp, color = p.on, maxLines = 1)
                            }
                        }
                    }
                }
                FilledIconButton(
                    onClick = onAdd,
                    modifier = Modifier.size(60.dp),
                    colors =
                        IconButtonDefaults.filledIconButtonColors(
                            containerColor = p.secondary,
                            contentColor = secondaryForeground(p),
                        ),
                ) {
                    Icon(Icons.Default.Add, "Nuova transazione", Modifier.size(24.dp))
                }
            }
        }
    }
}

/** Same stationary phase and blob equation as iOS BlobShape; no scaled bitmap. */
@Composable
fun OrbGraphic(p: OrbPalette, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        fun blob(inset: Float): Path {
            val radius = size.minDimension * .43f * inset
            return Path().apply {
                for (i in 0..120) {
                    val angle = i / 120.0 * PI * 2
                    val r = radius * (1 + .085 * sin(angle * 3) + .045 * cos(angle * 5))
                    val x = (center.x + cos(angle) * r).toFloat()
                    val y = (center.y + sin(angle) * r).toFloat()
                    if (i == 0) moveTo(x, y) else lineTo(x, y)
                }
                close()
            }
        }
        drawPath(blob(1f), p.primary)
        val dark = p == orbPresets.find { it.dark == p }?.dark
        drawPath(
            blob(.88f),
            p.secondary,
            alpha = .55f,
            blendMode = if (dark) BlendMode.Screen else BlendMode.Multiply,
        )
    }
}

private fun secondaryForeground(p: OrbPalette): androidx.compose.ui.graphics.Color {
    fun luminance(c: androidx.compose.ui.graphics.Color): Double {
        fun channel(x: Float) = if (x <= .04045f) x / 12.92 else ((x + .055) / 1.055).pow(2.4)
        return .2126 * channel(c.red) + .7152 * channel(c.green) + .0722 * channel(c.blue)
    }
    val whiteContrast = 1.05 / (luminance(p.secondary) + .05)
    return if (whiteContrast >= 3) androidx.compose.ui.graphics.Color.White
    else androidx.compose.ui.graphics.Color(0xFF121316)
}

@Composable
private fun OrbSectionIcon(index: Int, label: String, color: androidx.compose.ui.graphics.Color) {
    Canvas(Modifier.size(20.dp).semantics { contentDescription = label }) {
        scale(size.width / 24f, size.height / 24f, pivot = Offset.Zero) {
            when (index) {
                0 -> {
                    val home =
                        Path().apply {
                            moveTo(2f, 11f)
                            lineTo(12f, 2f)
                            lineTo(22f, 11f)
                            lineTo(20f, 11f)
                            lineTo(20f, 22f)
                            lineTo(14f, 22f)
                            lineTo(14f, 15f)
                            lineTo(10f, 15f)
                            lineTo(10f, 22f)
                            lineTo(4f, 22f)
                            lineTo(4f, 11f)
                            close()
                        }
                    drawPath(home, color)
                }
                1 -> {
                    drawRoundRect(
                        color,
                        Offset(3f, 13f),
                        Size(4f, 9f),
                        androidx.compose.ui.geometry.CornerRadius(1f),
                    )
                    drawRoundRect(
                        color,
                        Offset(10f, 7f),
                        Size(4f, 15f),
                        androidx.compose.ui.geometry.CornerRadius(1f),
                    )
                    drawRoundRect(
                        color,
                        Offset(17f, 2f),
                        Size(4f, 20f),
                        androidx.compose.ui.geometry.CornerRadius(1f),
                    )
                }
                2 -> {
                    drawRoundRect(
                        color,
                        Offset(3f, 5f),
                        Size(18f, 17f),
                        androidx.compose.ui.geometry.CornerRadius(2f),
                        style = Stroke(2f),
                    )
                    drawLine(color, Offset(3f, 10f), Offset(21f, 10f), 2f)
                    drawLine(color, Offset(7f, 2f), Offset(7f, 7f), 2f)
                    drawLine(color, Offset(17f, 2f), Offset(17f, 7f), 2f)
                }
                3 -> {
                    drawRoundRect(
                        color,
                        Offset(2f, 3f),
                        Size(20f, 18f),
                        androidx.compose.ui.geometry.CornerRadius(2f),
                        style = Stroke(2f),
                    )
                    for (i in 0..2) drawLine(
                        color,
                        Offset(6f, 7f + i * 5),
                        Offset(12f + i * 3, 7f + i * 5),
                        2f,
                    )
                }
                else -> for (i in 0..2) drawCircle(color, 1.8f, Offset(5f + i * 7, 12f))
            }
        }
    }
}
