package com.damianomiazzi.mymoney

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await
import org.json.JSONObject

/** Firebase authentication only. Financial synchronization requires the migration/consent flow. */
class CloudSession(context: Context) {
    private val config =
        runCatching {
                JSONObject(
                    context.assets.open("firebase-config.json").bufferedReader().use {
                        it.readText()
                    }
                )
            }
            .getOrNull()
    val configured
        get() = config != null

    val emulator = BuildConfig.DEBUG && config?.optBoolean("emulator", false) == true
    private val existingApp = FirebaseApp.getApps(context).find { it.name == "mymoney" }
    private val app: FirebaseApp? =
        config?.let { c ->
            existingApp
                ?: FirebaseApp.initializeApp(
                    context,
                    FirebaseOptions.Builder()
                        .setApplicationId(c.getString("appId"))
                        .setProjectId(c.getString("projectId"))
                        .setApiKey(c.getString("apiKey"))
                        .build(),
                    "mymoney",
                )
        }
    val auth: FirebaseAuth? = app?.let { FirebaseAuth.getInstance(it) }
    private val db: FirebaseFirestore? = app?.let { FirebaseFirestore.getInstance(it) }

    init {
        if (emulator && existingApp == null) {
            auth?.useEmulator("10.0.2.2", 9099)
            db?.useEmulator("10.0.2.2", 8080)
        }
    }

    suspend fun register(email: String, password: String, name: String) {
        val user =
            requireNotNull(auth).createUserWithEmailAndPassword(email.trim(), password).await().user
                ?: error("Registrazione non riuscita")
        user
            .updateProfile(
                com.google.firebase.auth.UserProfileChangeRequest.Builder()
                    .setDisplayName(name.trim())
                    .build()
            )
            .await()
        user.sendEmailVerification().await()
    }

    suspend fun signIn(email: String, password: String) {
        requireNotNull(auth).signInWithEmailAndPassword(email.trim(), password).await()
    }

    suspend fun refresh(): Boolean {
        val user = auth?.currentUser ?: return false
        user.reload().await()
        user.getIdToken(true).await()
        if (!user.isEmailVerified) return false
        // Merge avoids replacing the original creation timestamp on subsequent sign-ins.
        val profile = requireNotNull(db).collection("users").document(user.uid)
        if (!profile.get().await().exists())
            profile
                .set(
                    mapOf(
                        "displayName" to (user.displayName ?: ""),
                        "createdAt" to FieldValue.serverTimestamp(),
                        "updatedAt" to FieldValue.serverTimestamp(),
                    )
                )
                .await()
        return true
    }

    suspend fun reset(email: String) {
        requireNotNull(auth).sendPasswordResetEmail(email.trim()).await()
    }

    fun signOut() {
        auth?.signOut()
    }
}
