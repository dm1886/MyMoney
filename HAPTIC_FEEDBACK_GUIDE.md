# Guida Feedback Aptici - MyMoney

## ⚠️ IMPORTANTE - Prima di testare

### Gli haptic feedback NON funzionano nel simulatore!
Devi testare su un **iPhone fisico** per sentire le vibrazioni.

### Verifica impostazioni iPhone:
1. Vai in **Impostazioni > Suoni e feedback aptico**
2. Assicurati che **"Feedback aptico sistema"** sia **ATTIVO**
3. Riavvia l'iPhone se necessario

---

## 📁 File da aggiungere a Xcode

Assicurati di aver aggiunto questi file al progetto:

1. **HapticManager.swift** → cartella `Utilities`
2. **HapticTestView.swift** → cartella `Views`

### Come aggiungere i file:
1. Apri Xcode
2. Click destro sulla cartella appropriata
3. "Add Files to 'MyMoney'"
4. Seleziona i file
5. **DESELEZIONA** "Copy items if needed"
6. Premi "Add"

---

## 🧪 Come testare

1. Compila e lancia l'app su un **iPhone fisico**
2. Vai in **More (⋯) > Test Haptic Feedback**
3. Prova tutti i pulsanti per sentire i diversi tipi di feedback:
   - **Light/Medium/Heavy** - Intensità diverse
   - **Soft/Rigid** - Caratteristiche diverse
   - **Success/Warning/Error** - Notifiche
   - **Selection** - Per cambio selezione

---

## 📍 Dove sono implementati gli haptic

### ✅ Navigazione
- **Cambio tab** (Home, Bilancio, Oggi, Resoconto, More)
  - Tipo: `Selection`
  - Quando: Ogni volta che cambi tab nella barra inferiore

### ✅ Transazioni
- **Salvataggio transazione**
  - Tipo: `Success` (doppio tap + vibrazione forte)
  - Quando: Dopo aver salvato una nuova transazione

- **Eliminazione transazione**
  - Tipo: `Warning` (singolo tap + vibrazione media)
  - Quando: Dopo aver eliminato una transazione

- **Conferma transazione ricorrente**
  - Tipo: `Success`
  - Quando: Quando premi "Conferma" su un suggerimento ricorrente

### ✅ Report Entrate/Uscite
- **Cambio periodo** (7 giorni, mese, anno, ecc.)
  - Tipo: `Selection`
  - Quando: Tocchi un pulsante periodo

- **Cambio tipo grafico** (Barre ↔ Torta)
  - Tipo: `Soft` (vibrazione delicata)
  - Quando: Switchi tra grafici

- **Selezione conto**
  - Tipo: `Soft`
  - Quando: Tocchi un conto nella lista

- **Applicazione filtro**
  - Tipo: `Light`
  - Quando: Premi "Applica" sui filtri conti o date

### ✅ Account/Categorie/Budget
- **Creazione account**
  - Tipo: `Success`
  - Quando: Salvi un nuovo account

- **Creazione categoria**
  - Tipo: `Success`
  - Quando: Salvi una nuova categoria

- **Creazione budget**
  - Tipo: `Success`
  - Quando: Salvi un nuovo budget

---

## 🎯 Tipi di feedback implementati

| Tipo | Sensazione | Quando usarlo |
|------|-----------|---------------|
| **Light** | Tocco leggero | Azioni minori, conferme |
| **Medium** | Tocco normale | Azioni standard |
| **Heavy** | Tocco forte | Azioni importanti |
| **Soft** | Morbido, delicato | Selezioni, hover |
| **Rigid** | Deciso, solido | Limiti, stop |
| **Success** | ✓ Positivo (2 tap) | Salvataggi riusciti |
| **Warning** | ⚠️ Attenzione (1 tap) | Eliminazioni, avvisi |
| **Error** | ✗ Negativo (3 tap) | Errori |
| **Selection** | Cambio selezione | Tab, picker, segmented control |

---

## 🐛 Troubleshooting

### Non sento nessun feedback:

1. **Stai usando il simulatore?**
   - ❌ Il simulatore NON supporta haptic feedback
   - ✅ Usa un iPhone fisico

2. **Controlla le impostazioni iPhone:**
   - Impostazioni > Suoni e feedback aptico
   - Attiva "Feedback aptico sistema"
   - Attiva "Suoneria e avvisi tattili"

3. **Verifica che i file siano aggiunti a Xcode:**
   - `HapticManager.swift` deve essere nella cartella Utilities
   - Deve essere incluso nel target "MyMoney"

4. **Compila e rilancia l'app:**
   - Pulisci la build: `Cmd+Shift+K`
   - Ricompila: `Cmd+B`
   - Lancia su iPhone fisico

5. **Testa con la vista di debug:**
   - More > Test Haptic Feedback
   - Prova tutti i pulsanti
   - Se non funzionano, c'è un problema con le impostazioni iPhone

### Il feedback è troppo debole:

- Su alcuni modelli iPhone più vecchi, il Taptic Engine è meno potente
- Prova i feedback `Heavy` o `Rigid` per sensazioni più forti

### Il feedback è ritardato:

- Normale per alcuni tipi di feedback
- I generatori hanno un piccolo delay di preparazione
- Se il delay è troppo grande, potrebbe essere un problema di performance

---

## 📝 Note aggiuntive

- I feedback sono ottimizzati per iPhone con Taptic Engine (iPhone 7+)
- Su modelli più vecchi, i feedback potrebbero essere limitati
- L'intensità varia leggermente tra modelli di iPhone
- Gli haptic consumano pochissima batteria

---

## 🔧 Personalizzazione futura

Per aggiungere haptic in altre parti dell'app:

```swift
// Esempio base
HapticManager.shared.light()

// Esempi context-specific
HapticManager.shared.transactionSaved()
HapticManager.shared.itemSelected()
HapticManager.shared.periodChanged()
```

---

**Testato su:** iPhone 12 e successivi
**iOS Version:** 15.0+
**Data:** 26 Gennaio 2026
