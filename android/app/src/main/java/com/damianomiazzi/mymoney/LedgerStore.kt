package com.damianomiazzi.mymoney

import android.content.Context
import android.util.AtomicFile
import java.io.File
import java.time.LocalDate
import org.json.JSONArray
import org.json.JSONObject

// Atomic private-file persistence: a failed write must never leave half a ledger.
class LedgerStore(context: Context, userId: String = "local") {
    private val file =
        AtomicFile(
            File(context.filesDir, "ledger-${userId.replace(Regex("[^a-zA-Z0-9_-]"), "_")}-v1.json")
        )

    fun read(): Ledger =
        if (!file.baseFile.exists()) Ledger()
        else decode(file.openRead().bufferedReader().use { it.readText() })

    fun write(ledger: Ledger) {
        val stream = file.startWrite()
        try {
            stream.write(encode(ledger).toByteArray())
            file.finishWrite(stream)
        } catch (error: Exception) {
            file.failWrite(stream)
            throw error
        }
    }

    companion object {
        private fun JSONArray.objects() = (0 until length()).map { getJSONObject(it) }

        private fun JSONObject.optional(key: String) =
            if (isNull(key) || !has(key)) null else getString(key)

        fun encode(l: Ledger): String =
            JSONObject()
                .apply {
                    put("schemaVersion", 1)
                    put(
                        "accounts",
                        JSONArray(
                            l.accounts.map { a ->
                                JSONObject().apply {
                                    put("id", a.id)
                                    put("name", a.name)
                                    put("type", a.type.name)
                                    put("currency", a.currency)
                                    put("initial", a.initial.toPlainString())
                                    put("creditLimit", a.creditLimit?.toPlainString())
                                }
                            }
                        ),
                    )
                    put(
                        "categories",
                        JSONArray(
                            l.categories.map { c ->
                                JSONObject().apply {
                                    put("id", c.id)
                                    put("name", c.name)
                                    put("income", c.income)
                                }
                            }
                        ),
                    )
                    put(
                        "entries",
                        JSONArray(
                            l.entries.map { e ->
                                JSONObject().apply {
                                    put("id", e.id)
                                    put("type", e.type.name)
                                    put("amount", e.amount.toPlainString())
                                    put("currency", e.currency)
                                    put("date", e.date.toString())
                                    put("accountId", e.accountId)
                                    put("categoryId", e.categoryId)
                                    put("destinationId", e.destinationId)
                                    put("destinationAmount", e.destinationAmount?.toPlainString())
                                    put("accountAmount", e.accountAmount?.toPlainString())
                                    put("interest", e.interest.toPlainString())
                                    put("note", e.note)
                                    put("status", e.status.name)
                                }
                            }
                        ),
                    )
                    put(
                        "budgets",
                        JSONArray(
                            l.budgets.map { b ->
                                JSONObject().apply {
                                    put("id", b.id)
                                    put("categoryId", b.categoryId)
                                    put("amount", b.amount.toPlainString())
                                    put("currency", b.currency)
                                    put("start", b.start.toString())
                                    put("end", b.end.toString())
                                }
                            }
                        ),
                    )
                }
                .toString(2)

        fun decode(text: String): Ledger {
            val j = JSONObject(text)
            require(j.getInt("schemaVersion") == 1) { "Versione backup non supportata" }
            return Ledger(
                    j.getJSONArray("accounts").objects().map {
                        MoneyAccount(
                            it.getString("id"),
                            it.getString("name"),
                            AccountType.valueOf(it.getString("type")),
                            it.getString("currency"),
                            it.getString("initial").toBigDecimal(),
                            it.optional("creditLimit")?.toBigDecimal(),
                        )
                    },
                    j.getJSONArray("categories").objects().map {
                        MoneyCategory(
                            it.getString("id"),
                            it.getString("name"),
                            it.getBoolean("income"),
                        )
                    },
                    j.getJSONArray("entries").objects().map {
                        Entry(
                            id = it.getString("id"),
                            type = EntryType.valueOf(it.getString("type")),
                            amount = it.getString("amount").toBigDecimal(),
                            currency = it.getString("currency"),
                            date = LocalDate.parse(it.getString("date")),
                            accountId = it.getString("accountId"),
                            categoryId = it.optional("categoryId"),
                            destinationId = it.optional("destinationId"),
                            destinationAmount = it.optional("destinationAmount")?.toBigDecimal(),
                            accountAmount = it.optional("accountAmount")?.toBigDecimal(),
                            interest = it.getString("interest").toBigDecimal(),
                            note = it.getString("note"),
                            status = EntryStatus.valueOf(it.getString("status")),
                        )
                    },
                    j.getJSONArray("budgets").objects().map {
                        MoneyBudget(
                            it.getString("id"),
                            it.getString("categoryId"),
                            it.getString("amount").toBigDecimal(),
                            it.getString("currency"),
                            LocalDate.parse(it.getString("start")),
                            LocalDate.parse(it.getString("end")),
                        )
                    },
                )
                .also { l ->
                    require(l.accounts.map { it.id }.distinct().size == l.accounts.size)
                    require(l.entries.map { it.id }.distinct().size == l.entries.size)
                    require(l.entries.all { e -> l.accounts.any { it.id == e.accountId } })
                }
        }
    }
}
