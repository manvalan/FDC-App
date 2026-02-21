# Piano di Refactoring - Code That Fits in Your Head

## Analisi della Situazione Attuale

### Problemi Identificati

1. **Responsabilità Frammentate per l'Infrastruttura Fisica**
   - `NetworkModel`: contiene dati delle ferrovie (`ferrovie: [Ferrovia]`)
   - `InfrastructureManager`: gestisce solo segmentazione blocchi/segnali
   - `EditorModeView`: contiene logica BFS per calcolo distanze con junction nodes
   - `RailwayGraphManager`: gestisce percorsi e connessioni
   - **Problema**: la logica relativa alla ferrovia fisica è sparsa in 4+ moduli

2. **Rendering Duplicato e Inconsistente**
   - `SchematicRailwayView`: rendering schematico
   - `EditorModeView.AltimetricProfileView`: rendering profilo altimetrico
   - `RailwayMapView`: contiene 3 modalità diverse (schematic/infrastructure/scheduler)
   - `StationNodeView`, `IntermediatePointView`, `DraggablePointView`: componenti isolati
   - **Problema**: ogni vista ha la propria logica di rendering, difficile mantenere consistenza

3. **Accoppiamento Stretto**
   - Le View accedono direttamente a `appState.railroad.network`
   - Logica di business mescolata con logica di presentazione
   - Difficile testare in isolamento

4. **Carico Cognitivo Elevato**
   - File molto lunghi (RailwayMapView.swift: 2354 linee, EditorModeView.swift: 2376 linee)
   - Responsabilità non chiare: dove va aggiunta una nuova feature?
   - Codice duplicato per gestione junction nodes

## Soluzione Proposta

### 1. InfrastructureService - Modulo Unificato per Gestione Infrastruttura Fisica

```swift
// FdC Railway Manager/Services/InfrastructureService.swift

/// Servizio centralizzato per la gestione dell'infrastruttura ferroviaria fisica.
/// Responsabilità:
/// - Gestione ferrovie (Ferrovia) e loro proprietà
/// - Calcoli di distanza con gestione junction nodes
/// - Validazione topologia della rete
/// - Generazione segmenti e segnali
/// - Query su percorsi e connessioni
final class InfrastructureService {
    private let network: NetworkModel

    init(network: NetworkModel) {
        self.network = network
    }

    // MARK: - Ferrovia Management

    /// Crea una nuova ferrovia dalla selezione di stazioni
    func createFerrovia(name: String, stationIds: [String], color: String?) -> Result<Ferrovia, InfrastructureError>

    /// Valida che una sequenza di stazioni formi un percorso valido
    func validateFerroviaPath(_ stationIds: [String]) -> Result<Void, InfrastructureError>

    /// Ottiene tutte le proprietà calcolate di una ferrovia
    func getFerroviaProperties(_ ferroviaId: String) -> FerroviaProperties?

    // MARK: - Distance Calculations

    /// Calcola la distanza tra due nodi, gestendo junction nodes intermedi (BFS)
    func calculateDistance(from: String, to: String) -> Double?

    /// Calcola la distanza totale di un percorso
    func calculateTotalDistance(path: [String]) -> Double

    /// Trova il percorso tra due nodi (ritorna tutti i nodi, inclusi junction)
    func findPath(from: String, to: String) -> PathResult?

    // MARK: - Topology Queries

    /// Ottiene tutti i nodi connessi a un dato nodo
    func getConnectedNodes(nodeId: String, includingJunctions: Bool) -> [Node]

    /// Verifica se due nodi sono connessi direttamente o tramite junctions
    func areNodesConnected(_ node1: String, _ node2: String) -> Bool

    /// Trova tutti i percorsi possibili tra due nodi
    func findAllPaths(from: String, to: String, maxDepth: Int) -> [[String]]

    // MARK: - Segmentation & Signals

    /// Genera o aggiorna la segmentazione per tutti gli edge della rete
    func processNetworkSegmentation()

    /// Genera segmenti per un singolo edge
    func generateSegments(for edgeId: UUID) -> [TrackSegment]

    // MARK: - Validation

    /// Valida l'integrità della rete (no nodi orfani, edge validi, etc)
    func validateNetworkIntegrity() -> [ValidationIssue]
}

// MARK: - Supporting Types

struct FerroviaProperties {
    let id: String
    let name: String
    let totalDistance: Double
    let stationCount: Int
    let junctionCount: Int
    let altitudeProfile: [AltitudePoint]
    let segments: [FerroviaSegment]
}

struct PathResult {
    let nodes: [Node]  // Include stations AND junctions in order
    let totalDistance: Double
    let segments: [(from: String, to: String, distance: Double)]
}

struct AltitudePoint {
    let nodeId: String
    let distance: Double  // Cumulative from start
    let altitude: Double
    let isStation: Bool
}

struct FerroviaSegment {
    let fromNodeId: String
    let toNodeId: String
    let distance: Double
    let hasJunctions: Bool
}

enum InfrastructureError: Error {
    case invalidPath(reason: String)
    case nodeNotFound(id: String)
    case disconnectedNodes(from: String, to: String)
    case duplicateStations([String])
}

struct ValidationIssue {
    enum Severity { case error, warning, info }
    let severity: Severity
    let description: String
    let affectedNodes: [String]
    let affectedEdges: [UUID]
}
```

### 2. RailwayRenderer - Modulo Unificato per Rendering

```swift
// FdC Railway Manager/Rendering/RailwayRenderer.swift

/// Servizio centralizzato per il rendering dell'infrastruttura ferroviaria.
/// Responsabilità:
/// - Rendering consistente di nodi (stazioni, junction, hub)
/// - Rendering consistente di edge (binari)
/// - Gestione stili e colori
/// - Conversione coordinate per diversi contesti (map, altimetric profile, etc)
final class RailwayRenderer {

    // MARK: - Configuration

    struct RenderingContext {
        let bounds: MapBounds
        let canvasSize: CGSize
        let zoomLevel: CGFloat
        let mode: RenderMode
    }

    enum RenderMode {
        case schematic          // Vista schematica semplificata
        case infrastructure     // Dettagli tecnici (segmenti, segnali)
        case altimetricProfile  // Profilo altimetrico
        case scheduler          // Vista scheduler con timing
    }

    // MARK: - Node Rendering

    /// Genera la vista per un nodo (decide automaticamente station/junction/hub)
    func renderNode(_ node: Node, context: RenderingContext, style: NodeStyle) -> some View

    /// Rendering specifico per stazioni
    func renderStation(_ node: Node, context: RenderingContext, style: StationStyle) -> some View

    /// Rendering specifico per junction nodes
    func renderJunction(_ node: Node, context: RenderingContext, style: JunctionStyle) -> some View

    /// Rendering specifico per hub/interscambi
    func renderHub(_ node: Node, context: RenderingContext, style: HubStyle) -> some View

    // MARK: - Edge Rendering

    /// Genera la vista per un edge/binario
    func renderEdge(_ edge: Edge, context: RenderingContext, style: EdgeStyle) -> some View

    /// Genera percorso tra due nodi (gestisce junction intermedi)
    func renderPath(from: Node, to: Node, via junctions: [Node], context: RenderingContext) -> Path

    // MARK: - Complex Rendering

    /// Rendering completo ferrovia (tutti nodi ed edge)
    func renderFerrovia(_ ferrovia: Ferrovia, network: NetworkModel, context: RenderingContext) -> some View

    /// Rendering profilo altimetrico
    func renderAltimetricProfile(
        nodes: [Node],
        context: RenderingContext,
        interactive: Bool
    ) -> some View

    // MARK: - Coordinate Conversion

    /// Converte coordinate geografiche (lat/lon) in coordinate canvas
    func toCanvasCoordinates(lat: Double, lon: Double, context: RenderingContext) -> CGPoint

    /// Converte distanza chilometrica in pixel (per profilo altimetrico)
    func distanceToPixels(_ distance: Double, context: RenderingContext) -> CGFloat

    /// Converte altitudine in coordinata Y (per profilo altimetrico)
    func altitudeToY(_ altitude: Double, context: RenderingContext) -> CGFloat
}

// MARK: - Styles

struct NodeStyle {
    let fillColor: Color
    let strokeColor: Color
    let strokeWidth: CGFloat
    let size: CGFloat
    let showLabel: Bool
    let isHighlighted: Bool
    let isSelected: Bool
}

struct StationStyle {
    var base: NodeStyle
    let shape: StationShape
    let showTracks: Bool

    enum StationShape {
        case circle, square, diamond
    }
}

struct JunctionStyle {
    var base: NodeStyle
    let showInProfile: Bool

    static var standard: JunctionStyle {
        JunctionStyle(
            base: NodeStyle(
                fillColor: .black,
                strokeColor: .gray,
                strokeWidth: 1,
                size: 8,
                showLabel: false,
                isHighlighted: false,
                isSelected: false
            ),
            showInProfile: true
        )
    }
}

struct HubStyle {
    var base: NodeStyle
    let showConnectionLines: Bool
}

struct EdgeStyle {
    let strokeColor: Color
    let strokeWidth: CGFloat
    let lineStyle: LineStyle
    let showDirection: Bool
    let showSegments: Bool
    let isHighlighted: Bool

    enum LineStyle {
        case solid, dashed, dotted
    }
}
```

### 3. Refactoring delle View Esistenti

#### EditorModeView - Semplificato

```swift
// Prima: 2376 linee con logica BFS, rendering, calcoli
// Dopo: ~800 linee, delega a InfrastructureService e RailwayRenderer

struct EditorModeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loader: AppLoaderService

    // Services
    private var infrastructureService: InfrastructureService {
        InfrastructureService(network: appState.railroad.network)
    }
    private let renderer = RailwayRenderer()

    var body: some View {
        VStack {
            // Inspector panel
            inspectorPanel

            // Main content: delegato a sottocomponenti
            if let ferroviaId = appState.selectedFerroviaId {
                FerroviaEditorView(
                    ferroviaId: ferroviaId,
                    service: infrastructureService,
                    renderer: renderer
                )
            } else {
                EmptySelectionView()
            }
        }
    }
}

// Componente separato per editing ferrovia
struct FerroviaEditorView: View {
    let ferroviaId: String
    let service: InfrastructureService
    let renderer: RailwayRenderer

    var body: some View {
        // Profilo altimetrico usando renderer
        AltimetricProfileRenderer(
            ferroviaId: ferroviaId,
            service: service,
            renderer: renderer
        )
    }
}
```

#### RailwayMapView - Semplificato

```swift
// Prima: 2354 linee con rendering inline
// Dopo: ~600 linee, rendering delegato a RailwayRenderer

struct RailwayMapView: View {
    @EnvironmentObject var appState: AppState
    private let renderer = RailwayRenderer()

    var body: some View {
        GeometryReader { geo in
            let context = RailwayRenderer.RenderingContext(
                bounds: mapBounds,
                canvasSize: geo.size,
                zoomLevel: zoomLevel,
                mode: mode
            )

            ZStack {
                // Grid
                if showGrid {
                    GridRenderer(context: context)
                }

                // Edges (usando renderer)
                ForEach(network.edges) { edge in
                    renderer.renderEdge(edge, context: context, style: edgeStyle(for: edge))
                }

                // Nodes (usando renderer)
                ForEach(network.nodes) { node in
                    renderer.renderNode(node, context: context, style: nodeStyle(for: node))
                }
            }
        }
    }

    private func nodeStyle(for node: Node) -> NodeStyle {
        // Logica centralizzata per determinare lo stile
    }
}
```

### 4. Altri Miglioramenti Architetturali

#### 4.1 Separation of Concerns

```swift
// Services layer
Services/
├── InfrastructureService.swift      // Gestione infrastruttura fisica
├── RailwayRenderer.swift             // Rendering unificato
├── ValidationService.swift           // Validazione regole ferroviarie
└── CalculationService.swift          // Calcoli complessi (pendenze, curve, etc)

// Domain Models
Models/
├── Infrastructure/
│   ├── Ferrovia.swift
│   ├── Node.swift
│   ├── Edge.swift
│   └── TrackSegment.swift
└── Operations/
    ├── RailwayLine.swift
    └── Train.swift

// Views - solo presentazione
Views/
├── Map/
│   ├── RailwayMapView.swift         // Orchestrazione
│   ├── GridRenderer.swift            // Componente riutilizzabile
│   └── Styles/                       // Stili e temi
├── Editor/
│   ├── EditorModeView.swift         // Orchestrazione
│   ├── FerroviaEditorView.swift    // Editor specifico
│   └── AltimetricProfileRenderer.swift
└── Components/                       // Componenti riutilizzabili
    ├── StationNodeView.swift
    ├── JunctionNodeView.swift
    └── EdgePathView.swift
```

#### 4.2 Dependency Injection

```swift
// AppState dovrebbe iniettare servizi invece di essere acceduto direttamente

@main
struct FdC_Railway_ManagerApp: App {
    @StateObject private var appState = AppState()

    // Services
    @StateObject private var infrastructureService: InfrastructureService
    @StateObject private var renderer: RailwayRenderer

    init() {
        let network = appState.railroad.network
        _infrastructureService = StateObject(wrappedValue: InfrastructureService(network: network))
        _renderer = StateObject(wrappedValue: RailwayRenderer())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(infrastructureService)
                .environmentObject(renderer)
        }
    }
}
```

#### 4.3 Testability

```swift
// Con servizi separati, possiamo testare in isolamento

class InfrastructureServiceTests: XCTestCase {
    func testDistanceCalculationWithJunctions() {
        let network = createTestNetwork()
        let service = InfrastructureService(network: network)

        let distance = service.calculateDistance(from: "A", to: "B")

        XCTAssertEqual(distance, 150.0, accuracy: 0.1)
    }

    func testFerroviaValidation() {
        let network = createTestNetwork()
        let service = InfrastructureService(network: network)

        let result = service.validateFerroviaPath(["A", "J1", "B"]) // J1 is junction

        XCTAssertTrue(result.isSuccess)
    }
}
```

#### 4.4 Protocol-Oriented Design

```swift
// Interfacce invece di implementazioni concrete

protocol InfrastructureProviding {
    func calculateDistance(from: String, to: String) -> Double?
    func findPath(from: String, to: String) -> PathResult?
    func validateFerroviaPath(_ stationIds: [String]) -> Result<Void, InfrastructureError>
}

protocol RailwayRendering {
    func renderNode(_ node: Node, context: RenderingContext, style: NodeStyle) -> AnyView
    func renderEdge(_ edge: Edge, context: RenderingContext, style: EdgeStyle) -> AnyView
}

// Le view dipendono da protocol, non da implementazioni
struct FerroviaEditorView: View {
    let ferroviaId: String
    let infrastructure: InfrastructureProviding  // Protocol, non classe concreta
    let renderer: RailwayRendering

    // Ora possiamo iniettare mock per testing
}
```

## Piano di Implementazione

### Fase 1: Creazione Servizi (Non Breaking)
1. Creare `InfrastructureService` con tutte le funzioni necessarie
2. Creare `RailwayRenderer` con rendering base
3. Mantenere codice esistente funzionante

### Fase 2: Migrazione Graduale
1. Migrare `EditorModeView` per usare `InfrastructureService`
   - Sostituire BFS inline con `service.calculateDistance()`
   - Sostituire logica percorsi con `service.findPath()`
2. Migrare rendering in `EditorModeView` a `RailwayRenderer`
3. Testare che tutto funzioni come prima

### Fase 3: Refactoring Completo
1. Migrare `RailwayMapView`
2. Estrarre componenti riutilizzabili
3. Rimuovere codice duplicato

### Fase 4: Testing & Documentazione
1. Aggiungere unit test per servizi
2. Documentare API dei servizi
3. Creare esempi d'uso

## Benefici Attesi

### Riduzione Complessità
- File < 500 linee (target)
- Singola responsabilità per ogni modulo
- Facile capire dove aggiungere nuove feature

### Riusabilità
- Stesso rendering per mappa, editor, export
- Stessi calcoli per tutte le view
- Componenti testabili in isolamento

### Manutenibilità
- Bug fix in un posto solo
- Modifiche isolate (es: cambiare stile junction non tocca logica)
- Facile aggiungere nuovi tipi di nodi

### Testabilità
- Servizi testabili senza UI
- Mock per testing view
- Validazione automatica

## Note Implementative

### Gestione Junction Nodes
Tutto il codice BFS per junction nodes sarà in `InfrastructureService`:

```swift
// Prima: duplicato in EditorModeView, RailwayMapView, etc
// Dopo: un'unica implementazione
service.calculateDistance(from: "A", to: "B")  // Gestisce junction automaticamente
service.findPath(from: "A", to: "B")           // Ritorna tutti nodi, inclusi junction
```

### Rendering Consistente
Tutti i junction nodes saranno renderizzati allo stesso modo:

```swift
// Prima: cerchietti hardcoded in varie view
// Dopo: style centralizzato
renderer.renderJunction(node, context: context, style: .standard)
```

### Migrazione Incrementale
Ogni fase può essere committata separatamente, mantenendo sempre l'app funzionante.
