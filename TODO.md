# MyMoney — TODO e wishlist

Aggiornato: 8 ottobre 2026.

Questa checklist raccoglie le richieste e le idee discusse. Le voci non spuntate sono da progettare, implementare o verificare; non indicano funzionalità già disponibili. L'ordine di priorità è una proposta. Spuntare una voce solo dopo la relativa verifica.

## Già realizzato e verifiche aperte

- [x] Implementare il redesign Orb nel codice, conservando le cinque sezioni, i 15 widget e i sei stili del saldo.
- [x] Eseguire la suite di regressione Orb: 10 test superati nella verifica precedente. Ripeterli quando cambiano salvataggi, modelli o calcoli.
- [x] Rimuovere lo stile glass interno del pulsante Conto in Bilancio; compilazione Debug senza firma riuscita.
- [ ] Confermare sul dispositivo che Conto abbia una sola cornice e apra Aggiungi conto.
- [ ] Risolvere la firma per l'iPhone: il log esaminato segnala account Xcode assente e profilo non compatibile con il certificato selezionato. Verificare nuovamente dopo accesso all'account sviluppatore.
- [ ] Completare QA visiva di grafici, temi chiari/scuri, pannelli e animazioni rispetto alla guida Orb v1.2.
- [ ] Verificare su dispositivo Face ID, iCloud, notifiche, Dynamic Type, VoiceOver e movimento ridotto.

Dettagli delle verifiche e dei limiti: [ORB_REDESIGN_QA.md](docs/ORB_REDESIGN_QA.md).

## P0 — Fondamenta comuni per inserimenti rapidi

- [ ] Individuare il percorso di salvataggio esistente e renderlo riutilizzabile da modulo, Siri e importazioni, preservando il comportamento corrente.
- [ ] Definire una bozza con importo, valuta, data, esercente/nota, categoria, conto e provenienza: voce, immagine o manuale.
- [ ] Impostare data odierna e conto/valuta preferiti quando appropriato; chiedere i dati realmente mancanti.
- [ ] Validare importi con Decimal, separatori locali e conversioni; mantenere i calcoli fuori dai modelli AI.
- [ ] Gestire tentativi ripetuti senza salvare due volte la stessa richiesta; distinguere un duplicato da due acquisti reali dello stesso importo.
- [ ] Mantenere il blocco biometrico e le regole di autenticazione anche negli accessi esterni.
- [ ] Verificare creazione, annullamento, errore di salvataggio, aggiornamento saldo/budget e compatibilità dei backup.

## P1 — Siri e Comandi Rapidi

Obiettivo iniziale: «Siri, aggiungi una spesa in MyMoney» → richiesta dei dati mancanti → riepilogo → conferma vocale → salvataggio.

- [ ] Esporre Aggiungi spesa con App Intent e App Shortcut.
- [ ] Supportare importo, valuta, conto, categoria, data e nota; risolvere nomi ambigui senza scegliere arbitrariamente.
- [ ] Aggiungere frasi italiane e inglesi, con il nome MyMoney.
- [ ] Restituire una conferma vocale con importo e conto, senza obbligare ad aprire il modulo quando esecuzione e autenticazione lo consentono.
- [ ] Verificare la frase completa «Add an expense of 12 euros in MyMoney» e l'equivalente italiano su dispositivi reali; mantenere il dialogo guidato come alternativa.
- [ ] Verificare la policy di autenticazione con telefono bloccato e app protetta.
- [ ] Rendere l'azione utilizzabile anche da Comandi Rapidi e pulsante Azione sui dispositivi compatibili.
- [ ] Valutare gli App Schemas e le novità Siri disponibili sul sistema di destinazione, senza rendere obbligatorie le funzionalità più recenti.
- [ ] Provare importo assente, conto inesistente, categoria ambigua, valuta diversa, annullamento, richiesta ripetuta e assenza di rete.

Wishlist Siri:

- [ ] Aggiungi entrata.
- [ ] Registra un preferito, per esempio il caffè abituale.
- [ ] Consulta il budget residuo di una categoria.
- [ ] Consulta le spese di oggi o del mese, rispettando la protezione dei dati.

## P1 — Screenshot e ricevute

Obiettivo: screenshot → Condividi → MyMoney → riepilogo precompilato → Salva.

- [ ] Aggiungere un'estensione per ricevere immagini dalla condivisione di iOS.
- [ ] Definire lo scambio delle bozze fra estensione e app, evitando migrazioni o aperture concorrenti non controllate del database.
- [ ] Aggiungere anche l'importazione di un'immagine dall'app.
- [ ] Estrarre il testo con Apple Vision OCR.
- [ ] Riconoscere importo pagato, valuta, data ed esercente; distinguere totale, saldo disponibile, commissioni e altri numeri presenti nell'immagine.
- [ ] Suggerire conto e categoria; evidenziare i campi incerti e chiedere una conferma prima del salvataggio.
- [ ] Riconoscere lo stato del pagamento: completato, in attesa, fallito o rimborso, senza registrare automaticamente tutto come spesa eseguita.
- [ ] Cercare possibili duplicati anche rispetto alle transazioni inserite manualmente.
- [ ] Gestire ricevute multivaluta e screenshot con più movimenti attraverso una selezione esplicita.
- [ ] Definire se conservare l'allegato, per quanto tempo e come eliminarlo; non salvarlo automaticamente senza una scelta chiara.
- [ ] Valutare Apple Foundation Models sul dispositivo per interpretazione e classificazione; prevedere OCR e regole quando il modello non è disponibile.
- [ ] Valutare un servizio AI cloud opzionale solo dopo una prova comparativa: accuratezza, latenza, costo e dati inviati. Nessun invio esterno implicito.
- [ ] Verificare con un campione di ricevute e screenshot anonimizzati, in italiano e inglese e con valute/formati differenti.

## Aggiornamento — prima fase locale e inserimento rapido

- [x] Aggiungere proiezione investimenti senza API con crescita annua attesa, distinta dalla liquidità.
- [x] Aggiungere riconciliazioni manuali datate e movimenti interni di capitale; risultato al netto degli apporti.
- [x] Distinguere graficamente stima e valori confermati; aggiungere promemoria annuale opzionale.
- [ ] Aggiungere frequenze mensili/trimestrali e variazioni storicizzate del rendimento atteso.
- [x] Ridimensionare l'importo animato nella sfera Home e mantenere gli importi su una riga.
- [x] Esplicitare saldo netto e disponibilità delle carte: 90.000 disponibili con limite 60.000 = +30.000 netti. Supportare la conversione in creazione e aggiustamento saldo.
- [x] Allineare il modulo “+” al riferimento del PDF: importo, conto/data, categorie frequenti a griglia e pianificazione.
- [x] Proporre ricorrenze dopo tre operazioni simili in giorni diversi, richiedendo revisione e salvataggio espliciti.
- [ ] Verificare consegna dei promemoria su dispositivo e accessibilità/Dynamic Type su tutti i formati.

## P2 — Conti investimento

Stato implementazione: [dettagli e limiti](docs/INVESTMENTS.md). Decisioni confermate: **attività semplice gratuita**, **conto azioni Pro**, **PAC automatico stimato da riconciliare**.

- [x] Aggiungere le due modalità nella creazione di Attività e configurazione esplicita per i conti esistenti.
- [x] Implementare interesse annuo semplice e distinguere stima maturata da liquidità.
- [x] Implementare registro locale di posizioni, acquisti, vendite e dividendi con costo medio ponderato.
- [x] Separare il valore iniziale delle posizioni dal costo di acquisto, senza doppio conteggio del patrimonio.
- [x] Implementare PAC/acquisto singolo, stime, riconciliazione, pausa/ripresa e notifiche locali.
- [x] Aggiungere client del gateway quotazioni e integrazione StoreKit con accesso Pro verificato.
- [ ] Attivare un gateway e un fornitore con licenza: ricerca ticker/ISIN e feed reali non sono ancora disponibili.
- [ ] Configurare prodotti App Store Connect e validare acquisti/ripristino/rinnovi/revoche in sandbox.
- [x] Verificare nel simulatore creazione conto azioni e apertura posizione con costo distinto dal valore corrente.
- [ ] Completare QA manuale PAC/riconciliazione, notifiche e migrazione/sincronizzazione prima del rilascio.


Principio: separare liquidità, operazioni sui titoli e valore di mercato. Un aumento di quotazione modifica il patrimonio, ma non è un'entrata del budget quotidiano.

- [x] Definire il conto investimento senza alterare il significato dei conti e delle transazioni esistenti.
- [x] Modellare strumenti, identificativi (ISIN/ticker e borsa), valuta, quantità anche frazionarie e operazioni.
- [x] Registrare acquisti, vendite, commissioni, dividendi e trasferimenti di liquidità; evitare il doppio conteggio del patrimonio.
- [x] Distinguere valore corrente, costo delle posizioni aperte, plus/minusvalenze realizzate e non realizzate.
- [x] Scegliere e documentare il metodo di attribuzione del costo delle quote vendute; non presentare il risultato come rendiconto fiscale certificato.
- [ ] Selezionare il fornitore di quotazioni in base alle borse e agli strumenti utilizzati, verificando licenza, costi, limiti e copertura.
- [ ] Avviare con quotazioni giornaliere, aggiornamento manuale e cache locale; mostrare fonte e data dell'ultimo prezzo disponibile.
- [x] Conservare prezzi e cambi storici per evitare che una nuova quotazione riscriva il passato.
- [ ] Mostrare liquidità, posizioni, capitale versato, valore totale e grafico del patrimonio.
- [ ] Separare versamenti/prelievi dai rendimenti; scegliere e spiegare le metriche di performance.
- [x] Supportare inserimento manuale di strumenti e operazioni.
- [ ] Importare CSV con anteprima e controllo dei duplicati.
- [x] Progettare migrazione, backup e ripristino dei nuovi dati mantenendo leggibili i backup precedenti.
- [ ] Verificare acquisto, vendita parziale, dividendo, commissioni, trasferimento, cambio valuta, prezzo mancante e funzionamento offline.

Wishlist investimenti:

- [ ] Ripartizione per strumento, classe di attività e valuta.
- [ ] Confronto con un benchmark appropriato.
- [ ] Dividendi storici e calendario dei pagamenti disponibili dal fornitore.
- [ ] Gestione split e altre operazioni societarie.
- [ ] Importazione di rendiconti broker e riconciliazione delle posizioni.
- [ ] Collegamenti automatici ai broker, dopo verifica di compatibilità e condizioni dei servizi.

## P3 — Versione iPad (iPadOS)

- [ ] Adattare MyMoney a iPad con layout dedicati, navigazione a colonne e pannelli che sfruttino lo schermo grande, mantenendo il design Orb.
- [ ] Adattare grafici, widget e moduli a orientamento verticale/orizzontale e finestre ridimensionabili.
- [ ] Supportare tastiera, trackpad e scorciatoie per l'inserimento rapido.
- [ ] Verificare tutte le funzioni su iPhone e iPad, inclusi accessibilità, backup e investimenti, senza regressioni.

## P3 — Backup iCloud

- [ ] Implementare backup manuali e automatici su iCloud, con attivazione esplicita e data/esito dell'ultimo backup visibili.
- [ ] Mantenere copie versionate e definire frequenza, conservazione e gestione dello spazio disponibile.
- [ ] Offrire selezione della copia, anteprima del contenuto e conferma prima del ripristino; preservare una copia dello stato corrente.
- [ ] Includere conti, transazioni, investimenti, piani e impostazioni; definire la gestione degli eventuali allegati.
- [ ] Distinguere backup recuperabili e sincronizzazione tra dispositivi: verificare l'integrazione con l'iCloud già predisposto nell'app.
- [ ] Verificare ripristino su un nuovo dispositivo, assenza di rete, spazio esaurito, cambio account iCloud e backup di versioni precedenti.

## P4 — Sito web e gestione dal browser

- [ ] Creare il sito di MyMoney e progettare un'area web autenticata per consultare e gestire i propri conti.
- [ ] Definire backend e sincronizzazione tra web, iPhone e iPad, mantenendo utilizzabile l'app locale senza rete.
- [ ] Portare sul web saldo, movimenti, categorie, budget e conti condivisi con un'interfaccia coerente con Orb.
- [ ] Gestire accessi, sessioni, recupero account ed esportazione dei dati.
- [ ] Verificare coerenza dei calcoli, modifiche concorrenti e prevenzione dei duplicati tra dispositivi e browser.

## P4 — Conti condivisi con familiari e altre persone

- [ ] Consentire la condivisione di un singolo conto tramite invito, lasciando privati gli altri conti dell'utente.
- [ ] Definire ruoli e permessi: proprietario, membro che può inserire/modificare movimenti e accesso di sola lettura.
- [ ] Gestire insieme saldo, spese, entrate e budget del conto familiare.
- [ ] Mostrare chi ha inserito o modificato un movimento e conservare uno storico delle modifiche.
- [ ] Gestire accettazione/scadenza degli inviti, revoca dell'accesso, uscita dal gruppo e responsabilità sul conto condiviso.
- [ ] Sincronizzare le modifiche e risolvere conflitti o inserimenti offline senza duplicare movimenti.
- [ ] Aggiungere notifiche configurabili per i movimenti del conto condiviso.
- [ ] Definire backup, esportazione e ripristino dei conti condivisi rispettando i permessi dei partecipanti.
- [ ] Decidere quali funzioni condivise/web rientrano nel piano gratuito o Pro, senza modificare la scelta già confermata per attività semplice e conto azioni.
- [ ] Verificare il flusso completo con due utenti distinti su app e web, inclusa la revoca degli accessi.

## Wishlist — Meno passaggi per registrare una spesa

- [ ] Preferiti con categoria, conto e importo precompilati.
- [ ] Inserimento con frase scritta o dettata: «Pranzo 18 euro con Visa».
- [ ] Regole esercente → categoria/conto, modificabili dall'utente.
- [ ] Coda di bozze da completare in seguito, chiaramente distinta dalle transazioni eseguite.
- [ ] Widget e accesso dalla schermata di blocco per avviare l'inserimento rapido.
- [ ] Duplicazione rapida di una spesa precedente con nuova data.
- [ ] Automazione Comandi Rapidi dopo il tap di una carta Wallet: verificare trigger e dati effettivamente disponibili sul dispositivo, senza presumere accesso universale alle transazioni bancarie.
- [ ] Eventuale integrazione bancaria: studiare copertura geografica, provider, costi e consenso prima di progettare la sincronizzazione.

## Decisioni da prendere prima dei rispettivi moduli

- [ ] Siri: conti e categorie predefiniti, lingue da supportare e comportamento delle conferme.
- [ ] Screenshot: banche/app e tipi di ricevuta prioritari; immagini di prova anonimizzate.
- [ ] AI: mantenere tutto locale oppure offrire anche un'opzione cloud esplicita.
- [ ] Investimenti: broker, borse, azioni/ETF/altri strumenti e valute da coprire per primi.
- [ ] Quotazioni: frequenza desiderata e budget per il servizio dati.

## Riferimenti tecnici e di prodotto

- [Apple — App Intents](https://developer.apple.com/documentation/AppIntents)
- [Apple — Novità App Intents](https://developer.apple.com/documentation/updates/appintents)
- [Apple — App Shortcuts e frasi Siri](https://developer.apple.com/videos/play/wwdc2025/244/)
- [Apple — Share extensions](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html)
- [Apple — OCR con Vision](https://developer.apple.com/documentation/vision/recognizing-text-in-images)
- [Apple — Foundation Models e disponibilità](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)
- [Apple — Trigger transazioni in Comandi Rapidi](https://support.apple.com/en-lamr/guide/shortcuts/apd65c67538a/ios)
- [Portfolio Performance — Concetti di portafoglio e quotazioni](https://help.portfolio-performance.info/en/concepts/)
