import Foundation
import Combine
import SwiftUI


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
    @Published var selectedRouteId: String? = nil { 
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
    
    @Published var selectedInfraLineId: String? = nil {
        didSet { updateInspectorVisibilityForSelection() }
    }
    
    /// The currently selected physical infrastructure line (ex `selectedFerrovia`).
    var selectedInfraLine: RailwayLine? {
        guard let id = selectedInfraLineId else { return nil }
        return railroad.network.lines.first(where: { $0.id == id })
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
    @Published var lastVehicleAssignmentRouteId: String? = nil
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
    @Published var creationRouteId: String? = nil { 
        didSet { 
            if creationRouteId != nil { 
                showPanel(.inspector) 
            }
        }
    }
    
    // Schedule Preview State
    @Published var schedulePreviewTrains: [RailwayTrain]? = nil
    @Published var schedulePreviewRoute: TrainRoute? = nil
    @Published var schedulePreviewMode: ScheduleMode = .single
    var schedulePreviewSelectedModel: TrainModel? = nil
    @Published var schedulePreviewOptimizeVehicles: Bool = true
    @Published var schedulePreviewMinTurnaroundTime: Int = 15
    
    // Optimized Times Preview State (Step 1 of two-step preview)
    struct OptimizedTimesPreviewData {
        let route: TrainRoute
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
        return selectedRouteId != nil || selectedNodeId != nil || 
               selectedEdgeId != nil || selectedInfraLineId != nil || !selectedTrainIds.isEmpty ||
               isInspectorEditingMode
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
        if sidebarSelection == .lines || sidebarSelection == .trains || selectedRouteId != nil {
            mapVisualizationMode = .scheduler
        } else {
            mapVisualizationMode = .schematic
        }
    }
    
    func startTrainCreation(routeId: String) {
        self.creationRouteId = routeId
        self.selectedRouteId = routeId 
        self.selectedTrainIds = []
        self.selectedNodeId = nil
        self.selectedEdgeId = nil
        self.showPanel(.inspector)
    }
    
    /// The currently selected service route (TrainRoute), i.e. the "Linea" in the scheduler sidebar.
    var selectedRoute: TrainRoute? {
        railroad.lines.routes.first { $0.id == selectedRouteId }
    }
    
    /// Legacy alias kept for call-site compat during migration — prefer `selectedRoute`.
    var selectedLine: TrainRoute? { selectedRoute }
    
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
    
    func selectLine(_ route: TrainRoute) {
        selectedRouteId = route.id
        selectedNodeId = nil
        selectedEdgeId = nil
        selectedTrainIds = []
    }
    
    func clearSelection() {
        selectedRouteId = nil
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
        if activePanel == .inspector && !isCreatingLine && creationRouteId == nil && selectedTrainIds.isEmpty && selectedVehicleId == nil {
            activePanel = .none
        }
    }
    
    func showSettings() {
        clearSelection()
        isShowingSettings = true
        showPanel(.inspector)
    }
    
    var isSomethingSelected: Bool {
        selectedRouteId != nil || selectedNodeId != nil || selectedEdgeId != nil || !selectedTrainIds.isEmpty
    }
    
    var isWidePanelVisible: Bool {
        // Wide panel active ONLY as an extension when managing a specific line's schedule
        if sidebarSelection == .lines && lineInspectorMode == .schedule && selectedRouteId != nil {
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
