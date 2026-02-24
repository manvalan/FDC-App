# ✅ Network Lists Refactoring - Architettura Modulare

## User Request

> "si può unificare la gestione della lista stazioni (poi anche di Binari e Ferrovia) un modulo ed un componente ognuno che ereditano la medesima lista UI?"

## Obiettivo

Creare un'architettura modulare dove:
1. **ViewModels separati** gestiscono la logica di business per ciascun tipo di entità
2. **Componente UI riutilizzabile** (`FdCEntityList`) condiviso da tutte le liste
3. **Simboli centralizzati** in un unico modulo per consistenza visuale

## Implementazione

### 1. Nuovo File: NetworkListViewModels.swift

Contiene tre ViewModels e un modulo per i simboli:

#### A. StationListViewModel
Gestisce la logica delle stazioni:
- `items`: Array di stazioni ordinate
- `searchText(for:)`: Testo ricercabile per ogni stazione
- `onSelect()`: Selezione stazione + apertura inspector
- `onAdd()`: Creazione nuova stazione
- `onDelete()`: Rimozione stazione + cleanup
- `onDeleteAll()`: Rimozione totale + cleanup edges

#### B. TrackListViewModel
Gestisce la logica dei binari:
- `items`: Array di binari ordinati
- `searchText(for:)`: Nome stazioni "Da → A"
- `onSelect()`: Selezione binario + apertura inspector
- `onAdd()`: Avvio modalità creazione binario
- `onDelete()`: Rimozione binario
- `onDeleteAll()`: Rimozione totale binari

#### C. FerroviaListViewModel
Gestisce la logica delle ferrovie:
- `items`: Array di ferrovie
- `searchText(for:)`: Nome ferrovia
- `onSelect()`: Selezione ferrovia + highlight stazioni sulla mappa + clear altre selezioni
- `onAdd()`: Placeholder (richiede multi-selezione)
- `onDelete()`: Rimozione ferrovia
- `onDeleteAll()`: Rimozione totale ferrovie

#### D. NetworkSymbols
Modulo statico con funzioni per rendering simboli:
- `stationSymbol(for:size:)`: Simboli stazioni (cerchio/quadrato/stella/doppio cerchio)
- `trackSymbol(for:width:height:)`: Simboli binari (single/double/regional/highSpeed)
- `ferroviaSymbol(color:size:)`: Simbolo colore ferrovia

### 2. NetworkListView.swift Refactored

**Prima** (~260 linee con logica duplicata):
```swift
private var stationsListView: some View {
    FdCEntityList(
        // ... 50 linee di logica inline
        onSelect: { station in
            selectedNode = station
            appState.showPanel(.inspector)
        },
        onAdd: {
            let newStation = Node(...)
            network.nodes.append(newStation)
            selectedNode = newStation
            network.createCheckpoint()
            appState.showPanel(.inspector)
        },
        // ... più logica
    )
}
```

**Dopo** (~156 linee, logica nei ViewModels):
```swift
// ViewModels as computed properties
private var stationVM: StationListViewModel {
    StationListViewModel(network: network, appState: appState, selectedNode: $selectedNode)
}

private var stationsListView: some View {
    FdCEntityList(
        title: String(format: "stations_count".localized, stationVM.items.count),
        items: stationVM.items,
        rowContent: { node in
            HStack {
                NetworkSymbols.stationSymbol(for: node, size: 12)
                Text(node.name ?? node.id)
                // ...
            }
        },
        searchText: stationVM.searchText,
        onSelect: stationVM.onSelect,
        onAdd: stationVM.onAdd,
        onDelete: stationVM.onDelete,
        onDeleteAll: stationVM.onDeleteAll
    )
}
```

## Benefici

### 1. Separazione delle Responsabilità
- **NetworkListView**: Solo rendering e coordinamento
- **ViewModels**: Logica di business isolata
- **NetworkSymbols**: Rendering simboli centralizzato

### 2. Riusabilità
- `FdCEntityList` usato da tutte e 3 le liste
- `NetworkSymbols` riutilizzabile in altre viste (già usato in ScheduleCreationView e FloatingUIComponents)
- ViewModels facilmente testabili in isolamento

### 3. Manutenibilità
- Modifica logica stazioni: solo `StationListViewModel`
- Modifica simboli: solo `NetworkSymbols`
- Aggiungere nuova lista: creare nuovo ViewModel + 10 righe in NetworkListView

### 4. Consistenza Visuale
- Simboli identici in tutte le viste dell'app
- Single source of truth per rendering

### 5. Riduzione Codice
- **NetworkListView.swift**: da ~260 linee a ~156 linee (-40%)
- Logica duplicata eliminata
- Funzioni helper duplicate rimosse

## Architettura

```
┌─────────────────────────────────────────────────────────────┐
│                   NetworkListView.swift                      │
│                   (Coordinamento UI)                         │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ stationsView │  │ tracksView   │  │ ferrovieView │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │               │
│         └──────────────────┴──────────────────┘               │
│                            │                                  │
│                    FdCEntityList (shared)                     │
└────────────────────────────┼─────────────────────────────────┘
                             │
        ┌────────────────────┴────────────────────┐
        │                                          │
┌───────▼──────────────────┐          ┌───────────▼──────────┐
│ NetworkListViewModels    │          │  NetworkSymbols      │
│                          │          │                      │
│ ┌──────────────────────┐│          │ stationSymbol()      │
│ │ StationListViewModel ││          │ trackSymbol()        │
│ │  - items             ││          │ ferroviaSymbol()     │
│ │  - searchText()      ││          │                      │
│ │  - onSelect()        ││          └──────────────────────┘
│ │  - onAdd()           ││                     │
│ │  - onDelete()        ││                     │
│ └──────────────────────┘│          ┌──────────▼───────────┐
│                          │          │ Used by:             │
│ ┌──────────────────────┐│          │ - NetworkListView    │
│ │ TrackListViewModel   ││          │ - ScheduleCreation   │
│ │  - items             ││          │ - FloatingUIComp.    │
│ │  - searchText()      ││          └──────────────────────┘
│ │  - onSelect()        ││
│ │  - onAdd()           ││
│ │  - onDelete()        ││
│ └──────────────────────┘│
│                          │
│ ┌──────────────────────┐│
│ │ FerroviaListViewModel││
│ │  - items             ││
│ │  - searchText()      ││
│ │  - onSelect()        ││
│ │  - onAdd()           ││
│ │  - onDelete()        ││
│ └──────────────────────┘│
└──────────────────────────┘
```

## Simboli Implementati

### Stazioni
1. **Interchange** (priorità): Doppio cerchio rosso ⭕⭕
2. **Filled Circle**: Cerchio pieno (colore personalizzato)
3. **Empty Circle**: Cerchio vuoto (colore personalizzato)
4. **Filled Square**: Quadrato pieno (colore personalizzato) - Hub Taktfahrplan
5. **Empty Square**: Quadrato vuoto (colore personalizzato) - IC/Intercity
6. **Filled Star**: Stella piena (colore personalizzato) - Stazioni speciali

### Binari
1. **Single**: Linea singola grigia ─
2. **Double**: Due linee parallele grigie ═
3. **Regional**: Linea arancione con puntini ─●─
4. **High Speed**: Linea spessa rossa ━

### Ferrovie
- Quadrato colorato con il colore della ferrovia (hex → SwiftUI Color)

## File Modificati

### Creati
1. **NetworkListViewModels.swift** (7193 bytes)
   - StationListViewModel (60 righe)
   - TrackListViewModel (50 righe)
   - FerroviaListViewModel (50 righe)
   - NetworkSymbols (100 righe)

### Modificati
2. **NetworkListView.swift**
   - Prima: ~8550 bytes, ~260 righe
   - Dopo: ~5576 bytes, ~156 righe
   - Riduzione: **-35% linee, -35% bytes**

### Già Esistente (riutilizzato)
3. **FdCEntityList.swift** - Nessuna modifica necessaria!

## Testing Checklist

- [x] Build successful
- [ ] Lista Stazioni: Mostra simboli corretti
- [ ] Lista Binari: Mostra simboli binari stilizzati
- [ ] Lista Ferrovie: Mostra colore ferrovia
- [ ] Selezione stazione: Apre inspector
- [ ] Selezione binario: Apre inspector
- [ ] Selezione ferrovia: Evidenzia stazioni sulla mappa
- [ ] Add stazione: Crea nuova stazione
- [ ] Add binario: Avvia modalità creazione
- [ ] Delete stazione: Rimuove + cleanup
- [ ] Delete binario: Rimuove
- [ ] Delete ferrovia: Rimuove
- [ ] Delete All: Funziona per tutte le liste
- [ ] Search: Filtra correttamente

## Prossimi Passi (Opzionali)

### 1. Estendere a LinesListView
Applicare lo stesso pattern alle liste linee ferroviarie:
- Creare `LineListViewModel`
- Aggiungere `NetworkSymbols.lineSymbol()`

### 2. Aggiungere Unit Tests
```swift
func testStationViewModelOnAdd() {
    let vm = StationListViewModel(...)
    let initialCount = vm.items.count
    vm.onAdd()
    XCTAssertEqual(vm.items.count, initialCount + 1)
}
```

### 3. Protocol-Based Architecture
Creare un protocollo comune per i ViewModels:
```swift
protocol EntityListViewModel {
    associatedtype Item: Identifiable & Hashable
    var items: [Item] { get }
    func searchText(for item: Item) -> String
    func onSelect(_ item: Item)
    func onAdd()
    func onDelete(_ item: Item)
    func onDeleteAll()
}
```

### 4. Symbol Presets
Definire preset di simboli per casi comuni:
```swift
extension NetworkSymbols {
    static let standardStation = stationSymbol(visualType: .filledCircle, color: .blue)
    static let hubStation = stationSymbol(visualType: .filledSquare, color: .orange)
}
```

## Code Committable

```bash
git add "FdC Railway Manager/NetworkListViewModels.swift"
git add "FdC Railway Manager/NetworkListView.swift"
git commit -m "refactor: unify network lists with modular architecture

- Created NetworkListViewModels.swift with dedicated ViewModels:
  * StationListViewModel: stations business logic
  * TrackListViewModel: tracks business logic
  * FerroviaListViewModel: ferrovie business logic
  * NetworkSymbols: centralized symbol rendering

- Refactored NetworkListView.swift:
  * Removed duplicate helper functions (stationSymbol, trackSymbol)
  * Extracted business logic to ViewModels
  * Reduced code from ~260 to ~156 lines (-40%)
  * All three lists now use shared FdCEntityList component

- Benefits:
  * Single Responsibility: View only coordinates, ViewModels handle logic
  * Reusability: NetworkSymbols used across app (3+ files)
  * Maintainability: Logic changes isolated to ViewModels
  * Consistency: Same symbols everywhere in the app

User request: 'si può unificare la gestione della lista stazioni (poi
anche di Binari e Ferrovia) un modulo ed un componente ognuno che
ereditano la medesima lista UI?'

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

## Conclusione

L'architettura è ora modulare e scalabile:
- ✅ **3 ViewModels** gestiscono logica separata
- ✅ **1 Componente UI** riutilizzato 3 volte
- ✅ **1 Modulo Simboli** centralizzato
- ✅ **-40% codice** in NetworkListView
- ✅ **Build successful**

Aggiungere una nuova lista richiede ora solo:
1. Creare ViewModel (50 righe)
2. Aggiungere vista in NetworkListView (20 righe)
3. Totale: **~70 righe** invece di 200+
