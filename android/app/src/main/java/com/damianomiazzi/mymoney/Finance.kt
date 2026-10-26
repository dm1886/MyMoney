package com.damianomiazzi.mymoney

import java.math.BigDecimal
import java.time.LocalDate
import java.util.UUID

// Amounts are decimal strings at rest/on the wire, never binary floating point.
enum class AccountType(val label: String) {
    PAYMENT("Pagamento"),
    CASH("Contanti"),
    PREPAID("Carta Prepagata"),
    CREDIT("Carta di Credito"),
    ASSET("Attività"),
    LIABILITY("Passività"),
}

enum class EntryType(val label: String) {
    EXPENSE("Uscita"),
    INCOME("Entrata"),
    TRANSFER("Trasferimento"),
    LIABILITY_PAYMENT("Pagamento Passività"),
    ADJUSTMENT("Aggiustamento"),
}

enum class EntryStatus {
    EXECUTED,
    PENDING,
    CANCELLED,
    FAILED,
}

data class MoneyAccount(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val type: AccountType = AccountType.PAYMENT,
    val currency: String = "EUR",
    val initial: BigDecimal = BigDecimal.ZERO,
    val creditLimit: BigDecimal? = null,
)

data class MoneyCategory(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val income: Boolean = false,
)

data class Entry(
    val id: String = UUID.randomUUID().toString(),
    val type: EntryType,
    val amount: BigDecimal,
    val currency: String,
    val date: LocalDate = LocalDate.now(),
    val accountId: String,
    val categoryId: String? = null,
    val destinationId: String? = null,
    val destinationAmount: BigDecimal? = null,
    val accountAmount: BigDecimal? = null,
    val interest: BigDecimal = BigDecimal.ZERO,
    val note: String = "",
    val status: EntryStatus = EntryStatus.EXECUTED,
)

data class MoneyBudget(
    val id: String = UUID.randomUUID().toString(),
    val categoryId: String,
    val amount: BigDecimal,
    val currency: String,
    val start: LocalDate,
    val end: LocalDate,
)

data class Ledger(
    val accounts: List<MoneyAccount> = emptyList(),
    val categories: List<MoneyCategory> = defaultCategories(),
    val entries: List<Entry> = emptyList(),
    val budgets: List<MoneyBudget> = emptyList(),
) {
    fun balance(account: MoneyAccount): BigDecimal =
        entries
            .filter { it.status == EntryStatus.EXECUTED }
            .fold(account.initial) { value, entry ->
                var result = value
                if (entry.accountId == account.id) {
                    val amount = entry.accountAmount ?: entry.amount
                    result +=
                        when (entry.type) {
                            EntryType.INCOME,
                            EntryType.ADJUSTMENT -> amount
                            EntryType.LIABILITY_PAYMENT -> -(amount + entry.interest)
                            else -> -amount
                        }
                }
                if (entry.destinationId == account.id)
                    result += entry.destinationAmount ?: entry.amount
                result
            }

    fun totals(): Map<String, BigDecimal> =
        accounts
            .groupBy { it.currency }
            .mapValues { (_, list) -> list.fold(BigDecimal.ZERO) { sum, a -> sum + balance(a) } }

    fun add(entry: Entry): Ledger {
        require(entries.none { it.id == entry.id }) { "Movimento già presente" }
        val account =
            accounts.singleOrNull { it.id == entry.accountId } ?: error("Seleziona un conto")
        require(entry.type == EntryType.ADJUSTMENT || entry.amount > BigDecimal.ZERO) {
            "Importo non valido"
        }
        require(entry.categoryId == null || categories.any { it.id == entry.categoryId }) {
            "Categoria non valida"
        }
        if (entry.currency != account.currency)
            require(entry.accountAmount != null && entry.accountAmount > BigDecimal.ZERO) {
                "Indica l'importo nella valuta del conto"
            }
        if (entry.type == EntryType.TRANSFER || entry.type == EntryType.LIABILITY_PAYMENT) {
            val dest =
                accounts.singleOrNull { it.id == entry.destinationId }
                    ?: error("Seleziona il conto di destinazione")
            require(dest.id != account.id) { "Scegli due conti diversi" }
            if (dest.currency != entry.currency)
                require(
                    entry.destinationAmount != null && entry.destinationAmount > BigDecimal.ZERO
                ) {
                    "Indica l'importo ricevuto"
                }
        } else require(entry.destinationId == null)
        require(entry.interest >= BigDecimal.ZERO)
        return copy(entries = entries + entry)
    }

    fun spent(budget: MoneyBudget): BigDecimal =
        entries
            .filter {
                it.type == EntryType.EXPENSE &&
                    it.status == EntryStatus.EXECUTED &&
                    it.categoryId == budget.categoryId &&
                    !it.date.isBefore(budget.start) &&
                    !it.date.isAfter(budget.end)
            }
            .fold(BigDecimal.ZERO) { sum, e ->
                // Do not silently mix currencies. Explicit historical conversion needed for other
                // currencies.
                sum +
                    when {
                        e.currency == budget.currency -> e.amount
                        accounts.find { it.id == e.accountId }?.currency == budget.currency ->
                            e.accountAmount ?: BigDecimal.ZERO
                        else -> BigDecimal.ZERO
                    }
            }
}

fun defaultCategories() =
    listOf(
            "Alimentari",
            "Ristoranti",
            "Trasporti",
            "Casa",
            "Salute",
            "Shopping",
            "Tempo libero",
            "Altro",
        )
        .map { MoneyCategory(id = it, name = it) } +
        MoneyCategory(id = "Stipendio", name = "Stipendio", income = true)

fun parseMoney(value: String): BigDecimal? {
    val input = value.trim().replace(" ", "")
    if (!Regex("[+-]?\\d+([.,]\\d{1,8})?").matches(input)) return null
    return input.replace(',', '.').toBigDecimalOrNull()
}

fun displayMoney(value: BigDecimal, currency: String): String =
    java.text.NumberFormat.getCurrencyInstance(java.util.Locale.ITALY)
        .apply { this.currency = java.util.Currency.getInstance(currency) }
        .format(value)

fun creditNet(available: BigDecimal, limit: BigDecimal) = available - limit

fun nextOccurrence(
    date: LocalDate,
    interval: Int,
    unit: String,
    includeStart: Boolean = false,
): LocalDate {
    val step = (interval.coerceIn(1, 365) - if (includeStart) 1 else 0).coerceAtLeast(1).toLong()
    return when (unit) {
        "day" -> date.plusDays(step)
        "month" -> date.plusMonths(step)
        "year" -> date.plusYears(step)
        else -> error("Unità non valida")
    }
}
