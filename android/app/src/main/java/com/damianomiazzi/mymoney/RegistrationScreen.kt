package com.damianomiazzi.mymoney

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch

@Composable
fun RegistrationScreen(session: CloudSession, ready: () -> Unit) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var name by remember { mutableStateOf("") }
    var register by remember { mutableStateOf(true) }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    var awaitingVerification by remember { mutableStateOf(session.auth?.currentUser != null) }
    val scope = rememberCoroutineScope()
    fun run(action: suspend () -> Unit) {
        scope.launch {
            busy = true
            try {
                action()
            } catch (e: Exception) {
                message =
                    when (e) {
                        is com.google.firebase.auth.FirebaseAuthWeakPasswordException ->
                            "Scegli una password più sicura."
                        is com.google.firebase.auth.FirebaseAuthUserCollisionException ->
                            "Questo indirizzo è già registrato. Accedi o recupera la password."
                        is com.google.firebase.FirebaseNetworkException ->
                            "Connessione non disponibile. Riprova."
                        else ->
                            "Operazione non riuscita. Controlla i dati e la configurazione del servizio."
                    }
            } finally {
                busy = false
            }
        }
    }
    MaterialTheme(
        colorScheme = darkColorScheme(primary = orbPresets[0].dark.primary),
        typography = orbTypography,
    ) {
        Surface(Modifier.fillMaxSize(), color = orbPresets[0].dark.bg) {
            Column(
                Modifier.safeDrawingPadding().verticalScroll(rememberScrollState()).padding(28.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text("MyMoney", style = MaterialTheme.typography.headlineLarge)
                Text(
                    if (awaitingVerification) "Verifica il tuo indirizzo email"
                    else if (register) "Crea il tuo account" else "Bentornato",
                    style = MaterialTheme.typography.titleLarge,
                )
                if (!session.configured)
                    Text("Il servizio di registrazione non è ancora configurato per questa build.")
                else if (awaitingVerification) {
                    Text(
                        "Apri il link ricevuto via email, poi premi Continua. I tuoi dati finanziari rimangono sul dispositivo: la condivisione richiederà una scelta esplicita."
                    )
                    Button(
                        enabled = !busy,
                        onClick = {
                            run {
                                if (session.refresh()) ready()
                                else message = "L'indirizzo non risulta ancora verificato."
                            }
                        },
                    ) {
                        Text("Ho verificato, continua")
                    }
                    TextButton(
                        onClick = {
                            session.signOut()
                            awaitingVerification = false
                        }
                    ) {
                        Text("Usa un altro account")
                    }
                } else {
                    if (register) Input("Nome", name, { name = it })
                    Input("Email", email, { email = it })
                    OutlinedTextField(
                        password,
                        { password = it },
                        label = { Text("Password") },
                        singleLine = true,
                        visualTransformation = PasswordVisualTransformation(),
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Text(
                        "L'account identifica te. I conti e le spese resteranno privati; la condivisione familiare sarà facoltativa."
                    )
                    Button(
                        enabled =
                            !busy &&
                                email.contains('@') &&
                                password.length >= 8 &&
                                (!register || name.isNotBlank()),
                        onClick = {
                            run {
                                if (register) {
                                    session.register(email, password, name)
                                    awaitingVerification = true
                                } else {
                                    session.signIn(email, password)
                                    if (session.refresh()) ready() else awaitingVerification = true
                                }
                            }
                        },
                    ) {
                        Text(if (register) "Registrati" else "Accedi")
                    }
                    TextButton(
                        enabled = !busy,
                        onClick = {
                            register = !register
                            message = null
                        },
                    ) {
                        Text(if (register) "Hai già un account? Accedi" else "Crea un account")
                    }
                    TextButton(
                        enabled = !busy && email.contains('@'),
                        onClick = {
                            run {
                                session.reset(email)
                                message = "Se l'indirizzo è registrato, riceverai le istruzioni."
                            }
                        },
                    ) {
                        Text("Password dimenticata")
                    }
                }
                if (busy) CircularProgressIndicator()
                message?.let { Text(it) }
            }
        }
    }
}
