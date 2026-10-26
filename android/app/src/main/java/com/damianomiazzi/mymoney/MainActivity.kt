package com.damianomiazzi.mymoney

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val session = CloudSession(this)
        setContent {
            var signedIn by remember {
                mutableStateOf(session.auth?.currentUser?.isEmailVerified == true)
            }
            if (signedIn)
                MyMoneyApp(
                    userId = requireNotNull(session.auth?.currentUser?.uid),
                    cloudSession = session,
                    signOut = {
                        session.signOut()
                        signedIn = false
                    },
                )
            else RegistrationScreen(session) { signedIn = true }
        }
    }
}

@Composable
fun MyMoneyApp(
    userId: String = "local",
    signOut: () -> Unit = {},
    cloudSession: CloudSession? = null,
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val store = remember(userId) { LedgerStore(context, userId) }
    val prefs = remember { context.getSharedPreferences("presentation", 0) }
    var error by remember { mutableStateOf<String?>(null) }
    var ledger by
        remember(userId) {
            mutableStateOf(
                try {
                    store.read()
                } catch (e: Exception) {
                    error = "Archivio non leggibile. I dati originali sono stati conservati."
                    null
                }
            )
        }
    var preset by remember { mutableIntStateOf(prefs.getInt("theme", 0).coerceIn(0, 4)) }
    var dark by remember { mutableStateOf(prefs.getBoolean("dark", true)) }
    val p = if (dark) orbPresets[preset].dark else orbPresets[preset].light
    var tab by remember { mutableIntStateOf(0) }
    var form by remember { mutableStateOf<String?>(null) }
    var editing by remember { mutableStateOf<Entry?>(null) }
    fun save(next: Ledger): Boolean {
        return try {
            store.write(next)
            ledger = next
            true
        } catch (e: Exception) {
            error = "Salvataggio non riuscito. Riprova."
            false
        }
    }
    MaterialTheme(
        colorScheme =
            if (dark)
                darkColorScheme(
                    primary = p.primary,
                    secondary = p.secondary,
                    background = p.bg,
                    surface = p.card,
                    onSurface = p.text,
                    onBackground = p.text,
                    onPrimary = p.on,
                )
            else
                lightColorScheme(
                    primary = p.primary,
                    secondary = p.secondary,
                    background = p.bg,
                    surface = p.card,
                    onSurface = p.text,
                    onBackground = p.text,
                    onPrimary = p.on,
                ),
        typography = orbTypography,
    ) {
        Surface(color = p.bg, modifier = Modifier.fillMaxSize()) {
            if (ledger == null) {
                Column(Modifier.safeDrawingPadding().padding(24.dp)) {
                    Text("Archivio non disponibile")
                    Text("Non verranno sovrascritti i dati esistenti.")
                }
            } else {
                val l = ledger!!
                Scaffold(
                    containerColor = p.bg,
                    bottomBar = {
                        OrbNavigationBar(tab, p, { tab = it }) {
                            form = if (l.accounts.isEmpty()) "account" else "entry"
                        }
                    },
                ) { inset ->
                    Box(
                        Modifier.fillMaxSize().padding(inset),
                        contentAlignment = Alignment.TopCenter,
                    ) {
                        LazyColumn(
                            Modifier.widthIn(max = 720.dp).fillMaxWidth().fillMaxHeight(),
                            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
                            verticalArrangement = Arrangement.spacedBy(16.dp),
                        ) {
                            item {
                                Text(
                                    if (tab == 0)
                                        LocalDate.now()
                                            .format(
                                                DateTimeFormatter.ofPattern(
                                                    "EEEE d MMMM",
                                                    Locale.ITALIAN,
                                                )
                                            )
                                    else "MyMoney",
                                    color = p.muted,
                                    fontSize = 11.sp,
                                )
                                Text(
                                    listOf("Ciao", "Bilancio", "Oggi", "Resoconto", "Impostazioni")[
                                        tab],
                                    style = MaterialTheme.typography.headlineLarge,
                                    fontWeight = FontWeight.Bold,
                                )
                            }
                            when (tab) {
                                0 -> {
                                    item {
                                        OrbCard(p) {
                                            Box(
                                                Modifier.fillMaxWidth().height(210.dp),
                                                contentAlignment = Alignment.Center,
                                            ) {
                                                OrbGraphic(p, Modifier.size(190.dp))
                                            }
                                            Text("Saldo totale", color = p.muted)
                                            if (l.accounts.isEmpty())
                                                Text(
                                                    "Aggiungi il tuo primo conto",
                                                    style = MaterialTheme.typography.titleLarge,
                                                )
                                            else
                                                l.totals().forEach { (currency, amount) ->
                                                    Text(
                                                        displayMoney(amount, currency),
                                                        style =
                                                            MaterialTheme.typography.headlineLarge,
                                                    )
                                                }
                                        }
                                    }
                                    item {
                                        Text(
                                            "I tuoi conti",
                                            style = MaterialTheme.typography.titleLarge,
                                        )
                                    }
                                    items(l.accounts, key = { it.id }) { a ->
                                        AccountCard(a, l, p) { form = "account:${a.id}" }
                                    }
                                    item {
                                        OutlinedButton(onClick = { form = "account" }) {
                                            Text("Aggiungi conto")
                                        }
                                    }
                                    item {
                                        Text(
                                            "Ultimi movimenti",
                                            style = MaterialTheme.typography.titleLarge,
                                        )
                                    }
                                    items(
                                        l.entries.sortedByDescending { it.date }.take(5),
                                        key = { it.id },
                                    ) { e ->
                                        EntryCard(e, l, p) {
                                            editing = e
                                            form = "entry"
                                        }
                                    }
                                }
                                1 -> {
                                    items(l.accounts, key = { it.id }) { a ->
                                        AccountCard(a, l, p) { form = "account:${a.id}" }
                                    }
                                    item {
                                        Button(onClick = { form = "account" }) {
                                            Text("Aggiungi conto")
                                        }
                                        Spacer(Modifier.height(16.dp))
                                        Text("Budget", style = MaterialTheme.typography.titleLarge)
                                    }
                                    items(l.budgets, key = { it.id }) { b ->
                                        OrbCard(p) {
                                            Text(
                                                l.categories.find { it.id == b.categoryId }?.name
                                                    ?: "Categoria"
                                            )
                                            Text(
                                                "${displayMoney(l.spent(b),b.currency)} / ${displayMoney(b.amount,b.currency)}"
                                            )
                                            LinearProgressIndicator(
                                                progress = {
                                                    if (b.amount.signum() > 0)
                                                        (l.spent(b).toFloat() / b.amount.toFloat())
                                                            .coerceIn(0f, 1f)
                                                    else 0f
                                                },
                                                modifier = Modifier.fillMaxWidth(),
                                            )
                                            Text("${b.start} – ${b.end}", color = p.muted)
                                            TextButton(
                                                onClick = {
                                                    save(
                                                        l.copy(
                                                            budgets =
                                                                l.budgets.filterNot {
                                                                    it.id == b.id
                                                                }
                                                        )
                                                    )
                                                }
                                            ) {
                                                Text("Elimina budget")
                                            }
                                        }
                                    }
                                    item {
                                        OutlinedButton(onClick = { form = "budget" }) {
                                            Text("Aggiungi budget")
                                        }
                                    }
                                }
                                2 -> {
                                    item {
                                        Text(
                                            "Movimenti",
                                            style = MaterialTheme.typography.titleLarge,
                                        )
                                        Text(
                                            "Tutte le date • seleziona un movimento per modificarlo",
                                            color = p.muted,
                                        )
                                    }
                                    if (l.entries.isEmpty())
                                        item { Text("Non ci sono ancora movimenti") }
                                    items(
                                        l.entries.sortedByDescending { it.date },
                                        key = { it.id },
                                    ) { e ->
                                        EntryCard(e, l, p) {
                                            editing = e
                                            form = "entry"
                                        }
                                    }
                                }
                                3 -> {
                                    item {
                                        Text(
                                            "Entrate e uscite del mese",
                                            style = MaterialTheme.typography.titleLarge,
                                        )
                                    }
                                    val month =
                                        l.entries.filter {
                                            it.status == EntryStatus.EXECUTED &&
                                                it.date.withDayOfMonth(1) ==
                                                    LocalDate.now().withDayOfMonth(1)
                                        }
                                    items(month.map { it.currency }.distinct()) { currency ->
                                        OrbCard(p) {
                                            Text(currency, color = p.muted)
                                            val income =
                                                month
                                                    .filter {
                                                        it.currency == currency &&
                                                            it.type == EntryType.INCOME
                                                    }
                                                    .sumOf { it.amount }
                                            val expense =
                                                month
                                                    .filter {
                                                        it.currency == currency &&
                                                            it.type == EntryType.EXPENSE
                                                    }
                                                    .sumOf { it.amount }
                                            Text(
                                                "Entrate  ${displayMoney(income,currency)}",
                                                color = p.positive,
                                            )
                                            Text(
                                                "Uscite  ${displayMoney(expense,currency)}",
                                                color = p.negative,
                                            )
                                            l.categories
                                                .filterNot { it.income }
                                                .forEach { c ->
                                                    val amount =
                                                        month
                                                            .filter {
                                                                it.currency == currency &&
                                                                    it.type == EntryType.EXPENSE &&
                                                                    it.categoryId == c.id
                                                            }
                                                            .sumOf { it.amount }
                                                    if (amount.signum() > 0) {
                                                        Text(
                                                            "${c.name}  ${displayMoney(amount,currency)}"
                                                        )
                                                        LinearProgressIndicator(
                                                            progress = {
                                                                if (expense.signum() > 0)
                                                                    (amount.toFloat() /
                                                                            expense.toFloat())
                                                                        .coerceIn(0f, 1f)
                                                                else 0f
                                                            },
                                                            modifier = Modifier.fillMaxWidth(),
                                                        )
                                                    }
                                                }
                                        }
                                    }
                                }
                                4 -> {
                                    item {
                                        OrbCard(p) {
                                            Text(
                                                "Aspetto",
                                                style = MaterialTheme.typography.titleLarge,
                                            )
                                            Row(verticalAlignment = Alignment.CenterVertically) {
                                                Text("Modalità scura", Modifier.weight(1f))
                                                Switch(
                                                    checked = dark,
                                                    onCheckedChange = {
                                                        dark = it
                                                        prefs.edit().putBoolean("dark", it).apply()
                                                    },
                                                )
                                            }
                                            orbPresets.forEachIndexed { i, t ->
                                                TextButton(
                                                    onClick = {
                                                        preset = i
                                                        prefs.edit().putInt("theme", i).apply()
                                                    }
                                                ) {
                                                    Text((if (i == preset) "✓ " else "") + t.name)
                                                }
                                            }
                                        }
                                    }
                                    item {
                                        OrbCard(p) {
                                            Text(
                                                "Categorie",
                                                style = MaterialTheme.typography.titleLarge,
                                            )
                                            l.categories.forEach { Text(it.name, color = p.muted) }
                                            TextButton(onClick = { form = "category" }) {
                                                Text("Aggiungi categoria")
                                            }
                                        }
                                    }
                                    item {
                                        if (cloudSession != null)
                                            CloudAccountSettings(cloudSession, p, signOut)
                                    }
                                }
                            }
                        }
                    }
                }
                if (form != null) {
                    val dismiss = {
                        form = null
                        editing = null
                    }
                    when {
                        form == "entry" ->
                            EntryForm(
                                l,
                                editing,
                                dismiss,
                                { e ->
                                    try {
                                        val base =
                                            l.copy(entries = l.entries.filterNot { it.id == e.id })
                                        if (save(base.add(e))) dismiss()
                                    } catch (ex: Exception) {
                                        error = ex.message
                                    }
                                },
                                { id ->
                                    save(l.copy(entries = l.entries.filterNot { it.id == id }))
                                    dismiss()
                                },
                            )
                        form!!.startsWith("account") ->
                            AccountForm(l, form!!.substringAfter(':', ""), dismiss) { a ->
                                if (
                                    save(
                                        l.copy(
                                            accounts = l.accounts.filterNot { it.id == a.id } + a
                                        )
                                    )
                                )
                                    dismiss()
                            }
                        form == "budget" ->
                            BudgetForm(l, dismiss) { b ->
                                if (save(l.copy(budgets = l.budgets + b))) dismiss()
                            }
                        form == "category" ->
                            CategoryForm(dismiss) { c ->
                                if (save(l.copy(categories = l.categories + c))) dismiss()
                            }
                    }
                }
            }
            error?.let { message ->
                AlertDialog(
                    onDismissRequest = { error = null },
                    title = { Text("Attenzione") },
                    text = { Text(message) },
                    confirmButton = { TextButton(onClick = { error = null }) { Text("OK") } },
                )
            }
        }
    }
}

@Composable
fun OrbCard(p: OrbPalette, content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxWidth().background(p.card, RoundedCornerShape(20.dp)).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        content = content,
    )
}

@Composable
fun AccountCard(a: MoneyAccount, l: Ledger, p: OrbPalette, click: () -> Unit) {
    Box(Modifier.clickable(onClick = click)) {
        OrbCard(p) {
            Row {
                Text(a.name, Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
                Text(a.type.label, color = p.muted, fontSize = 12.sp)
            }
            Text(
                displayMoney(l.balance(a), a.currency),
                style = MaterialTheme.typography.titleLarge,
            )
        }
    }
}

@Composable
fun EntryCard(e: Entry, l: Ledger, p: OrbPalette, click: () -> Unit) {
    Box(Modifier.clickable(onClick = click)) {
        OrbCard(p) {
            Row {
                Column(Modifier.weight(1f)) {
                    Text(
                        e.note.ifBlank {
                            l.categories.find { it.id == e.categoryId }?.name ?: e.type.label
                        }
                    )
                    Text(
                        "${e.date} · ${l.accounts.find {it.id==e.accountId}?.name.orEmpty()}",
                        fontSize = 11.sp,
                        color = p.muted,
                    )
                }
                Text(
                    displayMoney(e.amount, e.currency),
                    color = if (e.type == EntryType.INCOME) p.positive else p.negative,
                )
            }
            if (e.status != EntryStatus.EXECUTED) Text("Da confermare", color = p.muted)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FormSheet(title: String, dismiss: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(onDismissRequest = dismiss, sheetState = sheetState) {
        Column(
            Modifier.fillMaxWidth()
                .fillMaxHeight(.95f)
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(title, style = MaterialTheme.typography.titleLarge)
            content()
            Spacer(Modifier.height(28.dp))
        }
    }
}

@Composable
fun Input(label: String, value: String, onChange: (String) -> Unit, numeric: Boolean = false) {
    OutlinedTextField(
        value,
        onChange,
        label = { Text(label) },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
        keyboardOptions =
            KeyboardOptions(keyboardType = if (numeric) KeyboardType.Decimal else KeyboardType.Text),
    )
}

@Composable
fun <T> Choice(
    label: String,
    selected: T?,
    values: List<T>,
    name: (T) -> String,
    choose: (T) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        OutlinedButton(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth()) {
            Text("$label: ${selected?.let(name) ?: "Seleziona"}")
        }
        DropdownMenu(expanded, onDismissRequest = { expanded = false }) {
            values.forEach { v ->
                DropdownMenuItem(
                    text = { Text(name(v)) },
                    onClick = {
                        choose(v)
                        expanded = false
                    },
                )
            }
        }
    }
}

@Composable
fun AccountForm(l: Ledger, id: String, dismiss: () -> Unit, save: (MoneyAccount) -> Unit) {
    val old = l.accounts.find { it.id == id }
    var name by remember { mutableStateOf(old?.name.orEmpty()) }
    var amount by remember { mutableStateOf(old?.initial?.toPlainString() ?: "0") }
    var currency by remember { mutableStateOf(old?.currency ?: "EUR") }
    var type by remember { mutableStateOf(old?.type ?: AccountType.PAYMENT) }
    FormSheet(if (old == null) "Nuovo conto" else "Modifica conto", dismiss) {
        Input("Nome", name, { name = it })
        Input("Saldo iniziale", amount, { amount = it }, true)
        Choice("Tipo", type, AccountType.entries, { it.label }, { type = it })
        Choice(
            "Valuta",
            currency,
            listOf("EUR", "USD", "GBP", "CHF", "HKD", "MOP", "AED", "AUD", "CAD", "JPY"),
            { it },
            { currency = it },
        )
        Button(
            onClick = {
                save(
                    MoneyAccount(
                        id = old?.id ?: java.util.UUID.randomUUID().toString(),
                        name = name.trim(),
                        initial = parseMoney(amount)!!,
                        currency = currency,
                        type = type,
                    )
                )
            },
            enabled =
                name.isNotBlank() &&
                    parseMoney(amount) != null &&
                    (old == null ||
                        currency == old.currency ||
                        l.entries.none { it.accountId == id || it.destinationId == id }),
        ) {
            Text("Salva conto")
        }
    }
}

@Composable
fun EntryForm(
    l: Ledger,
    old: Entry?,
    dismiss: () -> Unit,
    save: (Entry) -> Unit,
    delete: (String) -> Unit,
) {
    var amount by remember { mutableStateOf(old?.amount?.toPlainString().orEmpty()) }
    var note by remember { mutableStateOf(old?.note.orEmpty()) }
    var date by remember { mutableStateOf((old?.date ?: LocalDate.now()).toString()) }
    var type by remember { mutableStateOf(old?.type ?: EntryType.EXPENSE) }
    var account by remember {
        mutableStateOf(l.accounts.find { it.id == old?.accountId } ?: l.accounts.firstOrNull())
    }
    var destination by remember { mutableStateOf(l.accounts.find { it.id == old?.destinationId }) }
    var received by remember { mutableStateOf(old?.destinationAmount?.toPlainString().orEmpty()) }
    var category by remember { mutableStateOf(l.categories.find { it.id == old?.categoryId }) }
    var pending by remember { mutableStateOf(old?.status == EntryStatus.PENDING) }
    FormSheet(if (old == null) "Nuova transazione" else "Modifica transazione", dismiss) {
        Choice(
            "Tipo",
            type,
            EntryType.entries,
            { it.label },
            {
                type = it
                category = null
            },
        )
        Input("Importo", amount, { amount = it }, true)
        Choice("Conto", account, l.accounts, { it.name }, { account = it })
        Input("Data (AAAA-MM-GG)", date, { date = it })
        Input("Note", note, { note = it })
        if (type == EntryType.EXPENSE || type == EntryType.INCOME)
            Choice(
                "Categoria",
                category,
                l.categories.filter { it.income == (type == EntryType.INCOME) },
                { it.name },
                { category = it },
            )
        if (type == EntryType.TRANSFER || type == EntryType.LIABILITY_PAYMENT) {
            Choice(
                "Destinazione",
                destination,
                l.accounts.filter { it.id != account?.id },
                { it.name },
                { destination = it },
            )
            if (destination?.currency != account?.currency)
                Input("Importo ricevuto", received, { received = it }, true)
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Da confermare", Modifier.weight(1f))
            Switch(pending, { pending = it })
        }
        Button(
            onClick = {
                save(
                    Entry(
                        id = old?.id ?: java.util.UUID.randomUUID().toString(),
                        type = type,
                        amount = parseMoney(amount)!!,
                        currency = account!!.currency,
                        date = LocalDate.parse(date),
                        accountId = account!!.id,
                        categoryId = category?.id,
                        destinationId =
                            if (type == EntryType.TRANSFER || type == EntryType.LIABILITY_PAYMENT)
                                destination?.id
                            else null,
                        destinationAmount = parseMoney(received),
                        note = note,
                        status = if (pending) EntryStatus.PENDING else EntryStatus.EXECUTED,
                    )
                )
            },
            enabled =
                account != null &&
                    parseMoney(amount) != null &&
                    runCatching { LocalDate.parse(date) }.isSuccess,
        ) {
            Text("Salva transazione")
        }
        if (old != null) TextButton(onClick = { delete(old.id) }) { Text("Elimina transazione") }
    }
}

@Composable
fun BudgetForm(l: Ledger, dismiss: () -> Unit, save: (MoneyBudget) -> Unit) {
    var amount by remember { mutableStateOf("") }
    var category by remember { mutableStateOf(l.categories.firstOrNull { !it.income }) }
    var currency by remember { mutableStateOf("EUR") }
    FormSheet("Budget mensile", dismiss) {
        Choice(
            "Categoria",
            category,
            l.categories.filterNot { it.income },
            { it.name },
            { category = it },
        )
        Input("Limite", amount, { amount = it }, true)
        Choice(
            "Valuta",
            currency,
            l.accounts.map { it.currency }.distinct().ifEmpty { listOf("EUR") },
            { it },
            { currency = it },
        )
        Button(
            onClick = {
                val now = LocalDate.now()
                save(
                    MoneyBudget(
                        categoryId = category!!.id,
                        amount = parseMoney(amount)!!,
                        currency = currency,
                        start = now.withDayOfMonth(1),
                        end = now.withDayOfMonth(now.lengthOfMonth()),
                    )
                )
            },
            enabled = category != null && (parseMoney(amount)?.signum() ?: 0) > 0,
        ) {
            Text("Salva budget")
        }
    }
}

@Composable
fun CategoryForm(dismiss: () -> Unit, save: (MoneyCategory) -> Unit) {
    var name by remember { mutableStateOf("") }
    var income by remember { mutableStateOf(false) }
    FormSheet("Nuova categoria", dismiss) {
        Input("Nome", name, { name = it })
        Row {
            Text("Entrata", Modifier.weight(1f))
            Switch(income, { income = it })
        }
        Button(
            onClick = { save(MoneyCategory(name = name.trim(), income = income)) },
            enabled = name.isNotBlank(),
        ) {
            Text("Salva categoria")
        }
    }
}
