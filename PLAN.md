# Piano refactor FDC-App

Refactor incrementale (*Strangler pattern*) verso **Functional Core,
Imperative Shell**, con documentazione LaTeX estesa modulo per modulo.

Legenda: ✅ completato · 🔄 in corso · 🔲 pianificato

---

## Traccia documentazione (parallela)

| Artefatto | Percorso | Stato |
|-----------|----------|-------|
| README repository | `README.md` | ✅ v0.1 |
| Indice docs | `docs/README.md` | ✅ v0.1 |
| Manuale LaTeX | `docs/latex/` | 🔄 v0.1 → v0.2 |
| Regole codice | `CLAUDE.md` | ✅ (pre-esistente) |

### Capitoli LaTeX

| # | Capitolo | File | Stato |
|---|----------|------|-------|
| 0 | Prefazione | `modules/00-prefazione.tex` | ✅ |
| 1 | Architettura | `modules/01-architettura.tex` | ✅ |
| 2 | FDCDomain | `modules/02-fdcdomain.tex` | 🔄 |
| 3 | FDCScheduling | `modules/03-fdcscheduling.tex` | ✅ |
| 4 | Pathfinding | `modules/04-pathfinding.tex` | 🔄 Fase 5 |
| 5 | Editor | `modules/05-editor.tex` | 🔲 |
| 6 | Simulator | `modules/06-simulator.tex` | 🔲 |
| 7 | RailwayAI | `modules/07-railway-ai.tex` | 🔲 |
| 8 | Infrastructure | `modules/08-infrastructure.tex` | ✅ Fase 9 |

Ogni fase di codice aggiorna il capitolo LaTeX corrispondente.

---

## Fasi refactor

### Fase 0 — Fondamenta ✅ `0c18744`

- [x] Target XCTest (`FdC Railway ManagerTests`)
- [x] Test Taktfahrplan 120 min
- [x] `FeatureFlags.swift`

### Fase 1 — Domain + DI ✅ `0c18744`

- [x] Servizi scheduling: `class` → `struct` su `RailwayTopology`
- [x] Fix malloc crash test host
- [x] Migrazione iniziale: `Node`, `Edge`, `Train`, `RelationStop`
- [x] `TaktEngine` unificato

### Fase 2 — Pipeline nuova ✅ `0c18744`

- [x] `ScheduleOptimizationPipeline` (8 step)
- [x] `RailwayTopology` come snapshot immutabile
- [x] Disattivazione pipeline legacy (flag)

### Fase 3 — Domain esteso + AI ✅ `729f042`

- [x] `Vehicle`, `TrackSegment`, `RoutingConstraint`
- [x] `ScheduleAIResolver`
- [x] `ScheduleRefresher` (sostituisce legacy helpers)

### Fase 4 — Rimozione legacy + SPM ✅ `00db4c2`

- [x] `Signal`, `Switch`, `ElectrificationType`, `TrackControlPoint` → Domain
- [x] Rimosso `RailwayScheduleOptimizer/`
- [x] Scaffold `Packages/FDCDomain`, `Packages/FDCScheduling`
- [x] README + LaTeX v0.1

### Fase 5 — Decoupling UI e pathfinding ✅

- [x] `displayColor` → `Models/TrainRoute+UI.swift`, `Models/RailwayLine+UI.swift`
- [x] `NetworkPathfinder` in `Domain/Pathfinding/`
- [x] `RailwayTopology` senza `init(network: NetworkModel)`
- [x] Capitolo LaTeX `04-pathfinding.tex`
- [x] `PathfindingTests` (2 test)
- [x] `PLAN.md` + README aggiornati

### Fase 6 — SPM integrato ✅

- [x] `Node+UI`, split `TrainDatabase` (Foundation / Infrastructure / UI)
- [x] `FDCDomain` package completo (18 sorgenti)
- [x] Package collegato al target Xcode + `DomainBridge` (`@_exported import`)
- [x] Membership exceptions (no doppia compilazione Domain)
- [x] 3 test FDCDomain SPM + build app OK
- [x] Capitolo LaTeX `05-spm-integration.tex`

### Fase 7 — NetworkModel → adapter ✅

- [x] `NetworkModel` resta shell `@Observable` per UI
- [x] Logica query topologia via `NetworkTopologyService` (Domain)
- [x] `TrainCategory` in Domain; `TrainCategory+UI` in Models
- [x] `RailwayNetworkDTO` in Infrastructure
- [x] `DomainBridge` ridotto: `@_exported import` + disambiguazione `Edge`
- [x] Capitolo LaTeX `06-network-adapter.tex`

### Fase 8 — FDCScheduling package ✅

- [x] Protocolli in `Domain/Services/` (Conflict, GA, AI, TravelTime)
- [x] `ScheduleConflict` in Domain; `ScheduleConflict+UI` in app
- [x] 7 sorgenti scheduling in `Packages/FDCScheduling` + symlink
- [x] `FDCScheduling` linkato a Xcode + `SchedulingBridge`
- [x] Adapter app (`AppSchedulingAdapters.swift`)
- [x] Capitolo LaTeX `07-scheduling-package.tex`

### Fase 9 — Visualizzazione hub AV/classico ✅

- [x] `HubTopology` in Domain: regole endpoint binari + offset 8 posizioni
- [x] `HubOffsetDirection` esteso (vertici + metà lati)
- [x] Rendering: due pallini rossi + linea a 8 (`drawHubPair`)
- [x] Binari AV tra satelliti; classici tra parent (`RailroadNetwork.addEdge`)
- [x] Editor: creazione satellite AV da inspector
- [x] Test FDCDomain `HubTopology`
- [x] Capitolo LaTeX `08-infrastructure.tex`

---

## Metriche attuali

| Metrica | Valore |
|---------|--------|
| Test app XCTest | 24 |
| Test FDCDomain SPM | 8 |
| Test FDCScheduling SPM | 4 |
| Package SPM attivi | `FDCDomain`, `FDCScheduling` |
| Legacy `RailwayScheduleOptimizer` | rimosso |
| Pipeline attiva | `ScheduleOptimizationPipeline` |

---

## Commit di riferimento

| Commit | Fase |
|--------|------|
| `0c18744` | 0–2 |
| `729f042` | 3 |
| `00db4c2` | 4 |

---

## Prossima azione

Refactor completato (Fasi 0–9). Eventuali estensioni: Editor, Simulator, RailwayAI in package dedicati.
