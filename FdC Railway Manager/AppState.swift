import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var showAI: Bool = false
    var aiNetwork: RailwayNetwork? = nil
    @Published var didAutoImport: Bool = false
    @Published var importMessage: String? = nil
    @Published var simulator = FDCSimulator()
    
    // Navigation State (Global)
    @Published var sidebarSelection: SidebarItem? = .lines
    @Published var jumpToTrainId: UUID? = nil
    
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
        
        var endpoint = UserDefaults.standard.string(forKey: "ai_endpoint") ?? "http://railway-ai.michelebigi.it:8080"
        
        // MIGRATION FIX: Force update if old IP or broken HTTPS is found
        if endpoint.contains("82.165.138.64") || endpoint.contains("localhost") || endpoint.hasPrefix("https://") {
            endpoint = "http://railway-ai.michelebigi.it:8080"
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
        self.aiToken = token
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
        RailwayAIService.shared.syncCredentials(endpoint: endpoint, apiKey: apiKey, token: token)
        RailwayAIService.shared.verifyConnection()
        
        // Auto-login if Cloud AI is enabled and we have credentials but no token
        if useCloudAI && token == nil && !password.isEmpty {
            AuthenticationManager.shared.login(username: username, password: password) { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success(let newToken):
                        self?.aiToken = newToken
                        RailwayAIService.shared.syncCredentials(
                            endpoint: endpoint,
                            apiKey: apiKey,
                            token: newToken
                        )
                        print("✅ Auto-login AI riuscito")
                    case .failure(let error):
                        print("⚠️ Auto-login AI fallito: \(error)")
                    }
                }
            }
        }
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case network = "network"
    case lines = "lines"
    case trains = "trains"
    case ai = "railway_ai"
    case io = "io"
    case settings = "settings"
    
    var id: String { rawValue }
    
    var title: String {
        return self.rawValue.localized
    }
    
    var icon: String {
        switch self {
        case .network: return "map"
        case .lines: return "point.topleft.down.to.point.bottomright.curvepath"
        case .trains: return "train.side.front.car"
        case .ai: return "sparkles"
        case .io: return "doc.badge.arrow.up"
        case .settings: return "gear"
        }
    }
}
