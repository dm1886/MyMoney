package com.damianomiazzi.mymoney

import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createComposeRule
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], qualifiers = "w411dp-h891dp")
class UiTest {
    @get:Rule val compose = createComposeRule()

    @Test
    fun accountAndExpenseCanBeSavedThroughForms() {
        val userId = "ui-${System.nanoTime()}"
        compose.setContent { MyMoneyApp(userId = userId) }
        compose.onNodeWithContentDescription("Nuova transazione").performClick()
        compose.onNodeWithText("Nome").performTextInput("Conto QA")
        compose.onNodeWithText("Saldo iniziale").performTextReplacement("1000,25")
        compose.onNodeWithText("Salva conto").performScrollTo().performSemanticsAction(
            androidx.compose.ui.semantics.SemanticsActions.OnClick
        ) {
            it()
        }
        compose.waitForIdle()
        org.junit.Assert.assertEquals(
            1,
            LedgerStore(androidx.test.core.app.ApplicationProvider.getApplicationContext(), userId)
                .read()
                .accounts
                .size,
        )
        compose.mainClock.advanceTimeBy(1000)
        compose.waitForIdle()
        compose.onNodeWithText("Conto QA").assertExists()
        compose.onNodeWithContentDescription("Nuova transazione").performClick()
        compose.mainClock.advanceTimeBy(1000)
        compose.waitForIdle()
        compose.onNodeWithText("Importo").performTextInput("12,35")
        compose.onNodeWithText("Note").performTextInput("Supermercato QA")
        compose.onNodeWithText("Salva transazione").performScrollTo().performSemanticsAction(
            androidx.compose.ui.semantics.SemanticsActions.OnClick
        ) {
            it()
        }
        compose.mainClock.advanceTimeBy(1000)
        compose.waitForIdle()
        val restored =
            LedgerStore(androidx.test.core.app.ApplicationProvider.getApplicationContext(), userId)
                .read()
        org.junit.Assert.assertEquals(
            "987.90".toBigDecimal(),
            restored.balance(restored.accounts.single()),
        )
        compose
            .onAllNodes(hasScrollAction())
            .onFirst()
            .performScrollToNode(hasText("Supermercato QA"))
        compose.onNodeWithText("Supermercato QA").assertExists()
    }
}
