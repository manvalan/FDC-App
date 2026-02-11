import Foundation
import Combine
import SwiftUI

struct FdCTheme {
    var background: Color = Color(hex: "#F2F5F8")! // Default App Background
    var surface: Color = Color(hex: "#FFFFFF")!    // Card Surface
    var light: Color = Color(hex: "#E5E7EB")!      // Subtle Dividers / Unselected background
    var medium: Color = Color(hex: "#9CA3AF")!     // Secondary icons / text

    var dark: Color = Color(hex: "#4B5563")!       // Primary content / Sidebar labels
    var accent: Color = Color.blue                 // Selected items
    var line: Color = Color(hex: "#111827")!       // Graph Lines / Very dark accents
    var backgroundSecondary: Color = Color(hex: "#E5E7EB")! // Slightly darker/lighter background for contrast
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
    @Published var sidebarSelection: SidebarItem? = .lines
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
    
    // Selection State (Global)
    @Published var selectedLineId: String? = nil { didSet { withAnimation { if selectedLineId != nil { activePanel = .inspector } else if !isSomethingSelected { if activePanel == .inspector { activePanel = .none } } } } }
    @Published var selectedNodeId: String? = nil { didSet { withAnimation { if selectedNodeId != nil { activePanel = .inspector } else if !isSomethingSelected { if activePanel == .inspector { activePanel = .none } } } } }
    @Published var selectedEdgeId: String? = nil { didSet { withAnimation { if selectedEdgeId != nil { activePanel = .inspector } else if !isSomethingSelected { if activePanel == .inspector { activePanel = .none } } } } }
    @Published var selectedTrainIds: Set<UUID> = [] { didSet { withAnimation { if !selectedTrainIds.isEmpty { activePanel = .inspector } else if !isSomethingSelected { if activePanel == .inspector { activePanel = .none } } } } }
    @Published var isInspectorEditingMode: Bool = false
    @Published var lastVehicleAssignmentLineId: String? = nil
    
    // Last used vehicle for defaults
    @Published var lastVehicleName: String = ""
    @Published var lastVehicleModel: String = ""
    @Published var lastVehicleLength: Double = 200
    @Published var lastVehicleMaxSpeed: Double = 160
    
    // Line Creation / Editing Picking State
    var stationPickingCallback: ((String) -> Void)? = nil
    @Published var lineDraftStations: [String] = []
    
    var selectedLine: RailwayLine? {
        railroad.lines.lines.first { $0.id == selectedLineId }
    }
    
    var selectedNode: Node? {
        railroad.network.nodes.first { $0.id == selectedNodeId }
    }
    
    func selectTrain(_ id: UUID) {
        selectedTrainIds = [id]
        // selectedLineId = nil // Keep line context active!
        selectedNodeId = nil
        selectedEdgeId = nil
    }
    
    func selectLine(_ line: RailwayLine) {
        selectedLineId = line.id
        selectedNodeId = nil
        selectedEdgeId = nil
        selectedTrainIds = []
    }
    
    func clearSelection() {
        selectedLineId = nil
        selectedNodeId = nil
        selectedEdgeId = nil
        selectedTrainIds = []
        if activePanel == .inspector { activePanel = .none }
    }
    
    var isSomethingSelected: Bool {
        selectedLineId != nil || selectedNodeId != nil || selectedEdgeId != nil || !selectedTrainIds.isEmpty
    }
    
    var isWidePanelVisible: Bool {
        // Wide panel active when managing schedules in "Lines" tab and a line is selected
        if sidebarSelection == .lines && lineInspectorMode == .schedule && selectedLineId != nil {
            return true
        }
        // Also active in Trains tab if we want the general schedule view there
        if sidebarSelection == .trains {
            return true
        }
        return false
    }
    
    // MARK: - New Architecture (Code That Fits in Your Head)
    // Central Aggregate Root for the entire domain logic
    @Published var railroad = RailroadNetwork()
    
    // UI Settings
    @Published var globalLineWidth: Double {
        didSet { UserDefaults.standard.set(globalLineWidth, forKey: "global_line_width") }
    }
    @Published var globalFontSize: Double {
        didSet { UserDefaults.standard.set(globalFontSize, forKey: "global_font_size") }
    }
    
    // Track Line Widths
    @Published var trackWidthSingle: Double {
        didSet { UserDefaults.standard.set(trackWidthSingle, forKey: "track_width_single") }
    }
    @Published var trackWidthDouble: Double {
        didSet { UserDefaults.standard.set(trackWidthDouble, forKey: "track_width_double") }
    }
    @Published var trackWidthRegional: Double {
        didSet { UserDefaults.standard.set(trackWidthRegional, forKey: "track_width_regional") }
    }
    @Published var trackWidthHighSpeed: Double {
        didSet { UserDefaults.standard.set(trackWidthHighSpeed, forKey: "track_width_highspeed") }
    }
    
    // Train Parameters - Regional
    @Published var regionalMaxSpeed: Double {
        didSet { UserDefaults.standard.set(regionalMaxSpeed, forKey: "regional_max_speed") }
    }
    @Published var regionalAcceleration: Double {
        didSet { UserDefaults.standard.set(regionalAcceleration, forKey: "regional_acceleration") }
    }
    @Published var regionalDeceleration: Double {
        didSet { UserDefaults.standard.set(regionalDeceleration, forKey: "regional_deceleration") }
    }
    @Published var regionalPriority: Double {
        didSet { UserDefaults.standard.set(regionalPriority, forKey: "regional_priority") }
    }
    
    // Train Parameters - Intercity
    @Published var intercityMaxSpeed: Double {
        didSet { UserDefaults.standard.set(intercityMaxSpeed, forKey: "intercity_max_speed") }
    }
    @Published var intercityAcceleration: Double {
        didSet { UserDefaults.standard.set(intercityAcceleration, forKey: "intercity_acceleration") }
    }
    @Published var intercityDeceleration: Double {
        didSet { UserDefaults.standard.set(intercityDeceleration, forKey: "intercity_deceleration") }
    }
    @Published var intercityPriority: Double {
        didSet { UserDefaults.standard.set(intercityPriority, forKey: "intercity_priority") }
    }
    
    // Train Parameters - High Speed
    @Published var highSpeedMaxSpeed: Double {
        didSet { UserDefaults.standard.set(highSpeedMaxSpeed, forKey: "highspeed_max_speed") }
    }
    @Published var highSpeedAcceleration: Double {
        didSet { UserDefaults.standard.set(highSpeedAcceleration, forKey: "highspeed_acceleration") }
    }
    @Published var highSpeedDeceleration: Double {
        didSet { UserDefaults.standard.set(highSpeedDeceleration, forKey: "highspeed_deceleration") }
    }
    @Published var highSpeedPriority: Double {
        didSet { UserDefaults.standard.set(highSpeedPriority, forKey: "highspeed_priority") }
    }
    
    // Track Speed Limits
    @Published var singleTrackMaxSpeed: Double {
        didSet { UserDefaults.standard.set(singleTrackMaxSpeed, forKey: "single_track_max_speed") }
    }
    @Published var doubleTrackMaxSpeed: Double {
        didSet { UserDefaults.standard.set(doubleTrackMaxSpeed, forKey: "double_track_max_speed") }
    }
    @Published var regionalTrackMaxSpeed: Double {
        didSet { UserDefaults.standard.set(regionalTrackMaxSpeed, forKey: "regional_track_max_speed") }
    }
    @Published var highSpeedTrackMaxSpeed: Double {
        didSet { UserDefaults.standard.set(highSpeedTrackMaxSpeed, forKey: "highspeed_track_max_speed") }
    }
    
    @Published var aiEndpoint: String {
        didSet { UserDefaults.standard.set(aiEndpoint, forKey: "ai_endpoint") }
    }
    
    // Global UI Settings
    @Published var showGrid: Bool = false
    @Published var isMoveModeEnabled: Bool = false
    
    // ...



    @Published var aiUsername: String {
        didSet { UserDefaults.standard.set(aiUsername, forKey: "ai_username") }
    }
    @Published var aiPassword: String = "" {
        didSet { KeychainHelper.shared.save(aiPassword, service: "it.fdc.railway", account: "ai_password") }
    }
    @Published var aiToken: String? {
        didSet { 
            if let t = aiToken {
                KeychainHelper.shared.save(t, service: "it.fdc.railway", account: "ai_token")
            } else {
                KeychainHelper.shared.delete(service: "it.fdc.railway", account: "ai_token")
            }
        }
    }
    @Published var aiApiKey: String {
        didSet { KeychainHelper.shared.save(aiApiKey, service: "it.fdc.railway", account: "ai_api_key") }
    }
    @Published var useCloudAI: Bool {
        didSet { UserDefaults.standard.set(useCloudAI, forKey: "use_cloud_ai") }
    }
    
    @Published var currentLanguage: AppLanguage {
        didSet { LocalizationManager.shared.currentLanguage = currentLanguage }
    }
    
    init() {
        self.currentLanguage = LocalizationManager.shared.currentLanguage
        
        var endpoint = UserDefaults.standard.string(forKey: "ai_endpoint") ?? "https://railway-ai.michelebigi.it"
        
        // MIGRATION FIX: Force upgrade to HTTPS if using old HTTP or port 8080
        if endpoint.contains("82.165.138.64") || endpoint.contains("localhost") || endpoint.contains(":8080") || endpoint.hasPrefix("http://") {
            endpoint = "https://railway-ai.michelebigi.it"
            UserDefaults.standard.set(endpoint, forKey: "ai_endpoint") // Persist correction
        }

        let username = UserDefaults.standard.string(forKey: "ai_username") ?? "admin"
        let password = KeychainHelper.shared.read(service: "it.fdc.railway", account: "ai_password") ?? ""
        let apiKey = KeychainHelper.shared.read(service: "it.fdc.railway", account: "ai_api_key") ?? ""
        let token = KeychainHelper.shared.read(service: "it.fdc.railway", account: "ai_token")
        
        self.aiEndpoint = endpoint
        self.aiUsername = username
        self.aiPassword = password
        self.aiApiKey = apiKey
        
        // JWT Tokens are deprecated - explicitly clear from state and Keychain
        self.aiToken = nil
        KeychainHelper.shared.delete(service: "it.fdc.railway", account: "ai_token")
        
        self.useCloudAI = UserDefaults.standard.bool(forKey: "use_cloud_ai")
        
        let storedWidth = UserDefaults.standard.double(forKey: "global_line_width")
        self.globalLineWidth = (storedWidth > 0) ? storedWidth : 12.0
        
        let storedFontSize = UserDefaults.standard.double(forKey: "global_font_size")
        self.globalFontSize = (storedFontSize > 0) ? storedFontSize : 14.0
        
        // Track widths
        let singleWidth = UserDefaults.standard.double(forKey: "track_width_single")
        self.trackWidthSingle = (singleWidth > 0) ? singleWidth : 1.0
        
        let doubleWidth = UserDefaults.standard.double(forKey: "track_width_double")
        self.trackWidthDouble = (doubleWidth > 0) ? doubleWidth : 3.0
        
        let regionalWidth = UserDefaults.standard.double(forKey: "track_width_regional")
        self.trackWidthRegional = (regionalWidth > 0) ? regionalWidth : 1.8
        
        let highSpeedWidth = UserDefaults.standard.double(forKey: "track_width_highspeed")
        self.trackWidthHighSpeed = (highSpeedWidth > 0) ? highSpeedWidth : 2.5
        
        // Train Parameters - Regional
        let regSpeed = UserDefaults.standard.double(forKey: "regional_max_speed")
        self.regionalMaxSpeed = (regSpeed > 0) ? regSpeed : 120
        let regAccel = UserDefaults.standard.double(forKey: "regional_acceleration")
        self.regionalAcceleration = (regAccel > 0) ? regAccel : 0.5
        let regDecel = UserDefaults.standard.double(forKey: "regional_deceleration")
        self.regionalDeceleration = (regDecel > 0) ? regDecel : 0.5
        let regPrio = UserDefaults.standard.double(forKey: "regional_priority")
        self.regionalPriority = (regPrio > 0) ? regPrio : 3
        
        // Train Parameters - Intercity
        let icSpeed = UserDefaults.standard.double(forKey: "intercity_max_speed")
        self.intercityMaxSpeed = (icSpeed > 0) ? icSpeed : 160
        let icAccel = UserDefaults.standard.double(forKey: "intercity_acceleration")
        self.intercityAcceleration = (icAccel > 0) ? icAccel : 0.7
        let icDecel = UserDefaults.standard.double(forKey: "intercity_deceleration")
        self.intercityDeceleration = (icDecel > 0) ? icDecel : 0.7
        let icPrio = UserDefaults.standard.double(forKey: "intercity_priority")
        self.intercityPriority = (icPrio > 0) ? icPrio : 6
        
        // Train Parameters - High Speed
        let hsSpeed = UserDefaults.standard.double(forKey: "highspeed_max_speed")
        self.highSpeedMaxSpeed = (hsSpeed > 0) ? hsSpeed : 300
        let hsAccel = UserDefaults.standard.double(forKey: "highspeed_acceleration")
        self.highSpeedAcceleration = (hsAccel > 0) ? hsAccel : 1.0
        let hsDecel = UserDefaults.standard.double(forKey: "highspeed_deceleration")
        self.highSpeedDeceleration = (hsDecel > 0) ? hsDecel : 1.0
        let hsPrio = UserDefaults.standard.double(forKey: "highspeed_priority")
        self.highSpeedPriority = (hsPrio > 0) ? hsPrio : 10
        
        // Track Speed Limits
        let singleTrackSpeed = UserDefaults.standard.double(forKey: "single_track_max_speed")
        self.singleTrackMaxSpeed = (singleTrackSpeed > 0) ? singleTrackSpeed : 100
        let doubleTrackSpeed = UserDefaults.standard.double(forKey: "double_track_max_speed")
        self.doubleTrackMaxSpeed = (doubleTrackSpeed > 0) ? doubleTrackSpeed : 160
        let regionalTrackSpeed = UserDefaults.standard.double(forKey: "regional_track_max_speed")
        self.regionalTrackMaxSpeed = (regionalTrackSpeed > 0) ? regionalTrackSpeed : 200
        let highSpeedTrackSpeed = UserDefaults.standard.double(forKey: "highspeed_track_max_speed")
        self.highSpeedTrackMaxSpeed = (highSpeedTrackSpeed > 0) ? highSpeedTrackSpeed : 300
        
        // Initial sync of credentials to the singleton service
        RailwayAIService.shared.syncCredentials(endpoint: endpoint, apiKey: apiKey, token: nil)
        RailwayAIService.shared.verifyConnection()
        
        // Auto-login is disabled - we only use apiKey
        
        setupBindings()
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
        switch category {
        case .regional:
            return (regionalAcceleration, regionalDeceleration)
        case .direct:
            return (intercityAcceleration, intercityDeceleration)
        case .highSpeed:
            return (highSpeedAcceleration, highSpeedDeceleration)
        case .freight:
            return (0.3, 0.3)
        case .support:
            return (0.4, 0.4)
        }
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case stations = "stazioni"
    case tracks = "binari"
    case lines = "lines"
    case trains = "trains"
    case vehicles = "materiale_rotabile"
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
        case .lines: return "point.topleft.down.to.point.bottomright.curvepath"
        case .trains: return "train.side.front.car"
        case .vehicles: return "tram.fill"
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
    case design, schedule, live
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .design: return "Progetto"
        case .schedule: return "Programmazione"
        case .live: return "Esercizio"
        }
    }
}
