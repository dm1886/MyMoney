# MyMoney — redesign Orb

Verifica del 7 ottobre 2026, branch `codex/redesign-orb`, base `63ca9fe`.
Riferimento visivo: `MyMoney_Redesign_Orb_Linee_Guida_2.pdf` (v1.2, 30 pagine) fornito dall'utente.

## Implementazione

- Sistema di colori condiviso con Notte, Aurora, Brace, Oceano e Grafite, ciascuno in modalità chiara e scura; font Sora incluso con licenza OFL.
- Orb animato, componenti condivisi, schermate Home, Bilancio, Oggi, Budget, Resoconto, Impostazioni e moduli aggiornati.
- Temi personali con anteprima, duplicazione, modifica, eliminazione e correzione del contrasto. Preferenze in UserDefaults; campi opzionali nei backup per compatibilità con quelli precedenti. Migrazione del vecchio accento personalizzato.
- Animazioni decorative subordinate a movimento ridotto, risparmio energetico, visibilità e attività della scena. Importi interpolati solo nella presentazione: a riposo viene formattato il valore Decimal originale.
- Conservati TabView, cinque sezioni, quindici tipi di widget e sei stili del saldo; navigazione visibile sostituita dalla Capsule B con pillola animata, ri-selezione della radice e unico pulsante Nuova transazione. L'inserimento importi mantiene il TextField e la tastiera decimale nativi.
- Nei budget le azioni sono disponibili nel menu della scheda; nessun totale aggrega budget di valute differenti.

### Allineamento alla revisione 1.2

- Orb a due forme piene, colori del tema, senza alone o gradiente; Sora e importi con simbolo separato e due decimali.
- Home con saluto e pannello Personalizza: griglia di sei stili, aggiunta/rimozione/riordino widget e ripristino della configurazione iniziale.
- Nove visualizzazioni: colonne Spese, colonne Entrate/Uscite, cumulata mensile, donut categorie, anelli budget, avanzamento rispetto al tempo, calendario mensile, area patrimonio, classifica orizzontale delle categorie.
- Palette dei grafici separate dai colori semantici finanziari; assi ridotti, selezione dei valori, tabelle equivalenti e descrittori di accessibilità. Forma coerente fra chiaro e scuro.
- Animazioni di barre, linee, donut e anelli; orb, pillola della capsula, pulsazione del pulsante e conferma del salvataggio. Rispetto delle impostazioni di movimento ridotto.
- Menu visibile dei conti e menu contestuale collegati alle azioni originali. Selettore dei cinque tipi di transazione nel modulo di inserimento e categorie frequenti.
- Gli intervalli dei grafici sono calcolati nella presentazione. Per lo storico si riutilizzano le regole già presenti nella vista storica; il punto attuale del patrimonio usa il saldo corrente del conto. Nessuna riscrittura del registro finanziario.

## Integrità

I file dei modelli SwiftData e `MoneyTrackerApp.swift` sono identici alla base. Non è stata introdotta una migrazione dello schema né cambiata la configurazione del contenitore. Le funzioni di autenticazione sono conservate. Le modifiche al backup riguardano le preferenze grafiche opzionali; il payload finanziario mantiene la struttura esistente.

La verifica statica delle funzioni preesistenti individua, oltre alle viste, le aggiunte alle preferenze di backup e adattamenti dei colori nei report/selettori. I dati reali dell'utente non sono stati utilizzati per i test. La cartella preesistente `Claude outputs/` non è stata modificata.

## Verifiche riuscite

- Build Debug per simulatore e Release per dispositivo generico, senza firma.
- Dieci test XCTest: palette specifiche dei grafici e formattazione italiana; snapshot storici senza modificare il saldo; palette e contrasto; correzione dei temi personali; registrazione Sora; lettura di vecchi backup; persistenza delle preferenze e ripristino finanziario; cinque tipi di transazione e stato pending; ricorrenze da backup precedente; trasferimenti con cambio salvato e calcoli budget.
- Test finanziari con contenitore SwiftData in memoria, senza CloudKit.
- Simulatore dedicato iPhone 17 Pro, iOS 26.4: creazione conto di prova, spesa 12,35 EUR da saldo iniziale 1.000,25 EUR, saldo risultante 987,90 EUR; riavvio con persistenza; budget 100 EUR con spesa 12,35 EUR e residuo 87,65 EUR; apertura dettaglio budget; passaggio dei temi e modalità scura; anteprima chiara/scura del creatore temi.
- Revisione 1.2 sul simulatore: menu Modifica conto; ritorno alla radice con nuova selezione Bilancio; pannello Personalizza con aggiunta, riordino e rimozione del widget di prova; importi e budget conservati dopo riavvio; prima etichetta dell’asse X leggibile; ultimo widget interamente visibile sopra la capsula dopo la correzione dello spazio inferiore.
- `git diff --check` senza errori.

## Limiti della verifica

Non è stata eseguita una regressione manuale esaustiva di tutte le combinazioni di widget, stili, report e ricorrenze. La persistenza dei temi personali è coperta dai test, ma il salvataggio tramite pulsante nell'editor non è stato completato nella prova manuale: l'automazione delle coordinate del simulatore ha restituito `noWindowsAvailable`; l'anteprima è stata chiusa senza salvare.

Non è stato misurato ogni timing con strumenti né confrontato un canvas privato esterno al PDF. La copertura visiva di tutti i nove grafici, di tutte le palette e delle combinazioni multivaluta storiche resta parziale.

Da validare su iPhone reale: Face ID/passcode, sincronizzazione iCloud, notifiche, VoiceOver completo, tutte le dimensioni Dynamic Type e misure di energia/fluidità con Instruments. Non sono state effettuate pubblicazioni, installazioni sul telefono, commit o push. Le build e i test non costituiscono una garanzia di assenza di ogni regressione.

## Ripetere i test

Aprire `MyMoney.xcodeproj`, selezionare lo schema condiviso `MyMoney` e un simulatore iOS compatibile, quindi eseguire Product → Test. Il target `MyMoneyTests` contiene la suite `OrbRegressionTests`.


## Aggiornamento 8 ottobre 2026 — investimenti

Le osservazioni precedenti sulla mancata modifica dei modelli si riferiscono al solo redesign. Il modulo investimenti successivo aggiunge un payload opzionale ad Account e aggiorna backup e valorizzazione: stato e limiti in [INVESTMENTS.md](INVESTMENTS.md). Le dieci regressioni Orb sono state rieseguite insieme ai diciassette test investimenti, tutti superati. Migrazione di archivi reali e sincronizzazione CloudKit restano da verificare.
