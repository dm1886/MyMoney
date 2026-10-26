package com.damianomiazzi.mymoney

import androidx.compose.material3.Typography
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.sp

data class OrbPalette(val values: List<Color>) {
    val bg
        get() = values[0]

    val card
        get() = values[1]

    val card2
        get() = values[2]

    val line
        get() = values[3]

    val text
        get() = values[4]

    val muted
        get() = values[5]

    val primary
        get() = values[6]

    val secondary
        get() = values[7]

    val positive
        get() = values[8]

    val negative
        get() = values[9]

    val highlight
        get() = values[10]

    val on
        get() = values[11]
}

data class OrbPreset(val name: String, val dark: OrbPalette, val light: OrbPalette)

private fun palette(s: String) =
    OrbPalette(s.split(" ").map { Color(android.graphics.Color.parseColor(it)) })

val orbPresets =
    listOf(
        OrbPreset(
            "Notte",
            palette(
                "#0C0B1A #17162C #2A2650 #3A3766 #E9E7FF #9D9AC2 #6B4DFF #FF6A8A #7EE2A8 #FF8FA6 #B9A8FF #FFFFFF"
            ),
            palette(
                "#F4F1FF #FFFFFF #ECE7FF #D8D0F5 #1B1640 #615B85 #6B4DFF #FF6A8A #12805C #C2304F #6B4DFF #FFFFFF"
            ),
        ),
        OrbPreset(
            "Aurora",
            palette(
                "#07161A #0F2429 #173A40 #24525A #E3FBF6 #8FB8B1 #0B7A6E #A3E635 #A3E635 #FF9B85 #5EEAD4 #FFFFFF"
            ),
            palette(
                "#EEF8F6 #FFFFFF #DCF1EC #C3E3DC #0B2A26 #4D6E68 #0B7A6E #65A30D #3F7D0A #C2410C #0B7A6E #FFFFFF"
            ),
        ),
        OrbPreset(
            "Brace",
            palette(
                "#140C08 #24160F #3A2216 #5A3524 #FFF1E8 #C4A493 #C2410C #FFB703 #9BE38A #FF8A7A #FFB98A #FFFFFF"
            ),
            palette(
                "#FBF3EE #FFFFFF #F6E4D8 #ECD2C1 #2A160C #7A5A48 #C2410C #D98E04 #2F7D32 #B42318 #C2410C #FFFFFF"
            ),
        ),
        OrbPreset(
            "Oceano",
            palette(
                "#050B18 #0D1830 #16264A #26406E #E6EFFF #8EA3C8 #2563EB #22D3EE #6EE7B7 #FDA4AF #93C5FD #FFFFFF"
            ),
            palette(
                "#EEF3FC #FFFFFF #DFE8FA #C9D7F2 #0B1A33 #4F6185 #2563EB #0891B2 #047857 #BE123C #2563EB #FFFFFF"
            ),
        ),
        OrbPreset(
            "Grafite",
            palette(
                "#121316 #1D1F24 #2A2D34 #3A3E48 #F1F2F4 #A3A8B3 #D4F25C #5B8CFF #D4F25C #FF9F6B #D4F25C #121316"
            ),
            palette(
                "#F2F3F1 #FFFFFF #E6E8E3 #D4D7D0 #16181C #5D636E #4D7C0F #3B6EF5 #4D7C0F #C2410C #4D7C0F #FFFFFF"
            ),
        ),
    )
// Same Sora face and semantic sizes as Font.orb in OrbComponents.swift.
val sora = FontFamily(Font(R.font.sora))

private fun orb(
    size: Int,
    weight: androidx.compose.ui.text.font.FontWeight =
        androidx.compose.ui.text.font.FontWeight.Normal,
) = TextStyle(fontFamily = sora, fontSize = size.sp, fontWeight = weight)

val orbTypography =
    Typography(
        displayLarge = orb(38, androidx.compose.ui.text.font.FontWeight.Bold),
        displayMedium = orb(38, androidx.compose.ui.text.font.FontWeight.Bold),
        displaySmall = orb(26, androidx.compose.ui.text.font.FontWeight.Bold),
        headlineLarge = orb(26, androidx.compose.ui.text.font.FontWeight.Bold),
        headlineMedium = orb(22, androidx.compose.ui.text.font.FontWeight.Bold),
        headlineSmall = orb(19, androidx.compose.ui.text.font.FontWeight.SemiBold),
        titleLarge = orb(22, androidx.compose.ui.text.font.FontWeight.Bold),
        titleMedium = orb(19, androidx.compose.ui.text.font.FontWeight.SemiBold),
        titleSmall = orb(16, androidx.compose.ui.text.font.FontWeight.SemiBold),
        bodyLarge = orb(14),
        bodyMedium = orb(13),
        bodySmall = orb(12),
        labelLarge = orb(16, androidx.compose.ui.text.font.FontWeight.SemiBold),
        labelMedium = orb(11),
        labelSmall = orb(10),
    )
