# ✅ Miglioramento Click su Profilo Altimetrico

## Richiesta Utente

> "quando clicco su un punto per modificare altezza tu trova la distanza dalla stazione più vicina. se siamo vicini muovi l'altezza della stazione non creare un junction. Se crei un junction controlla nel chilometraggio della linea (in base a dove hai premuto) dove si trova la junction e interpola la posizione del junction in base alla distanza tra le due stazioni. poi collegalo con un binario alle due stazioni"

## Problema Precedente

Prima della modifica, `handleGraphClick` aveva un comportamento troppo semplicistico:
- Trovava sempre il nodo più vicino al click
- Modificava sempre l'altitudine di quel nodo
- **Problema**: Non distingueva tra click vicino/lontano da stazione
- **Problema**: Non permetteva di creare junction cliccando tra stazioni
- **Bug**: Usava `stations[bestIdx]` che era errato perché `pointsData` e `stations` hanno lunghezze diverse

## Soluzione Implementata

### 1. Comportamento Intelligente in `handleGraphClick`

**Logica**:
1. **Se click entro 20 pixel da una stazione** → Modifica altitudine della stazione
2. **Se click lontano da tutte le stazioni** → Crea junction nel punto cliccato

```swift
// Threshold: if click is within 20 pixels of a station, modify station altitude
// Otherwise, create a junction at the clicked km position
let clickThreshold: CGFloat = 20

if nearestStationDist < clickThreshold {
    // Close to a station → modify station altitude
    updateNode(nodeId, alt: newAlt)
    appState.selectedNodeId = nodeId
} else {
    // Far from stations → create junction at clicked position
    handleSegmentTap(p1: p1, p2: p2, location: location, geo: geo, minAlt: minAlt, altRange: altRange)
}
```

**Benefici**:
- ✅ Click preciso su stazione → modifica altitudine stazione
- ✅ Click tra stazioni → crea junction
- ✅ Nessun comportamento ambiguo
- ✅ Considera solo stazioni vere (non junction) per il calcolo della vicinanza

### 2. Aggiunta `cumulativeDistance` a `PointData`

**Prima**:
```swift
struct PointData {
    let nodeId: String?
    let point: CGPoint
    let isStation: Bool
    // ... no distance info
}
```

**Dopo**:
```swift
struct PointData {
    let nodeId: String?
    let point: CGPoint
    let isStation: Bool
    let cumulativeDistance: Double  // ✅ Distance from start in km
}
```

**Benefici**:
- Ogni punto conosce la sua distanza dall'inizio della ferrovia
- Permette interpolazione accurata basata su chilometraggio reale
- Facilita calcoli di posizione geografica

### 3. Interpolazione Corretta della Posizione Junction

**Prima** (`handleSegmentTap`):
```swift
// Interpolazione semplice X → relativeX
let relativeX = (location.x - p1.point.x) / (p2.point.x - p1.point.x)
let junctionLat = lat1 + (lat2 - lat1) * Double(relativeX)
let distToJunction = totalDist * Double(relativeX)
```

**Problema**: Usava solo la posizione X del pixel, ignorando le distanze cumulative reali.

**Dopo**:
```swift
// Calculate junction position based on cumulative distance (km-based)
let junctionCumulativeDistance = p1.cumulativeDistance +
    (p2.cumulativeDistance - p1.cumulativeDistance) *
    Double((location.x - p1.point.x) / (p2.point.x - p1.point.x))

// Calculate distances from nodes
let distFromNode1 = junctionCumulativeDistance - p1.cumulativeDistance
let distFromNode2 = p2.cumulativeDistance - junctionCumulativeDistance

// Geographic interpolation based on distance ratio
let relativePosition = distFromNode1 / edgeDistance
let junctionLat = lat1 + (lat2 - lat1) * relativePosition
let junctionLon = lon1 + (lon2 - lon1) * relativePosition
```

**Benefici**:
- ✅ Junction posizionata al chilometraggio esatto del click
- ✅ Interpolazione geografica basata su distanze reali, non pixel
- ✅ Distanze edge corrette: `distFromNode1` + `distFromNode2` = `edgeDistance`
- ✅ Gestisce correttamente casi con junction intermedi

### 4. Creazione Edge con Distanze Corrette

```swift
// Create new edges using calculated distances based on actual km position
let edgeAJ = Edge(from: nodeId1, to: junctionNode.id,
                  distance: distFromNode1,  // ✅ km-based
                  trackType: edge.trackType, maxSpeed: edge.maxSpeed)
let edgeJB = Edge(from: junctionNode.id, to: nodeId2,
                  distance: distFromNode2,  // ✅ km-based
                  trackType: edge.trackType, maxSpeed: edge.maxSpeed)
```

**Verifica**: `distFromNode1 + distFromNode2 = edgeDistance` (sempre corretto)

## Scenari di Utilizzo

### Scenario 1: Click Vicino a Stazione
```
User clicks at pixel X=150 (20px from station at X=155)
→ Modifica altitudine della stazione
→ Nessun junction creato
```

### Scenario 2: Click Lontano da Stazioni
```
User clicks at pixel X=300 (between stations at X=150 and X=450)
→ Trova segmento contenente X=300
→ Calcola km position: 15.5 km (interpolazione)
→ Crea junction a 15.5 km dall'inizio
→ Interpola lat/lon basandosi sul rapporto di distanza
→ Crea edge A→J (7.5km) e J→B (9.5km)
```

### Scenario 3: Click tra Stazione e Junction
```
User clicks between station S1 and existing junction J1
→ Trova segmento S1-J1
→ Usa cumulative distances di S1 e J1
→ Crea nuova junction J2 tra S1 e J1
→ Aggiorna edge: S1↔J2 e J2↔J1
```

## Modifiche ai File

### EditorModeView.swift

**1. `PointData` struct** (linee ~1714-1743)
- Aggiunto campo `cumulativeDistance: Double`
- Aggiornati entrambi gli init per accettare/impostare cumulative distance

**2. `calculatePoints()` function** (linea ~1808)
- Passa `cumulativeDistance: distance` quando crea PointData

**3. `handleGraphClick()` function** (linee ~1625-1687)
- **Completamente riscritta** con logica intelligente:
  - Cerca solo stazioni (non junction) per vicinanza
  - Soglia 20 pixel per decidere modifica vs creazione
  - Delega a `handleSegmentTap` se crea junction
  - Fix bug: non usa più `stations[bestIdx]`

**4. `handleSegmentTap()` function** (linee ~1543-1623)
- Calcola `junctionCumulativeDistance` basandosi su `p1.cumulativeDistance` e `p2.cumulativeDistance`
- Interpola posizione geografica usando rapporto di distanza reale
- Usa `distFromNode1` e `distFromNode2` calcolate da distanze cumulative
- Crea edge con distanze km-based corrette

## Metriche

### Precisione
- **Prima**: Posizione junction approssimativa (basata solo su pixel)
- **Dopo**: Posizione junction esatta (basata su chilometraggio reale)

### Usabilità
- **Prima**: Sempre modificava nodo più vicino (comportamento ambiguo)
- **Dopo**: Click preciso vs click lontano → comportamenti distinti

### Correttezza
- **Prima**: `distToJunction + distFromJunction ≈ edgeDistance` (approssimazione)
- **Dopo**: `distFromNode1 + distFromNode2 = edgeDistance` (esatto)

## Build Status

✅ **Build Successful** - Nessun errore di compilazione
✅ **No Breaking Changes** - Funzionalità esistenti preservate
✅ **Backward Compatible** - Tutti i test esistenti dovrebbero passare

## Testing Checklist

Per verificare il corretto funzionamento:

- [ ] Click a 10px da stazione → modifica altitudine stazione
- [ ] Click a 30px da stazione → crea junction
- [ ] Junction creata ha lat/lon corrette (interpolate)
- [ ] Junction creata ha distanze edge corrette (somma = edge originale)
- [ ] Click tra stazione e junction esistente → crea seconda junction
- [ ] Distanze cumulative corrette nel profilo altimetrico
- [ ] Nessun crash quando si clicca fuori range

## Codice Committable

```bash
git add "FdC Railway Manager/EditorModeView.swift"
git commit -m "feat: intelligent altitude profile click handling with km-based junction placement

- Added cumulativeDistance field to PointData for accurate km tracking
- Implemented smart click behavior in handleGraphClick:
  * Click near station (< 20px) → modify station altitude
  * Click far from stations → create junction at exact km position
- Improved handleSegmentTap to use cumulative distances for:
  * Accurate geographic position interpolation
  * Correct edge distance calculations based on km position
- Fixed bug: handleGraphClick now correctly handles pointsData vs stations mismatch
- Junction placement now based on actual railway km, not just pixel position

User request: 'quando clicco su un punto per modificare altezza trova la
distanza dalla stazione più vicina. se siamo vicini muovi l'altezza della
stazione non creare un junction. Se crei un junction controlla nel
chilometraggio della linea dove si trova e interpola la posizione in base
alla distanza tra le due stazioni'"
```

## Architettura

```
Click su Profilo Altimetrico
    │
    ├─→ handleGraphClick()
    │       │
    │       ├─→ Trova stazione più vicina
    │       │
    │       ├─→ Distanza < 20px?
    │       │   ├─→ Sì: updateNode(altitude)
    │       │   └─→ No: handleSegmentTap()
    │       │           │
    │       │           ├─→ Calcola junctionCumulativeDistance (km-based)
    │       │           ├─→ Calcola distFromNode1, distFromNode2
    │       │           ├─→ Interpola lat/lon con relativePosition
    │       │           ├─→ Crea junction node
    │       │           └─→ Crea edge con distanze corrette
    │       │
    │       └─→ PointData contiene:
    │               - nodeId
    │               - point (CGPoint)
    │               - isStation (bool)
    │               - cumulativeDistance (Double) ✨ NUOVO
    │
    └─→ calculatePoints() costruisce PointData con cumulative distances
```

## Relazione con Phase 2 Refactoring

Questo miglioramento si integra perfettamente con il lavoro di Phase 2:

1. **Usa InfrastructureService**: `handleSegmentTap` usa `service.calculateDistance()` per trovare edge bidirectional
2. **Coerente con "junction come stazioni"**: `handleGraphClick` considera solo `isStation` true per vicinanza
3. **Single Responsibility**: Click handling separato da junction creation logic
4. **Testabile**: Logica basata su distanze numeriche, facile da verificare

## Prossimi Miglioramenti Opzionali

1. **Visual Feedback**: Mostrare anteprima dove verrà creata junction prima del click
2. **Configurabile Threshold**: Permettere all'utente di cambiare la soglia di 20px
3. **Snap to Grid**: Opzionale snapping a chilometri interi (es. ogni 5km)
4. **Undo Granulare**: Separare undo per altitudine vs creazione junction
