import Foundation
import Combine
import SwiftUI

struct FdCTheme: Equatable {
    var background: Color = Color(hex: "#F2F5F8")! // Default App Background
    var surface: Color = Color(hex: "#FFFFFF")!    // Card Surface
    var light: Color = Color(hex: "#E5E7EB")!      // Subtle Dividers / Unselected background
    var medium: Color = Color(hex: "#9CA3AF")!     // Secondary icons / text

    var dark: Color = Color(hex: "#4B5563")!       // Primary content / Sidebar labels
    var accent: Color = Color.blue                 // Selected items
    var line: Color = Color(hex: "#111827")!       // Graph Lines / Very dark accents
    var backgroundSecondary: Color = Color(hex: "#E5E7EB")! // Slightly darker/lighter background for contrast
    
    static let light = FdCTheme(
        background: Color(hex: "#F2F5F8")!,
        surface: Color(hex: "#FFFFFF")!,
        light: Color(hex: "#E5E7EB")!,
        medium: Color(hex: "#9CA3AF")!,
        dark: Color(hex: "#4B5563")!,
        accent: Color.blue,
        line: Color(hex: "#111827")!,
        backgroundSecondary: Color(hex: "#E5E7EB")!
    )
    
    static let dark = FdCTheme(
        background: Color(hex: "#1F2937")!,
        surface: Color(hex: "#374151")!,
        light: Color(hex: "#4B5563")!,
        medium: Color(hex: "#9CA3AF")!,
        dark: Color(hex: "#E5E7EB")!,
        accent: Color.blue,
        line: Color(hex: "#F9FAFB")!,
        backgroundSecondary: Color(hex: "#111827")!
    )
    
    static func == (lhs: FdCTheme, rhs: FdCTheme) -> Bool {
        // Simple comparison based on background color
        lhs.background == rhs.background && lhs.surface == rhs.surface
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var theme = FdCTheme()
    @Published var showAI: Bool = false
    var aiNetwork: NetworkModel? = nil
    @Published var didAutoImport: Bool = false
    @Published var importMessage: String? = nil
    @Published var simulator = FDCSimulator()
    @Published var liveSim = LiveSimulationManager()
    private var cancellables = Set<AnyCancellable>()
    
    // Navigation State (Global)
    @Published var sidebarSelection: SidebarItem? = .lines {
        didSet {
            updateMapVisualizationMode()
        }
    }
    @Published var jumpToTrainId: UUID? = nil
    
    // UI Panels Management (Single Source of Truth)
    enum ActivePanel {
        case none, sidebar, inspector, modeBar
    }
    @Published var activePanel: ActivePanel = .none
    
    enum LineInspectorMode: String, CaseIterable, Identifiable {
        case infrastructure = "Infrastruttura"
        case schedule = "Orario"
        case vehicles = "Mezzi"
        var id: String { self.rawValue }
    }
    @Published var lineInspectorMode: LineInspectorMode = .infrastructure
    
    // Convenience Accessors
    var isSideMenuVisible: Bool { activePanel == .sidebar }
    var isInspectorVisible: Bool { activePanel == .inspector }
    var isModeBarVisible: Bool { activePanel == .modeBar }
    
    func showPanel(_ panel: ActivePanel) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            activePanel = panel
        }
    }
    
    func togglePanel(_ panel: ActivePanel) {
        showPanel(activePanel == panel ? .none : panel)
    }
    
    // New Minimalist Navigation State
    @Published var currentMode: AppMode = .design
    @Published var mapVisualizationMode: RailwayMapView.MapVisualizationMode = .schematic
    
    // Selection State (Global)
    @Published var selectedLineId: String? = nil { 
        didSet { 
            updateInspectorVisibilityForSelection()
            updateMapVisualizationMode()
        }
    }
    @Published var selectedNodeId: String? = nil { 
        didSet { 
            if let id = selectedNodeId {
                // Sync with set if not in multi-select mode? 
                // Or just independent?
                if !isMultiSelectMode {
                    selectedNodeIds = [id]
                }
            } else if !isMultiSelectMode {
                selectedNodeIds = []
            }
            updateInspectorVisibilityForSelection() 
        }
    }
    
    // Multi-Selection Support
    @Published var isMultiSelectMode: Bool = false
    @Published var selectedNodeIds: Set<String> = []
    @Published var selectedNodeIdsOrder: [String] = []
    
    func toggleNodeSelection(_ id: String) {
        if selectedNodeIds.contains(id) {
            selectedNodeIds.remove(id)
            selectedNodeIdsOrder.removeAll(where: { $0 == id })
        } else {
            selectedNodeIds.insert(id)
            selectedNodeIdsOrder.append(id)
        }
        
        // If we are in single selection mode via toggle (shift-click?), we might want to update selectedNodeId
        if selectedNodeIds.count == 1 {
            selectedNodeId = selectedNodeIds.first
        } else if selectedNodeIds.isEmpty {
            selectedNodeId = nil
        } else {
            // Multiple selected: Clear single selection to avoid confusion or keep primary?
            // Let's keep primary as the LAST added?
            // selectedNodeId = id // This might trigger single inspector logic. 
            // Better to have specific MultiSelectInspector.
            selectedNodeId = nil 
        }
    }

    @Published var selectedEdgeId: String? = nil { 
        didSet { updateInspectorVisibilityForSelection() }
    }
    
    @Published var selectedFerroviaId: String? = nil {
        didSet { updateInspectorVisibilityForSelection() }
    }
    
    var selectedFerrovia: Ferrovia? {
        guard let id = selectedFerroviaId else { return nil }
        return railroad.network.ferrovie.first(where: { $0.id == id })
    }
    @Published var selectedTrainIds: Set<UUID> = [] { 
        didSet { updateInspectorVisibilityForSelection() }
    }
    @Published var selectedVehicleId: UUID? = nil {
        didSet { updateInspectorVisibilityForSelection() }
    }
    @Published var isShowingSettings: Bool = false {
        didSet { updateInspectorVisibilityForSelection() }
    }
    @Published var isInspectorEditingMode: Bool = false
    @Published var lastVehicleAssignmentLineId: String? = nil
    @Published var isLineEditing: Bool = false
    @Published var isScheduleGeneratorVisible: Bool = false
    @Published var isVehicleManagementVisible: Bool = false
    @Published var isCreatingTrack: Bool = false
    
    // Import/Export State (persisted across view recreation)
    enum IOImportMode {
        case project
        case infrastructure
    }
    @Published var ioImportMode: IOImportMode? = nil
    
    // Last used vehicle for defaults
    @Published var lastVehicleName: String = ""
    @Published var lastVehicleModel: String = ""
    @Published var lastVehicleLength: Double = 200
    @Published var lastVehicleMaxSpeed: Double = 160
    
    // Line Creation / Editing Picking State
    var stationPickingCallback: ((String) -> Void)? = nil
    @Published var lineDraftStations: [String] = []
    @Published var trackDraftFromId: String? = nil
    @Published var trackDraftToId: String? = nil
    @Published var isCreatingLine: Bool = false
    @Published var creationLineId: String? = nil { 
        didSet { 
            if creationLineId != nil { 
                showPanel(.inspector) 
            }
        }
    }
    
    // Schedule Preview State
    @Published var schedulePreviewTrains: [RailwayTrain]? = nil
    @Published var schedulePreviewLine: RailwayLine? = nil
    @Published var schedulePreviewMode: ScheduleMode = .single
    var schedulePreviewSelectedModel: TrainModel? = nil
    var schedulePreviewOptimizeVehicles: Bool = false
    var schedulePreviewMinTurnaroundTime: Int = 15
    
    // Optimized Times Preview State (Step 1 of two-step preview)
    struct OptimizedTimesPreviewData {
        let line: RailwayLine
        let mode: ScheduleMode
        let currentOutboundTime: Date
        let currentReturnTime: Date?
        let proposedOutboundTime: Date
        let proposedReturnTime: Date?
        let proposedInterval: Int?
        let proposedReturnInterval: Int?
    }
    @Published var optimizedTimesPreviewData: OptimizedTimesPreviewData? = nil
    @Published var optimizedTimesConfirmed: Bool = false
    @Published var scheduleCreationViewRefreshId: Int = 0  // Counter to force ScheduleCreationView recreation
    
    // MARK: - Selection Management Methods
    private func updateInspectorVisibilityForSelection() {
        withAnimation {
            if shouldShowInspectorForSelection() {
                activePanel = .inspector
            } else if shouldHideInspectorForSelection() {
                activePanel = .none
            }
        }
    }
    
    private func shouldShowInspectorForSelection() -> Bool {
        // Don't show the generic inspector if we are in track creation mode
        if isCreatingTrack { return false }
        
        // Now supports multi-selection scenarios
        return selectedLineId != nil || selectedNodeId != nil || 
               selectedEdgeId != nil || selectedFerroviaId != nil || !selectedTrainIds.isEmpty ||
               isInspectorEditingMode // Keep open if editing
    }
    
    private func shouldHideInspectorForSelection() -> Bool {
        // Don't auto-hide inspector when deselecting - let user close it manually
        // This allows hierarchical navigation (back to list without closing)
        return false
    }
    
    private func updateMapVisualizationMode() {
        // In Editor mode, we ALWAYS want to see the physical infrastructure (schematic)
        // and NEVER the logical service lines (scheduler).
        if currentMode == .editor {
            mapVisualizationMode = .schematic
            return
        }
        
        // Show colored lines when:
        // 1. Sidebar is on "Lines" or "Trains" section, OR
        // 2. A specific line is selected
        if sidebarSelection == .lines || sidebarSelection == .trains || selectedLineId != nil {
            mapVisualizationMode = .scheduler
        } else {
            mapVisualizationMode = .schematic
        }
    }
    
    func startTrainCreation(lineId: String) {
        self.creationLineId = lineId
        self.selectedLineId = lineId 
        self.selectedTrainIds = []
        self.selectedNodeId = nil
        self.selectedEdgeId = nil
        self.showPanel(.inspector)
    }
    
    var selectedLine: RailwayLine? {
        railroad.lines.lines.first { $0.id == selectedLineId }
    }
    
    var selectedNode: RailwayNode? {
        railroad.network.nodes.first { $0.id == selectedNodeId }
    }
    
    var selectedVehicle: RailwayVehicle? {
        railroad.lines.vehicles.first { $0.id == selectedVehicleId }
    }
    
    func selectTrain(_ id: UUID) {
        selectedTrainIds = [id]
        // selectedLineId = nil // Keep line context active!
        selectedNodeId = nil
        selectedEdgeId = nil
        // Don't close schedule creation when selecting a train
        // creationLineId = nil  // COMMENTED OUT
    }
    
    func selectLine(_ line: RailwayLine) {
        selectedLineId = line.id
        selectedNodeId = nil
        selectedEdgeId = nil
        selectedTrainIds = []
        // Don't close schedule creation when selecting a line
        // creationLineId = nil  // COMMENTED OUT
    }
    
    func clearSelection() {
        selectedLineId = nil
        selectedNodeId = nil
        selectedEdgeId = nil
        // Don't clear selectedTrainIds - keep train inspector open
        // selectedTrainIds = []  // COMMENTED OUT - this was causing the inspector to close when viewing trains
        // Don't clear selectedVehicleId - keep vehicle inspector open
        // selectedVehicleId = nil  // COMMENTED OUT - this was causing the inspector to close when viewing vehicles
        // Don't clear creationLineId - keep schedule generation view open
        // creationLineId = nil  // COMMENTED OUT - this was causing the inspector to close during schedule generation
        isShowingSettings = false
        // Don't close inspector if we're creating a line, generating schedules, viewing trains, or viewing vehicles
        if activePanel == .inspector && !isCreatingLine && creationLineId == nil && selectedTrainIds.isEmpty && selectedVehicleId == nil {
            activePanel = .none
        }
    }
    
    func showSettings() {
        clearSelection()
        isShowingSettings = true
        showPanel(.inspector)
    }
    
    var isSomethingSelected: Bool {
        selectedLineId != nil || selectedNodeId != nil || selectedEdgeId != nil || !selectedTrainIds.isEmpty
    }
    
    var isWidePanelVisible: Bool {
        // Wide panel active ONLY as an extension when managing a specific line's schedule
        if sidebarSelection == .lines && lineInspectorMode == .schedule && selectedLineId != nil {
            return true
        }
        return false
    }
    
    // MARK: - New Architecture (Code That Fits in Your Head)
    // Central Aggregate Root for the entire domain logic
    @Published var railroad = RailroadNetwork()
    
    // MARK: - Settings Aggregates (Reduced Cognitive Load)
    @Published var uiSettings = UISettings()
    @Published var trackSettings = TrackSettings()
    @Published var trainPhysics = TrainPhysicsSettings()
    @Published var aiCredentials = AICredentials()
    
    @Published var currentLanguage: AppLanguage {
        didSet { LocalizationManager.shared.currentLanguage = currentLanguage }
    }
    
    // MARK: - Backward Compatibility Properties
    // These provide seamless access to nested settings for existing code
    var globalLineWidth: Double {
        get { uiSettings.globalLineWidth }
        set { uiSettings.globalLineWidth = newValue }
    }
    
    var globalFontSize: Double {
        get { uiSettings.globalFontSize }
        set { uiSettings.globalFontSize = newValue }
    }
    
    var showGrid: Bool {
        get { uiSettings.showGrid }
        set { uiSettings.showGrid = newValue }
    }
    
    var isMoveModeEnabled: Bool {
        get { uiSettings.isMoveModeEnabled }
        set { uiSettings.isMoveModeEnabled = newValue }
    }
    
    var trackWidthSingle: Double {
        get { trackSettings.widthSingle }
        set { trackSettings.widthSingle = newValue }
    }
    
    var trackWidthDouble: Double {
        get { trackSettings.widthDouble }
        set { trackSettings.widthDouble = newValue }
    }
    
    var trackWidthRegional: Double {
        get { trackSettings.widthRegional }
        set { trackSettings.widthRegional = newValue }
    }
    
    var trackWidthHighSpeed: Double {
        get { trackSettings.widthHighSpeed }
        set { trackSettings.widthHighSpeed = newValue }
    }
    
    var regionalMaxSpeed: Double {
        get { trainPhysics.regionalMaxSpeed }
        set { trainPhysics.regionalMaxSpeed = newValue }
    }
    
    var regionalAcceleration: Double {
        get { trainPhysics.regionalAcceleration }
        set { trainPhysics.regionalAcceleration = newValue }
    }
    
    var regionalDeceleration: Double {
        get { trainPhysics.regionalDeceleration }
        set { trainPhysics.regionalDeceleration = newValue }
    }
    
    var regionalPriority: Double {
        get { trainPhysics.regionalPriority }
        set { trainPhysics.regionalPriority = newValue }
    }
    
    var intercityMaxSpeed: Double {
        get { trainPhysics.intercityMaxSpeed }
        set { trainPhysics.intercityMaxSpeed = newValue }
    }
    
    var intercityAcceleration: Double {
        get { trainPhysics.intercityAcceleration }
        set { trainPhysics.intercityAcceleration = newValue }
    }
    
    var intercityDeceleration: Double {
        get { trainPhysics.intercityDeceleration }
        set { trainPhysics.intercityDeceleration = newValue }
    }
    
    var intercityPriority: Double {
        get { trainPhysics.intercityPriority }
        set { trainPhysics.intercityPriority = newValue }
    }
    
    var highSpeedMaxSpeed: Double {
        get { trainPhysics.highSpeedMaxSpeed }
        set { trainPhysics.highSpeedMaxSpeed = newValue }
    }
    
    var highSpeedAcceleration: Double {
        get { trainPhysics.highSpeedAcceleration }
        set { trainPhysics.highSpeedAcceleration = newValue }
    }
    
    var highSpeedDeceleration: Double {
        get { trainPhysics.highSpeedDeceleration }
        set { trainPhysics.highSpeedDeceleration = newValue }
    }
    
    var highSpeedPriority: Double {
        get { trainPhysics.highSpeedPriority }
        set { trainPhysics.highSpeedPriority = newValue }
    }
    
    var singleTrackMaxSpeed: Double {
        get { trackSettings.maxSpeedSingle }
        set { trackSettings.maxSpeedSingle = newValue }
    }
    
    var doubleTrackMaxSpeed: Double {
        get { trackSettings.maxSpeedDouble }
        set { trackSettings.maxSpeedDouble = newValue }
    }
    
    var regionalTrackMaxSpeed: Double {
        get { trackSettings.maxSpeedRegional }
        set { trackSettings.maxSpeedRegional = newValue }
    }
    
    var highSpeedTrackMaxSpeed: Double {
        get { trackSettings.maxSpeedHighSpeed }
        set { trackSettings.maxSpeedHighSpeed = newValue }
    }
    
    var aiEndpoint: String {
        get { aiCredentials.endpoint }
        set { aiCredentials.endpoint = newValue }
    }
    
    var aiUsername: String {
        get { aiCredentials.username }
        set { aiCredentials.username = newValue }
    }
    
    var aiPassword: String {
        get { aiCredentials.password }
        set { aiCredentials.password = newValue }
    }
    
    var aiApiKey: String {
        get { aiCredentials.apiKey }
        set { aiCredentials.apiKey = newValue }
    }
    
    var useCloudAI: Bool {
        get { aiCredentials.useCloudAI }
        set { aiCredentials.useCloudAI = newValue }
    }
    
    init() {
        self.currentLanguage = LocalizationManager.shared.currentLanguage
        
        // Settings aggregates initialize themselves from UserDefaults/Keychain
        // This dramatically simplifies initialization
        
        initializeAIService()
        setupBindings()
    }
    
    // MARK: - Private Initialization Helpers
    private func initializeAIService() {
        aiCredentials.syncToService()
        RailwayAIService.shared.verifyConnection()
    }
    
    private func setupBindings() {
        // Propagate changes from RailroadNetwork to AppState
        railroad.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        liveSim.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        railroad.lines.onSchedulesChanged = { [weak self] in
            guard let self = self else { return }
            self.simulator.schedules = self.railroad.lines.generateSchedulesPreview()
        }
    }

    /// Centralized physics parameters for each train category
    func getPhysics(for category: TrainCategory) -> (acceleration: Double, deceleration: Double) {
        let params = trainPhysics.getParameters(for: category)
        return (params.acceleration, params.deceleration)
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case stations = "stazioni"
    case tracks = "binari"
    case ferrovie = "ferrovie"
    case lines = "lines"
    case vehicles = "materiale_rotabile"
    case trains = "trains"
    case timetable = "tabella_oraria"
    case diagram = "grafico_orario"
    case ai = "railway_ai"
    case io = "io"
    case settings = "settings"
    case simulation = "simulation"
    
    var id: String { rawValue }
    
    var title: String {
        return self.rawValue.localized
    }
    
    var icon: String {
        switch self {
        case .stations: return "building.2"
        case .tracks: return "tram"
        case .ferrovie: return "map.fill"
        case .lines: return "point.topleft.down.to.point.bottomright.curvepath"
        case .vehicles: return "tram.fill"
        case .trains: return "train.side.front.car"
        case .timetable: return "tablecells"
        case .diagram: return "chart.xyaxis.line"
        case .ai: return "sparkles"
        case .io: return "doc.badge.arrow.up"
        case .simulation: return "play.desktopcomputer"
        case .settings: return "gear"
        }
    }
}

enum AppMode: String, CaseIterable, Identifiable {
    case design, schedule, live, editor
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .design: return "Progetto"
        case .schedule: return "Programmazione"
        case .live: return "Esercizio"
        case .editor: return "Modifica"
        }
    }
}
