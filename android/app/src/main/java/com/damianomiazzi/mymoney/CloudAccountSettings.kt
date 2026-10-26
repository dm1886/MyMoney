package com.damianomiazzi.mymoney

import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

@Composable
fun CloudAccountSettings(session: CloudSession, p: OrbPalette, signOut: () -> Unit) {
    var user by remember { mutableStateOf(session.auth?.currentUser) }
    var verified by remember { mutableStateOf(user?.isEmailVerified == true) }
    var busy by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    fun run(action: suspend () -> Unit) {
        scope.launch {
            busy = true
            try {
                action()
            } catch (e: Exception) {
                message = "Operazione non riuscita. Controlla la connessione e riprova."
            } finally {
                busy = false
            }
        }
    }
    OrbCard(p) {
        Text("Account MyMoney", style = MaterialTheme.typography.titleLarge)
        Text(if (user != null) "Registrato" else "Non registrato")
        user?.displayName?.takeIf { it.isNotBlank() }?.let { Text(it) }
        user?.email?.let { Text(it) }
        Text(
            if (verified) "Email verificata" else "Email da verificare",
            color = if (verified) p.positive else p.highlight,
        )
        if (!verified)
            TextButton(
                enabled = !busy,
                onClick = {
                    run {
                        session.auth?.currentUser?.sendEmailVerification()?.await()
                        message = "Email di verifica inviata."
                    }
                },
            ) {
                Text("Invia email di verifica")
            }
        TextButton(
            enabled = !busy,
            onClick = {
                run {
                    verified = session.refresh()
                    user = session.auth?.currentUser
                    message =
                        if (verified) "Email verificata."
                        else "L'email non risulta ancora verificata."
                }
            },
        ) {
            Text("Aggiorna stato")
        }
        TextButton(enabled = !busy, onClick = signOut) { Text("Esci dall’account") }
        Text("Condivisione spese: non attiva", color = p.muted)
        Text(
            "La registrazione non attiva il caricamento o la condivisione delle spese.",
            color = p.muted,
        )
        if (busy) CircularProgressIndicator()
        message?.let { Text(it) }
    }
}
