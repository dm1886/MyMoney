package com.damianomiazzi.mymoney

import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w800dp-h1000dp")
class AdaptiveLayoutTest {
    @get:Rule val compose = createComposeRule()

    @Test
    fun navigationFitsCompactPhoneThroughTabletAndLargeText() {
        var width by mutableIntStateOf(320)
        var scale by mutableFloatStateOf(1f)
        var selected by mutableIntStateOf(3)
        compose.setContent {
            val density = LocalDensity.current.density
            CompositionLocalProvider(LocalDensity provides Density(density, scale)) {
                MaterialTheme(typography = orbTypography) {
                    Box(Modifier.width(width.dp)) {
                        OrbNavigationBar(selected, orbPresets[0].dark, { selected = it }, {})
                    }
                }
            }
        }
        for (w in listOf(320, 390, 768)) for (s in listOf(1f, 1.4f, 2f)) {
            compose.runOnIdle {
                width = w
                scale = s
                selected = 3
            }
            compose.waitForIdle()
            val sections =
                listOf("Home", "Bilancio", "Oggi", "Resoconto", "More").map {
                    compose
                        .onNodeWithContentDescription(it)
                        .assertIsDisplayed()
                        .fetchSemanticsNode()
                        .boundsInRoot
                }
            val add =
                compose
                    .onNodeWithContentDescription("Nuova transazione")
                    .assertIsDisplayed()
                    .fetchSemanticsNode()
                    .boundsInRoot
            sections.zipWithNext().forEach { (a, b) ->
                assertTrue("Overlapping tabs at $w/$s", a.right <= b.left + 1f)
            }
            assertTrue(sections.last().right <= add.left)
            assertTrue(sections.first().left >= 0)
            compose.onNodeWithContentDescription("Bilancio").performClick()
            compose.runOnIdle { assertEquals(1, selected) }
        }
    }

    @Test
    fun accountFormRemainsUsableOnCompactScreenWithDoubleSizeText() {
        val userId = "adaptive-${System.nanoTime()}"
        compose.setContent {
            val density = LocalDensity.current.density
            CompositionLocalProvider(LocalDensity provides Density(density, 2f)) {
                Box(Modifier.width(320.dp).height(640.dp)) { MyMoneyApp(userId = userId) }
            }
        }
        compose.onNodeWithContentDescription("Nuova transazione").performClick()
        compose.onNodeWithText("Nome").performScrollTo().performTextInput("Conto accessibile")
        compose
            .onNodeWithText("Saldo iniziale")
            .performScrollTo()
            .performTextReplacement("1234567890,12")
        compose
            .onNodeWithText("Salva conto")
            .performScrollTo()
            .assertIsDisplayed()
            .performSemanticsAction(androidx.compose.ui.semantics.SemanticsActions.OnClick) { it() }
        compose.waitForIdle()
        val ledger =
            LedgerStore(androidx.test.core.app.ApplicationProvider.getApplicationContext(), userId)
                .read()
        assertEquals("1234567890.12".toBigDecimal(), ledger.accounts.single().initial)
    }
}
