# FdC Railway Manager

Applicazione **iPad** (Swift/SwiftUI) per la gestione di reti ferroviarie,
la creazione di orari (Taktfahrplan e modalità libera) e la simulazione
di servizi su infrastruttura reale o di fantasia — con focus sulla rete
**Ferrovia della Casentinese (FdC)** e scenari Toscana–Liguria.

Repository: [github.com/manvalan/FDC-App](https://github.com/manvalan/FDC-App)

---

## Funzionalità principali

| Area | Descrizione |
|------|-------------|
| **Editor** | Disegno e modifica della rete (stazioni, binari, segnali, deviatoi) |
| **Scheduler** | Generazione e ottimizzazione orari, Taktfahrplan, GA, AI cloud |
| **Simulator** | Simulazione movimento treni sulla rete (in evoluzione) |
| **I/O** | Import/export file `.rail`, `.fdc`, integrazione AI via WebSocket |

---

## Architettura (stato attuale)

Il progetto segue un refactor incrementale (*Strangler pattern*) verso
**Functional Core, Imperative Shell** (vedi `CLAUDE.md`).

```
FDC-App/
├── FdC Railway Manager/          # Target principale (sync group Xcode)
│   ├── Domain/Model/             # Modelli di dominio (in migrazione)
│   ├── Services/Scheduling/      # Pipeline scheduling (attiva)
│   ├── Models/                   # Bridge UI, NetworkModel, DTO
│   ├── Editor/ Scheduler/ Simulator/
│   ├── Infrastructure/           # Persistenza, I/O
│   ├── UI/                       # SwiftUI views
│   └── RailwayAIService/         # Backend AI / ottimizzazione cloud
├── FdC Railway ManagerTests/     # 20 unit test XCTest
├── Packages/
│   ├── FDCDomain/                # Swift Package — modelli Foundation
│   └── FDCScheduling/            # Swift Package — scaffold (non linkato)
└── docs/latex/                   # Documentazione tecnica modulare (LaTeX)
```

### Pipeline scheduling (attiva)

`ScheduleGenerationEngine` → `ScheduleOptimizationPipeline` (8 step):

1. Ottimizzazione partenze (shift greedy)
2. Refresh fisico orari (`ScheduleRefresher`)
3–5. Allineamento Taktfahrplan (`TaktEngine`)
6. Ottimizzazione AI cloud (`ScheduleAIResolver`)
7. Raffinamento genetico (`GeneticOptimizer`)
8. Verifica finale

Il legacy `RailwayScheduleOptimizer/` è stato **rimosso** (Fase 4).

### Domain/Model (tipi migrati)

`Node`, `Edge`, `Train`, `RelationStop`, `Vehicle`, `TrackSegment`,
`RoutingConstraint`, `RailwayTopology`, `Signal`, `Switch`,
`ElectrificationType`, `TrackControlPoint`, `TrainRoute`, `Ferrovia`,
`RailwayConstants`, `LineProfilePoint`, `TrainDatabaseModels`.

---

## Requisiti

- **Xcode** 16+ (Swift 5.9+, iOS 17+)
- **macOS** per build e test su simulatore
- Opzionale: **MacTeX** o `tectonic` per compilare `docs/latex/`

---

## Build e test

### App (Xcode)

```bash
open "FdC Railway Manager.xcodeproj"
```

Oppure da terminale:

```bash
xcodebuild build \
  -project "FdC Railway Manager.xcodeproj" \
  -scheme "FdC Railway Manager" \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M4)"
```

### Unit test (20 test)

```bash
xcodebuild test \
  -project "FdC Railway Manager.xcodeproj" \
  -scheme "FdC Railway Manager" \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M4)" \
  -only-testing:"FdC Railway ManagerTests" \
  -parallel-testing-enabled NO
```

### Swift Packages

```bash
swift build --package-path Packages/FDCDomain
swift test  --package-path Packages/FDCDomain
swift build --package-path Packages/FDCScheduling
```

---

## Documentazione

| Documento | Contenuto |
|-----------|-----------|
| [`CLAUDE.md`](CLAUDE.md) | Regole architetturali e convenzioni di codice |
| [`PLAN.md`](PLAN.md) | Piano refactor + traccia documentazione |
| [`docs/README.md`](docs/README.md) | Indice documentazione tecnica |
| [`docs/latex/`](docs/latex/) | Manuale modulare LaTeX (Domain, Scheduling, …) |
| [`FdC Railway Manager/RailwayAlgorithmDocs.md`](FdC%20Railway%20Manager/RailwayAlgorithmDocs.md) | Note storiche pipeline (pre-refactor) |

La documentazione LaTeX viene estesa **modulo per modulo** in
`docs/latex/modules/`.

---

## Convenzioni di sviluppo

- **Regola del 7** — complessità e variabili per funzione ≤ 7
- **80/24** — max 80 caratteri per riga, 24 righe per corpo funzione
- **CQS** — command/query separation
- **DI esplicita** — niente singleton nel domain; struct pure su `RailwayTopology`
- **Feature flags** — funzionalità sperimentali in `FeatureFlags.swift`
- **Test** — Arrange–Act–Assert; naming `test_<condizione>_<esito>`

Dettaglio completo in `CLAUDE.md`.

---

## Stato refactor (Fasi 0–5)

| Fase | Esito |
|------|-------|
| 0 | XCTest, test Taktfahrplan, FeatureFlags |
| 1 | Fix malloc, DI, migrazione Domain iniziale |
| 2 | `ScheduleOptimizationPipeline`, `TaktEngine` unificato |
| 3 | Vehicle/TrackSegment/RoutingConstraint, `ScheduleAIResolver` |
| 4 | Signal/Switch/ElectrificationType, rimozione legacy, SPM scaffold |
| 5 | `NetworkPathfinder`, UI decoupling (`*+UI.swift`), docs LaTeX |

### Prossimi passi (Fase 6+)

Vedi [`PLAN.md`](PLAN.md) per il dettaglio completo.

---

## Licenza

Consultare il proprietario del repository per i termini di utilizzo.
