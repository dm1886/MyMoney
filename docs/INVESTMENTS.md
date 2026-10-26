# Attività e investimenti — stato e configurazione

8 ottobre 2026. Prima implementazione locale; validazione automatica e verifica parziale nel simulatore completate. Non è un'integrazione di trading con un broker.

## Scelte concordate

- Attività semplice gratuita: capitale e interesse annuo lordo.
- Conto azioni a pagamento: MyMoney Pro.
- PAC con registrazione automatica stimata come predefinita, poi riconciliazione dei dati del broker.
- Conti Attività precedenti conservati: la configurazione delle nuove modalità è esplicita.

## Prima fase senza API — crescita attesa e riconciliazione

I nuovi conti investimenti Pro usano per default una proiezione complessiva locale. L'attività semplice resta gratuita. I conti titoli già salvati mantengono il loro registro; il passaggio esplicito alla proiezione è disponibile solo senza operazioni o PAC, per non perdere dati.

- Liquidità e valore investito iniziale separati; crescita annua attesa da −100% a +100%, semplice su giorni di calendario/365, applicata solo agli investimenti e ponderata per le date degli apporti. La stima è limitata inferiormente a zero.
- Rilevazioni manuali datate del valore complessivo delle posizioni, esclusa liquidità. Una rilevazione sostituisce la stima a quella data e diventa la base delle proiezioni successive; non crea un'entrata.
- Investimenti/disinvestimenti manuali spostano liquidità all'interno del conto. Per i fondi da altri conti si usa il trasferimento esistente. I movimenti interni sono registrabili in ordine cronologico dopo l'ultima rilevazione/movimento; non riscrivono riconciliazioni successive.
- Risultato monetario rilevato = ultimo valore confermato − valore iniziale − capitale netto investito. Non viene esposta una percentuale di rendimento non ponderata per i flussi.
- Grafico con proiezione tratteggiata e punti di rilevazione distinti; nessun prezzo di mercato ricostruito o richiesto online.
- Promemoria facoltativo il 31 dicembre alle 18 locali, previa abilitazione delle notifiche. Riconciliazione disponibile in qualsiasi momento. Frequenze mensili/trimestrali e variazioni storicizzate del tasso restano da aggiungere.
- Il payload opzionale è incluso nel backup esistente; il registro per singoli titoli rimane disponibile per i conti precedenti.

## Disponibile nel codice

- Creazione attività semplice e conto azioni; per il secondo si distinguono liquidità iniziale e saldo investito da dettagliare.
- Configurazione di un'attività esistente: la quota investita viene riclassificata dal saldo già presente, senza creare nuovo patrimonio.
- Interesse semplice lordo: giorni di calendario effettivi / 365, capitale ponderato per versamenti e prelievi. È una stima separata dalla liquidità, inclusa nel valore stimato dell'attività. Non include tasse né accrediti automatici.
- Accredito manuale degli interessi: registra l'importo netto effettivo come entrata e fa ripartire la stima dalla data dell'accredito. Il collegamento segue lo stato della transazione ed è rimappato al ripristino del backup.
- Strumenti manuali con nome, ticker, borsa, valuta e ISIN facoltativo. L'identità comprende il mercato; il ticker da solo non identifica sempre una quotazione.
- Posizioni iniziali, acquisti, vendite parziali e dividendi. Quantità frazionarie, cambio dell'operazione e commissioni/imposte espliciti.
- Per le posizioni iniziali il valore di mercato dichiarato è separato dal costo storico. Il valore iniziale viene scalato dalla quota ancora da dettagliare, senza addebito della liquidità.
- Risultato realizzato e non realizzato con costo medio ponderato, non un rendiconto fiscale.
- Quotazioni manuali datate; valore storico calcolato usando solo prezzi disponibili a quella data. In assenza di quotazioni si usa il prezzo dell'operazione, o il valore iniziale dichiarato per le posizioni di apertura, con avviso visibile.
- PAC mensili con intervallo da 1 a 12 mesi, acquisto singolo pianificato, data finale opzionale, pausa/ripresa e notifiche opzionali. Il giorno di fine mese rimane ancorato alla data iniziale.
- Recupero dei PAC all'attivazione dell'app e all'aggiornamento del portafoglio; chiave stabile per scadenza contro duplicati. Si richiede una quotazione non successiva alla scadenza e non più vecchia di quattro giorni. Senza quotazione adeguata o fondi il piano resta da completare manualmente.
- Le quote stimate sono arrotondate per difetto a otto decimali. Il prezzo di un PAC resta stimato anche quando la quotazione è recente: non equivale al prezzo di esecuzione del broker.
- Riconciliazione: sostituisce la stima, conservandone l'identificativo di scadenza e ricalcolando liquidità e posizioni. Controllo delle quote vendute e dei fondi disponibili anche per correzioni retrodatate.
- Portafoglio con riepilogo, titoli, registro operazioni, scadenze da completare e grafico giornaliero degli ultimi 30 giorni.
- Integrazione del valore del patrimonio nella Home, in Bilancio e nello storico; nei selettori dei conti la disponibilità resta la liquidità.
- Payload investimento opzionale su Account. I conti precedenti senza payload mantengono il comportamento esistente. Backup completo e backup Solo Conti includono i dati investimento; quest'ultimo conserva anche i flussi finanziari necessari per ricostruire i valori senza esportare le normali transazioni.
- Prevalidazione del payload investimento prima che il ripristino cancelli i dati correnti.

## Quotazioni online: predisposte, non attive

`InvestmentMarketService` è il client del gateway MyMoney; non contiene chiavi del fornitore e non restituisce prezzi simulati. La ricerca online e gli aggiornamenti richiedono un backend da implementare/deployare e un fornitore autorizzato. In questa versione, senza configurazione, resta disponibile la gestione manuale.

Configurazione futura in Info.plist:

- `InvestmentMarketURL`: URL HTTPS del gateway.
- `InvestmentProductIDs`: array degli identificativi reali degli abbonamenti App Store Connect.

Contratto atteso dal gateway:

- `GET /search?q=...`: array JSON di `InvestmentInstrument`, con identità stabile della quotazione, ticker, nome, ISIN quando disponibile, borsa e valuta.
- `GET /quotes?instrument=...&currency=EUR&from=<ISO8601>`: array JSON di `InvestmentQuote` con `id` UUID, `instrumentID`, `price`, `fxToAccount`, `date` ISO8601, `source`, `isRealtime`. Il cambio è nella valuta del conto richiesta e deve riferirsi alla data del prezzo, non essere sostituito arbitrariamente dal cambio odierno.
- Il client invia il JWS StoreKit nell'header Authorization. Il server deve verificarne firma, ambiente, bundle, prodotto e stato dell'abbonamento, incluso revoca/scadenza; un JWS passato dal client non è di per sé un'autorizzazione già verificata dal server.
- Il server deve proteggere le chiavi del fornitore, limitare richieste, gestire cache e diritti per borsa, normalizzare unità come pence/sterline, fornire errori per dati non disponibili e distinguere realtime/ritardato/chiusura.
- A servizio configurato, il dettaglio del portafoglio richiede aggiornamenti ogni 60 secondi mentre è attivo. Non è uno stream tick-by-tick; la frequenza e l'etichetta dipendono dal servizio effettivo.

Twelve Data è un candidato da valutare: ricerca/strumenti, prezzi e storico sono documentati; ISIN e redistribuzione richiedono condizioni specifiche. Non è stato acquistato alcun piano o attivato alcun contratto. Fonti: [API](https://twelvedata.com/docs/markets/market-state), [condizioni](https://twelvedata.com/terms).

Da definire con il proprietario dell'app: mercati prioritari, copertura ETF/fondi, budget dati e licenza di visualizzazione agli abbonati. Non chiamare “realtime” dati ritardati o manuali.

## Paywall: integrazione StoreKit, vendita non attiva

- L'attività semplice non richiede un entitlement.
- Nuovi conti azioni e modifiche richiedono un entitlement verificato; sono consultabili i dati già salvati anche dopo la perdita di accesso.
- Prodotti, acquisto nativo e ripristino sono predisposti. Senza identificativi reali il paywall mostra che il servizio non è ancora disponibile.
- Nessun prezzo o prodotto App Store è stato inventato o pubblicato.
- Prima della distribuzione: configurare prodotti/gruppo abbonamento, prezzo, informative privacy/termini, acquisto/ripristino/rinnovo/revoca in sandbox e verifica server delle licenze dati.
- Per QA locale selezionare lo schema **MyMoney Investments QA**: passa `-investment-preview`, riconosciuto solo nelle build DEBUG. La build Release ignora sempre questo argomento. Questa anteprima non prova un acquisto StoreKit.

Riferimento: [StoreKit currentEntitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements).

## Limiti operativi

- Nessun ordine reale, collegamento broker o trasferimento di denaro: tutte le operazioni sono registrazioni locali.
- iOS non garantisce esecuzioni in background a un'ora esatta. Le notifiche ricordano la scadenza; l'app recupera il registro quando torna attiva. Non è stata introdotta una promessa di esecuzione del PAC a dispositivo spento o app chiusa.
- Le notifiche investimento usano identificativi propri e rispettano lo spazio disponibile, fino a 24 scadenze, senza cancellare notifiche di normali transazioni.
- Il grafico ricostruisce i dati disponibili; non inventa uno storico antecedente alle posizioni o ai prezzi registrati.
- Non sono implementati split, fusioni, fiscalità, short selling, opzioni, lotti fiscali, importazione CSV o sincronizzazione broker.
- Il tasso dell'attività semplice è costante per la configurazione attuale. Variazioni storicizzate del tasso e accrediti retrodatati richiedono un intervento dedicato.
- L'archivio investimento è un payload per conto: prima di abilitare la distribuzione verificare migrazione su copie di archivi preesistenti, sincronizzazione CloudKit e modifiche concorrenti tra dispositivi. Non presentare i test in memoria come verifica della sincronizzazione.

## Verifiche

- Build Debug per simulatore e Release per iOS riuscite. La Release è compilata con firma disabilitata: non equivale a un archivio firmato o a una pubblicazione App Store.

- Suite `InvestmentTests`: acquisti/vendite/dividendi, liquidità e quote insufficienti, correzioni retrodatate, apertura senza doppio conteggio, costo diverso dal valore iniziale, prezzi storici, valuta estera, idempotenza e riconciliazione PAC, prezzi mancanti, fine mese, acquisto singolo, interesse ponderato per i flussi, accredito interessi, backup completo e Solo Conti, payload non valido e accesso Pro.
- Suite Orb precedente mantenuta ed eseguita insieme ai nuovi test: **27 test superati, zero errori** (17 investimenti, 10 Orb).
- Simulatore dedicato **MyMoney Investment QA**, iOS 26.2: creazione e riapertura di Deposito QA, EUR 1.000, tasso 5%; riepilogo capitale, tasso e stima osservati.
- Simulatore conto azioni: Broker QA con EUR 500 liquidi e EUR 2.000 investiti; strumento manuale ETF QA/TEST, 10 quote, costo storico EUR 1.500 e valore iniziale EUR 2.000. Dopo il salvataggio: patrimonio EUR 2.500, liquidità EUR 500, risultato non realizzato EUR 500; nessun doppio conteggio.
- Non ancora verificati end-to-end: PAC e riconciliazione tramite UI, feed di mercato reale, acquisto StoreKit reale/sandbox, ricezione di tutte le notifiche, migrazione di un archivio reale e sincronizzazione iCloud.


Verifica aggiornamento locale: 31 test superati (21 investimenti e suggerimenti, 10 Orb). Simulatore iOS 26.2: creazione Proiezione QA, separazione capitale/liquidità, schermata stima e conferme; Home con oltre un miliardo su una riga; modulo “+” con importo lungo. La consegna del promemoria annuale su dispositivo e tutti i flussi di riconciliazione tramite UI restano da verificare.
