# Piano Componenti UI — Editor Infrastruttura ("Ferrovia")

## Terminologia Aggiornata
- **Ferrovia** = percorso fisico dell'infrastruttura (ex "Relazione"). Struct `Ferrovia` al posto di `Relazione`.
- **Linea** = linea di servizio con orari e treni (resta `RailwayLine`).

---

## Componente 1: `FdCInspectorPanel` — Inspector Generalizzato

**Stato attuale:** `ContextualInspector` in `FloatingUIComponents.swift` (righe 193-484) e `InspectorWrapperView` (righe 2227-2269). Strettamente accoppiato con `appState`, logica di navigazione hardcoded.

**Obiettivo:** Un componente inspector riutilizzabile con navigazione a stack (push/pop pagine).

### Specifiche:
```
FdCInspectorPanel(title: "Titolo", onClose: { ... }) {
    // contenuto della pagina
}
```

### Struttura:
- **Header fisso:**
  - Freccia `←` (chevron.left) per tornare alla pagina precedente (visibile solo se c'è una pagina nello stack)
  - Titolo della pagina corrente (settabile da chi chiama)
  - Bottone `×` per chiudere l'inspector
- **Corpo:** `@ViewBuilder content` — spazio libero per il chiamante
- **Navigazione:** Stack interno con `push(title:content:)` e `pop()`. L'inspector mantiene uno stack di pagine. Ogni pagina ha un titolo e un contenuto.

### Comportamento:
- La `×` chiude sempre l'inspector (`appState.showPanel(.none)`)
- La `←` torna alla pagina precedente; se siamo alla root, deseleziona l'elemento corrente
- Non si chiude mai autonomamente (lasciamo il controllo al chiamante)

### File: `FdCInspectorPanel.swift` (nuovo)

---

## Componente 2: `FdCEntityList` — Lista Generalizzata

**Stato attuale:** Già esiste in `FdCEntityList.swift` (127 righe). Ha header, ricerca, row tap, context menu delete. Hardcoded per Node/Edge/RailwayLine nel `makeRow()`.

**Obiettivo:** Renderla pienamente generica con row customizzabile dall'esterno.

### Specifiche:
```swift
FdCEntityList(
    title: "Stazioni",
    items: stations,
    selectedItem: $selected,
    rowContent: { station in StationRow(station: station) },
    onAdd: { ... },
    onDelete: { station in ... },
    onDeleteAll: { ... }
)
```

### Miglioramenti:
- Rimuovere il `makeRow()` hardcoded → accettare un `@ViewBuilder rowContent: (Item) -> RowView`
- Mantenere: header con titolo, "+" e "svuota", ricerca automatica (>10 items)
- Mantenere: swipe-to-delete nativo, context menu, selezione
- Aggiungere: long-press per edit mode (già implementato in `ContextualInspector`)
- Aggiungere: badge count opzionale nell'header
- Rimuovere dipendenza da `@EnvironmentObject var network: NetworkModel`

### File: `FdCEntityList.swift` (refactor)

---

## Componente 3: `FdCToolbar` — Toolbar Icone Generalizzata

**Stato attuale:** Inline in `EditorModeView.swift` (righe 67-147). Capsule con `.ultraThinMaterial`, icone hardcoded.

**Obiettivo:** Componente riutilizzabile con icone configurabili + icone fisse standard.

### Specifiche:
```swift
FdCToolbar(
    items: [
        .button(icon: "building.2.fill", label: "Stazione", action: createStation),
        .button(icon: "tram.fill", label: "Binario", action: toggleTrack, isActive: isTrackMode),
        .divider,
        .button(icon: "list.bullet.rectangle", label: "Ferrovie", action: showList),
    ],
    mainViewRef: mapViewRef  // per export
)
```

### Struttura (da sinistra a destra):
1. **Sezione custom** — icone specifiche della view (configurabili)
2. **Divider**
3. **Sezione standard fissa:**
   - Undo (`arrow.uturn.backward`) — `appState.railroad.network.undo()`
   - Redo (`arrow.uturn.forward`) — `appState.railroad.network.redo()`
   - Divider
   - Export JPG (`photo`)
   - Export PDF (`doc.richtext`)
   - Stampa (`printer`)

### Stile:
- `.ultraThinMaterial` in Capsule (come attuale)
- Shadow
- Posizione: overlay top-center della main view (come attuale)

### File: `FdCToolbar.swift` (nuovo)

---

## Componente 4: `FdCBottomPanel` — Pannello Inferiore Generalizzato

**Stato attuale:** Il profilo altimetrico in `EditorModeView.swift` (righe 157-166) è inline, hardcoded con altezza fissa 300pt. Slide-up dal basso con ombra e bordi arrotondati.

**Obiettivo:** Un pannello bottom riutilizzabile che compare dal basso, con altezza configurabile ma **mai più di 1/3 della pagina**.

### Specifiche:
```swift
FdCBottomPanel(
    isPresented: $showProfile,
    title: "Profilo Altimetrico",
    preferredHeight: 280  // opzionale, default 250
) {
    AltimetricProfileView(...)
}
```

### Struttura:
- **Handle bar** in alto (pillola grigia per drag, stile sheet iOS)
- **Header opzionale:** titolo + bottone `×` per chiudere
- **Corpo:** `@ViewBuilder content` — spazio libero
- **Altezza:** configurabile con `preferredHeight`, MA con `maxHeight = geoHeight / 3` (mai più di 1/3)
- **Animazione:** slide-up con `.transition(.move(edge: .bottom))`, come l'attuale

### Stile:
- Background: `secondarySystemBackground`
- Corner radius top: 12pt
- Shadow: upward (come attuale)
- Divider sopra il pannello

### File: `FdCBottomPanel.swift` (nuovo)

---

## Componente 5: Rinominare "Relazione" → "Ferrovia"

### Modifiche:
| File | Cosa cambia |
|------|-------------|
| `Models.swift` | `struct Relazione` → `struct Ferrovia` |
| `NetworkModel.swift` | `relazioni: [Relazione]` → `ferrovie: [Ferrovia]` |
| `IOManager.swift` | campo DTO `relazioni` → `ferrovie` |
| `Models.swift (DTO)` | `var relazioni: [Relazione]?` → `var ferrovie: [Ferrovia]?` |
| `EditorModeView.swift` | `RelazioniListPopover` → integrazione con `FdCEntityList` |
| `EditorModeView.swift` | `selectedRelazioneId` → `selectedFerroviaId` |
| `EditorModeView.swift` | `createNewRelazione()` → `createNewFerrovia()` |
| UI text | "Relazioni Fisiche" → "Ferrovie", "Nuova Relazione" → "Nuova Ferrovia" |

---

## Ordine di Implementazione

### Fase 1 — Componenti base (da fare prima)
1. **`FdCEntityList` refactor** — Generalizzare con rowContent esterno
2. **`FdCInspectorPanel`** — Inspector con navigazione a stack
3. **`FdCToolbar`** — Toolbar generalizzata con undo/redo/export fissi
4. **`FdCBottomPanel`** — Pannello bottom generalizzato

### Fase 2 — Rinominare e integrare
5. **Rinominare Relazione → Ferrovia** ovunque
6. **Integrare** i nuovi componenti nell'EditorModeView

### Fase 3 — Polish
7. Rimuovere codice morto (debug prints, vecchi componenti duplicati)
8. Test e verifica build

---

## Note Architetturali
- I 4 componenti (`FdCInspectorPanel`, `FdCEntityList`, `FdCToolbar`, `FdCBottomPanel`) saranno **indipendenti da AppState** dove possibile, comunicando via binding e closure
- Ogni componente in un file dedicato
- Il prefisso **FdC** distingue i componenti standard del progetto
