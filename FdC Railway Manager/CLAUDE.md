# CLAUDE.md — Regole "Code That Fits in Your Head"
# Train Scheduler iPad App — Swift/SwiftUI

## Filosofia generale
Il codice è una **passività**, non un asset. Ogni riga aggiunta è una riga da mantenere.
Ottimizza sempre per la **leggibilità**, non per la furbizia.
I tre moduli (Editor, Scheduler, Simulator) sono **indipendenti**: nessuno importa
tipi interni di un altro. Comunicano solo attraverso i modelli di dominio condivisi
definiti in `Domain/`.

---

## Struttura del progetto

```
TrainScheduler/
├── Domain/                  # Modelli puri, zero dipendenze UI o framework
│   ├── Model/               # Line, Station, Stop, Schedule, Train, SimEvent…
│   └── Services/            # Protocolli: ScheduleGenerator, Validator…
├── Editor/                  # Modulo 1 — editing linee ferroviarie
│   ├── ViewModel/
│   └── View/
├── Scheduler/               # Modulo 2 — generazione orari
│   ├── ViewModel/
│   └── View/
├── Simulator/               # Modulo 3 — simulazione / game
│   ├── Engine/              # Logica pura di simulazione (no SwiftUI)
│   ├── ViewModel/
│   └── View/
├── Infrastructure/          # Persistenza, rete, file I/O
│   ├── Persistence/
│   └── Export/
├── FeatureFlags.swift
└── AppRoot/                 # Entry point, DI root, navigazione top-level
```

**Regola di dipendenza**: le frecce puntano sempre verso `Domain/`.
`Editor`, `Scheduler`, `Simulator` non si importano mai a vicenda.

---

## 1. Regola del 7 (Rule of 7)

- Complessità ciclomatica per funzione: **≤ 7**.
- Somma di (parametri + variabili locali + proprietà usate) per funzione: **≤ 7**.
- Se superi 7, estrai in una funzione o tipo separato.
- Esempi di violazione tipica in questo progetto:
  - Un metodo che calcola l'orario E valida E salva → tre responsabilità, dividile.
  - Una `View` con più di 7 sotto-view inline → estrai componenti.

## 2. Regola 80/24

- Larghezza massima: **80 caratteri** per riga.
- Corpo di ogni funzione/metodo: **massimo 24 righe**.
- Se non ci stai, è un segnale di decomposizione mancante.
- Eccezione accettata: dichiarazioni di tipo lunghe su più righe (es. closure SwiftUI
  multiriga) — ma il corpo logico deve comunque rispettare il limite.

## 3. Command Query Separation (CQS)

- Un metodo **o** modifica stato **o** restituisce un valore — mai entrambe le cose.
- In questo progetto:
  - `scheduleGenerator.generate(for: line) -> Schedule` → query (OK)
  - `simulator.advance(by: tick)` → command, non restituisce nulla (OK)
  - `simulator.advance(by: tick) -> [SimEvent]` → violazione CQS; usa invece
    un publisher/AsyncStream separato per gli eventi.
- I metodi `@discardableResult` richiedono commento `// JUSTIFY:`.

## 4. Parse, Don't Validate

- Converti i dati grezzi in tipi di dominio **al confine** del sistema:
  - Input utente (coordinate, orari) → `init` throwing o `Optional` nei ViewModel.
  - File JSON/CSV importati → decoder con `init(from:) throws` nei tipi `Domain/`.
- Non passare `String` o `Double` grezzo oltre il layer Infrastructure/ViewModel.
- Esempi di tipi sicuri da usare:
  ```swift
  struct Coordinate: Codable {
      let latitude: Double   // -90…90
      let longitude: Double  // -180…180
      init(latitude: Double, longitude: Double) throws { … }
  }
  struct Altitude: Codable {  // in metri
      let value: Double
      init(_ value: Double) throws { guard value >= -500 else { throw … } … }
  }
  ```

## 5. Functional Core, Imperative Shell

- **Core puro** (in `Domain/` e `Simulator/Engine/`):
  - `Schedule`, `Line`, `SimulationState` sono `struct` immutabili.
  - `ScheduleGenerator`, `ConflictDetector`, `SimulationEngine` sono funzioni pure
    o tipi senza side-effect.
  - Testabili senza simulatore, senza UI, senza file system.
- **Shell imperativa** (ViewModel, Infrastructure):
  - Gestisce I/O, persistenza, timer, notifiche.
  - Chiama il core e pubblica il risultato via `@Published` o `AsyncStream`.
- Le `View` SwiftUI sono **solo** presentazione: nessuna logica di dominio al loro interno.

## 6. Iniezione delle dipendenze esplicita

- Niente `MyService.shared` nella logica di dominio o nei ViewModel.
- Le dipendenze vengono iniettate via `init`:
  ```swift
  final class SchedulerViewModel: ObservableObject {
      init(generator: ScheduleGenerating, store: ScheduleStoring) { … }
  }
  ```
- I protocolli per le dipendenze vivono in `Domain/Services/`.
- `@EnvironmentObject` è accettato **solo** nel layer `View/`, mai nei ViewModel.
- `AppRoot/` è l'unico posto dove si costruisce il grafo delle dipendenze reali.

## 7. Gestione degli errori esplicita

- Vietati `try!` e `fatalError` senza commento `// JUSTIFY: <motivo>`.
- Niente `catch {}` vuoti: ogni errore viene loggato o presentato all'utente.
- Usa `Result<T, AppError>` o `throws`; mai booleani di successo.
- Definisci errori tipizzati per dominio:
  ```swift
  enum ScheduleError: Error {
      case conflictDetected(Train, Train, at: TimeInterval)
      case noFeasibleSlot(Station)
  }
  ```

## 8. Nomi significativi

- Prima di finalizzare un nome, sostituiscilo con `foo`: se il codice perde senso,
  il nome è insufficiente.
- Niente abbreviazioni non standard: `mgr`, `vc`, `tmp`, `btn`, `stn` → vietate.
  Usa `stationEditor`, `viewController`, `temporaryBuffer`, `button`, `station`.
- Convenzioni di questo progetto:
  - Modelli: sostantivi (`Line`, `Station`, `Schedule`, `Train`)
  - Protocolli di servizio: suffisso `-ing` o `-able` (`ScheduleGenerating`, `Exportable`)
  - ViewModel: `<Feature>ViewModel` (non `VM`, non `Controller`)
  - View SwiftUI: `<Feature>View` o `<Feature>Screen` per schermate intere

## 9. Test: Arrange-Act-Assert

- Ogni unit test ha esattamente **tre sezioni** separate da una riga vuota:
  setup, azione, asserzione.
  ```swift
  func test_scheduleGenerator_returnsConflict_whenTrainsOverlap() throws {
      let line = Line.stub(withOverlappingTrains: true)
      
      let result = try generator.generate(for: line)
      
      XCTAssertTrue(result.hasConflicts)
  }
  ```
- I test di integrazione/UI hanno al massimo **una asserzione** significativa.
- Naming: `test_<condizione>_<comportamentoAtteso>()`.
- Ogni bug fixato deve avere un test di regressione **prima** del fix.
- Il core puro (`Domain/`, `Simulator/Engine/`) deve avere copertura ≥ 80%.
- Le View non vengono testate unitariamente; usa test di snapshot solo se stabile.

## 10. Aggiornamento dipendenze

- Le dipendenze SPM vengono aggiornate almeno **una volta al mese**.
- Dipendenze con vulnerabilità note bloccano la build in CI.
- Ogni dipendenza esterna deve avere un commento in `Package.swift` che spiega
  perché non è stata reimplementata internamente.

## 11. Feature Flag e Strangler

- Ogni funzionalità sperimentale (es. modalità game, simulazione in tempo reale)
  è protetta da un flag in `FeatureFlags.swift`:
  ```swift
  enum FeatureFlags {
      static let simulatorGameMode = false
      static let realtimeConflictHighlight = false
  }
  ```
- La migrazione di codice legacy usa lo **Strangler pattern**: il vecchio codice
  rimane compilabile finché il nuovo non è completo e testato.
- Il modulo `Simulator/` è il candidato principale per il game mode: mantienilo
  separato da `Scheduler/` fin dall'inizio per questa ragione.

## 12. Git: commit atomici e messaggio 50/72

- Titolo del commit: massimo **50 caratteri**, imperativo presente.
  (`Add station altitude validation`, `Fix schedule conflict detection`)
- Corpo (se presente): a capo a **72 caratteri**; spiega il *perché*, non il *cosa*.
- Ogni commit deve **compilare** e **passare i test**.
- Prefissi consigliati: `Add`, `Fix`, `Refactor`, `Remove`, `Test`, `Docs`.

## 13. Separazione dei moduli: regole specifiche per questo progetto

| Modulo | Può importare | Non può importare |
|---|---|---|
| `Domain/` | solo stdlib e Foundation | Editor, Scheduler, Simulator, Infrastructure |
| `Editor/` | Domain, Infrastructure | Scheduler, Simulator |
| `Scheduler/` | Domain, Infrastructure | Editor, Simulator |
| `Simulator/` | Domain, Infrastructure | Editor, Scheduler |
| `Infrastructure/` | Domain | Editor, Scheduler, Simulator |
| `AppRoot/` | tutto | — |

---

## Eccezioni

Ogni deroga a queste regole va marcata con un commento inline:

```swift
// JUSTIFY: superato limite 24 righe perché [motivo preciso]
// JUSTIFY: dipendenza diretta tra moduli perché [motivo preciso]
```

Le eccezioni non giustificate sono errori di review.
