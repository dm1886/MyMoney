package com.damianomiazzi.mymoney

import java.time.LocalDate
import org.junit.Assert.*
import org.junit.Test

class FinanceTest {
    private val a = MoneyAccount(id = "a", name = "Conto", initial = "1000.25".toBigDecimal())
    private val b = MoneyAccount(id = "b", name = "USD", currency = "USD")

    private fun base() = Ledger(accounts = listOf(a, b))

    private fun spend(status: EntryStatus = EntryStatus.EXECUTED) =
        Entry(
            type = EntryType.EXPENSE,
            amount = "12.35".toBigDecimal(),
            currency = "EUR",
            accountId = "a",
            categoryId = "Alimentari",
            status = status,
        )

    @Test
    fun supermarketBalance() {
        val l = base().add(spend())
        assertEquals("987.90".toBigDecimal(), l.balance(a))
    }

    @Test
    fun pendingDoesNotAffectBalance() {
        assertEquals(a.initial, base().add(spend(EntryStatus.PENDING)).balance(a))
    }

    @Test
    fun deletingRestoresBalance() {
        val l = base().add(spend())
        assertEquals(a.initial, l.copy(entries = emptyList()).balance(a))
    }

    @Test
    fun currenciesNeverSummed() {
        assertEquals(setOf("EUR", "USD"), base().totals().keys)
    }

    @Test
    fun transferUsesSavedDestination() {
        val l =
            base()
                .add(
                    Entry(
                        type = EntryType.TRANSFER,
                        amount = "100".toBigDecimal(),
                        currency = "EUR",
                        accountId = "a",
                        destinationId = "b",
                        destinationAmount = "108.12".toBigDecimal(),
                    )
                )
        assertEquals("900.25".toBigDecimal(), l.balance(a))
        assertEquals("108.12".toBigDecimal(), l.balance(b))
    }

    @Test
    fun incomeIncreasesBalance() {
        val l =
            base()
                .add(
                    Entry(
                        type = EntryType.INCOME,
                        amount = "10".toBigDecimal(),
                        currency = "EUR",
                        accountId = "a",
                    )
                )
        assertEquals("1010.25".toBigDecimal(), l.balance(a))
    }

    @Test
    fun adjustmentCanBeNegative() {
        val l =
            base()
                .add(
                    Entry(
                        type = EntryType.ADJUSTMENT,
                        amount = "-10".toBigDecimal(),
                        currency = "EUR",
                        accountId = "a",
                    )
                )
        assertEquals("990.25".toBigDecimal(), l.balance(a))
    }

    @Test
    fun crossCurrencyExpenseUsesSnapshot() {
        val l =
            base()
                .add(
                    Entry(
                        type = EntryType.EXPENSE,
                        amount = "10".toBigDecimal(),
                        currency = "USD",
                        accountAmount = "9.20".toBigDecimal(),
                        accountId = "a",
                    )
                )
        assertEquals("991.05".toBigDecimal(), l.balance(a))
    }

    @Test
    fun budgetExcludesPendingAndTransfers() {
        val today = LocalDate.now()
        val l = base().add(spend()).add(spend(EntryStatus.PENDING))
        val budget =
            MoneyBudget(
                categoryId = "Alimentari",
                amount = "100".toBigDecimal(),
                currency = "EUR",
                start = today,
                end = today,
            )
        assertEquals("12.35".toBigDecimal(), l.spent(budget))
    }

    @Test
    fun duplicateIdRejected() {
        val e = spend()
        assertTrue(runCatching { base().add(e).add(e) }.isFailure)
    }

    @Test
    fun transferToSelfRejected() {
        assertTrue(
            runCatching {
                    base()
                        .add(
                            Entry(
                                type = EntryType.TRANSFER,
                                amount = "1".toBigDecimal(),
                                currency = "EUR",
                                accountId = "a",
                                destinationId = "a",
                            )
                        )
                }
                .isFailure
        )
    }

    @Test
    fun missingRateRejected() {
        assertTrue(
            runCatching {
                    base()
                        .add(
                            Entry(
                                type = EntryType.EXPENSE,
                                amount = "10".toBigDecimal(),
                                currency = "USD",
                                accountId = "a",
                            )
                        )
                }
                .isFailure
        )
    }

    @Test
    fun decimalInput() {
        assertEquals("12.35".toBigDecimal(), parseMoney("12,35"))
        assertNull(parseMoney("1,234.56"))
        assertNull(parseMoney("NaN"))
    }

    @Test
    fun creditFacilityNotNetWorth() {
        assertEquals("-100".toBigDecimal(), creditNet("900".toBigDecimal(), "1000".toBigDecimal()))
    }

    @Test
    fun monthlyClampsAtMonthEnd() {
        assertEquals(
            LocalDate.of(2026, 2, 28),
            nextOccurrence(LocalDate.of(2026, 1, 31), 1, "month"),
        )
    }

    @Test
    fun inclusiveRecurrence() {
        assertEquals(
            LocalDate.of(2026, 10, 15),
            nextOccurrence(LocalDate.of(2026, 10, 1), 15, "day", true),
        )
    }
}
