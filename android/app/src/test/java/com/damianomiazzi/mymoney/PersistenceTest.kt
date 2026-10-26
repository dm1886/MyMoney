package com.damianomiazzi.mymoney

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class PersistenceTest {
    @Test
    fun exactDecimalAndSnapshotsSurviveRestart() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val a = MoneyAccount(id = "a", name = "Conto", initial = "1000.25".toBigDecimal())
        val b = MoneyAccount(id = "b", name = "USD", currency = "USD")
        val l =
            Ledger(accounts = listOf(a, b))
                .add(
                    Entry(
                        type = EntryType.TRANSFER,
                        amount = "12.35".toBigDecimal(),
                        currency = "EUR",
                        accountId = "a",
                        destinationId = "b",
                        destinationAmount = "13.12345678".toBigDecimal(),
                    )
                )
        LedgerStore(context, "restart-test").write(l)
        val restored = LedgerStore(context, "restart-test").read()
        assertEquals(l, restored)
        assertEquals("987.90".toBigDecimal(), restored.balance(a))
    }

    @Test
    fun separateUsersHaveSeparateLibraries() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        LedgerStore(context, "alice-test")
            .write(Ledger(accounts = listOf(MoneyAccount(name = "Private account"))))
        LedgerStore(context, "bob-test").write(Ledger())
        assertEquals(1, LedgerStore(context, "alice-test").read().accounts.size)
        assertTrue(LedgerStore(context, "bob-test").read().accounts.isEmpty())
    }

    @Test
    fun futureSchemaRejectedWithoutOverwritingOriginal() {
        assertTrue(runCatching { LedgerStore.decode("{\"schemaVersion\":99}") }.isFailure)
    }
}
