import Foundation
import SwiftUI
import Combine

// MARK: - UI Settings Aggregate
// Separates UI-related settings from business logic
final class UISettings: ObservableObject {
    @Published var globalLineWidth: Double {
        didSet { UserDefaults.standard.set(globalLineWidth, forKey: "global_line_width") }
    }
    
    @Published var globalFontSize: Double {
        didSet { UserDefaults.standard.set(globalFontSize, forKey: "global_font_size") }
    }
    
    @Published var showGrid: Bool = false
    @Published var isMoveModeEnabled: Bool = false
    
    init() {
        let storedWidth = UserDefaults.standard.double(forKey: "global_line_width")
        self.globalLineWidth = (storedWidth > 0) ? storedWidth : 12.0
        
        let storedFontSize = UserDefaults.standard.double(forKey: "global_font_size")
        self.globalFontSize = (storedFontSize > 0) ? storedFontSize : 14.0
    }
}

// MARK: - Track Settings Aggregate
final class TrackSettings: ObservableObject {
    @Published var widthSingle: Double {
        didSet { UserDefaults.standard.set(widthSingle, forKey: "track_width_single") }
    }
    
    @Published var widthDouble: Double {
        didSet { UserDefaults.standard.set(widthDouble, forKey: "track_width_double") }
    }
    
    @Published var widthRegional: Double {
        didSet { UserDefaults.standard.set(widthRegional, forKey: "track_width_regional") }
    }
    
    @Published var widthHighSpeed: Double {
        didSet { UserDefaults.standard.set(widthHighSpeed, forKey: "track_width_highspeed") }
    }
    
    @Published var maxSpeedSingle: Double {
        didSet { UserDefaults.standard.set(maxSpeedSingle, forKey: "single_track_max_speed") }
    }
    
    @Published var maxSpeedDouble: Double {
        didSet { UserDefaults.standard.set(maxSpeedDouble, forKey: "double_track_max_speed") }
    }
    
    @Published var maxSpeedRegional: Double {
        didSet { UserDefaults.standard.set(maxSpeedRegional, forKey: "regional_track_max_speed") }
    }
    
    @Published var maxSpeedHighSpeed: Double {
        didSet { UserDefaults.standard.set(maxSpeedHighSpeed, forKey: "highspeed_track_max_speed") }
    }
    
    init() {
        let singleWidth = UserDefaults.standard.double(forKey: "track_width_single")
        self.widthSingle = (singleWidth > 0) ? singleWidth : 1.0
        
        let doubleWidth = UserDefaults.standard.double(forKey: "track_width_double")
        self.widthDouble = (doubleWidth > 0) ? doubleWidth : 3.0
        
        let regionalWidth = UserDefaults.standard.double(forKey: "track_width_regional")
        self.widthRegional = (regionalWidth > 0) ? regionalWidth : 1.8
        
        let highSpeedWidth = UserDefaults.standard.double(forKey: "track_width_highspeed")
        self.widthHighSpeed = (highSpeedWidth > 0) ? highSpeedWidth : 2.5
        
        let singleSpeed = UserDefaults.standard.double(forKey: "single_track_max_speed")
        self.maxSpeedSingle = (singleSpeed > 0) ? singleSpeed : 100
        
        let doubleSpeed = UserDefaults.standard.double(forKey: "double_track_max_speed")
        self.maxSpeedDouble = (doubleSpeed > 0) ? doubleSpeed : 160
        
        let regionalSpeed = UserDefaults.standard.double(forKey: "regional_track_max_speed")
        self.maxSpeedRegional = (regionalSpeed > 0) ? regionalSpeed : 200
        
        let highSpeedSpeed = UserDefaults.standard.double(forKey: "highspeed_track_max_speed")
        self.maxSpeedHighSpeed = (highSpeedSpeed > 0) ? highSpeedSpeed : 300
    }
}

// MARK: - Train Physics Settings
struct TrainPhysicsParameters {
    let maxSpeed: Double
    let acceleration: Double
    let deceleration: Double
    let mass: Double
    let power: Double
    let priority: Double
}

final class TrainPhysicsSettings: ObservableObject {
    // Regional
    @Published var regionalMaxSpeed: Double {
        didSet { UserDefaults.standard.set(regionalMaxSpeed, forKey: "regional_max_speed") }
    }
    @Published var regionalAcceleration: Double {
        didSet { UserDefaults.standard.set(regionalAcceleration, forKey: "regional_acceleration") }
    }
    @Published var regionalDeceleration: Double {
        didSet { UserDefaults.standard.set(regionalDeceleration, forKey: "regional_deceleration") }
    }
    @Published var regionalMass: Double {
        didSet { UserDefaults.standard.set(regionalMass, forKey: "regional_mass") }
    }
    @Published var regionalPower: Double {
        didSet { UserDefaults.standard.set(regionalPower, forKey: "regional_power") }
    }
    @Published var regionalPriority: Double {
        didSet { UserDefaults.standard.set(regionalPriority, forKey: "regional_priority") }
    }
    
    // Intercity
    @Published var intercityMaxSpeed: Double {
        didSet { UserDefaults.standard.set(intercityMaxSpeed, forKey: "intercity_max_speed") }
    }
    @Published var intercityAcceleration: Double {
        didSet { UserDefaults.standard.set(intercityAcceleration, forKey: "intercity_acceleration") }
    }
    @Published var intercityDeceleration: Double {
        didSet { UserDefaults.standard.set(intercityDeceleration, forKey: "intercity_deceleration") }
    }
    @Published var intercityMass: Double {
        didSet { UserDefaults.standard.set(intercityMass, forKey: "intercity_mass") }
    }
    @Published var intercityPower: Double {
        didSet { UserDefaults.standard.set(intercityPower, forKey: "intercity_power") }
    }
    @Published var intercityPriority: Double {
        didSet { UserDefaults.standard.set(intercityPriority, forKey: "intercity_priority") }
    }
    
    // High Speed
    @Published var highSpeedMaxSpeed: Double {
        didSet { UserDefaults.standard.set(highSpeedMaxSpeed, forKey: "highspeed_max_speed") }
    }
    @Published var highSpeedAcceleration: Double {
        didSet { UserDefaults.standard.set(highSpeedAcceleration, forKey: "highspeed_acceleration") }
    }
    @Published var highSpeedDeceleration: Double {
        didSet { UserDefaults.standard.set(highSpeedDeceleration, forKey: "highspeed_deceleration") }
    }
    @Published var highSpeedMass: Double {
        didSet { UserDefaults.standard.set(highSpeedMass, forKey: "highspeed_mass") }
    }
    @Published var highSpeedPower: Double {
        didSet { UserDefaults.standard.set(highSpeedPower, forKey: "highspeed_power") }
    }
    @Published var highSpeedPriority: Double {
        didSet { UserDefaults.standard.set(highSpeedPriority, forKey: "highspeed_priority") }
    }
    
    init() {
        // Regional
        let regSpeed = UserDefaults.standard.double(forKey: "regional_max_speed")
        self.regionalMaxSpeed = (regSpeed > 0) ? regSpeed : 120
        let regAccel = UserDefaults.standard.double(forKey: "regional_acceleration")
        self.regionalAcceleration = (regAccel > 0) ? regAccel : 0.5
        let regDecel = UserDefaults.standard.double(forKey: "regional_deceleration")
        self.regionalDeceleration = (regDecel > 0) ? regDecel : 0.5
        let regMass = UserDefaults.standard.double(forKey: "regional_mass")
        self.regionalMass = (regMass > 0) ? regMass : 200
        let regPower = UserDefaults.standard.double(forKey: "regional_power")
        self.regionalPower = (regPower > 0) ? regPower : 2500
        let regPrio = UserDefaults.standard.double(forKey: "regional_priority")
        self.regionalPriority = (regPrio > 0) ? regPrio : 3
        
        // Intercity
        let icSpeed = UserDefaults.standard.double(forKey: "intercity_max_speed")
        self.intercityMaxSpeed = (icSpeed > 0) ? icSpeed : 160
        let icAccel = UserDefaults.standard.double(forKey: "intercity_acceleration")
        self.intercityAcceleration = (icAccel > 0) ? icAccel : 0.7
        let icDecel = UserDefaults.standard.double(forKey: "intercity_deceleration")
        self.intercityDeceleration = (icDecel > 0) ? icDecel : 0.7
        let icMass = UserDefaults.standard.double(forKey: "intercity_mass")
        self.intercityMass = (icMass > 0) ? icMass : 450
        let icPower = UserDefaults.standard.double(forKey: "intercity_power")
        self.intercityPower = (icPower > 0) ? icPower : 6000
        let icPrio = UserDefaults.standard.double(forKey: "intercity_priority")
        self.intercityPriority = (icPrio > 0) ? icPrio : 6
        
        // High Speed
        let hsSpeed = UserDefaults.standard.double(forKey: "highspeed_max_speed")
        self.highSpeedMaxSpeed = (hsSpeed > 0) ? hsSpeed : 300
        let hsAccel = UserDefaults.standard.double(forKey: "highspeed_acceleration")
        self.highSpeedAcceleration = (hsAccel > 0) ? hsAccel : 1.0
        let hsDecel = UserDefaults.standard.double(forKey: "highspeed_deceleration")
        self.highSpeedDeceleration = (hsDecel > 0) ? hsDecel : 1.0
        let hsMass = UserDefaults.standard.double(forKey: "highspeed_mass")
        self.highSpeedMass = (hsMass > 0) ? hsMass : 500
        let hsPower = UserDefaults.standard.double(forKey: "highspeed_power")
        self.highSpeedPower = (hsPower > 0) ? hsPower : 9800
        let hsPrio = UserDefaults.standard.double(forKey: "highspeed_priority")
        self.highSpeedPriority = (hsPrio > 0) ? hsPrio : 10
    }
    
    func getParameters(for category: TrainCategory) -> TrainPhysicsParameters {
        switch category {
        case .regional:
            return TrainPhysicsParameters(
                maxSpeed: regionalMaxSpeed,
                acceleration: regionalAcceleration,
                deceleration: regionalDeceleration,
                mass: regionalMass,
                power: regionalPower,
                priority: regionalPriority
            )
        case .direct:
            return TrainPhysicsParameters(
                maxSpeed: intercityMaxSpeed,
                acceleration: intercityAcceleration,
                deceleration: intercityDeceleration,
                mass: intercityMass,
                power: intercityPower,
                priority: intercityPriority
            )
        case .highSpeed:
            return TrainPhysicsParameters(
                maxSpeed: highSpeedMaxSpeed,
                acceleration: highSpeedAcceleration,
                deceleration: highSpeedDeceleration,
                mass: highSpeedMass,
                power: highSpeedPower,
                priority: highSpeedPriority
            )
        case .freight:
            return TrainPhysicsParameters(maxSpeed: 100, acceleration: 0.3, deceleration: 0.3, mass: 1200, power: 4500, priority: 2)
        case .support:
            return TrainPhysicsParameters(maxSpeed: 80, acceleration: 0.4, deceleration: 0.4, mass: 80, power: 1500, priority: 1)
        }
    }
}

// MARK: - AI Credentials Aggregate
final class AICredentials: ObservableObject {
    @Published var endpoint: String {
        didSet { UserDefaults.standard.set(endpoint, forKey: "ai_endpoint") }
    }
    
    @Published var username: String {
        didSet { UserDefaults.standard.set(username, forKey: "ai_username") }
    }
    
    @Published var password: String {
        didSet { 
            KeychainHelper.shared.save(password, service: "it.fdc.railway", account: "ai_password")
        }
    }
    
    @Published var apiKey: String {
        didSet { 
            KeychainHelper.shared.save(apiKey, service: "it.fdc.railway", account: "ai_api_key")
        }
    }
    
    @Published var useCloudAI: Bool {
        didSet { UserDefaults.standard.set(useCloudAI, forKey: "use_cloud_ai") }
    }
    
    init() {
        var endpoint = UserDefaults.standard.string(forKey: "ai_endpoint") ?? "https://railway-ai.michelebigi.it"
        
        // Migration fix: Force upgrade to HTTPS
        if endpoint.contains("82.165.138.64") || endpoint.contains("localhost") || 
           endpoint.contains(":8080") || endpoint.hasPrefix("http://") {
            endpoint = "https://railway-ai.michelebigi.it"
            UserDefaults.standard.set(endpoint, forKey: "ai_endpoint")
        }
        
        self.endpoint = endpoint
        self.username = UserDefaults.standard.string(forKey: "ai_username") ?? "admin"
        self.password = KeychainHelper.shared.read(service: "it.fdc.railway", account: "ai_password") ?? ""
        self.apiKey = KeychainHelper.shared.read(service: "it.fdc.railway", account: "ai_api_key") ?? ""
        self.useCloudAI = UserDefaults.standard.bool(forKey: "use_cloud_ai")
        
        // Clear deprecated JWT tokens
        KeychainHelper.shared.delete(service: "it.fdc.railway", account: "ai_token")
    }
    
    func syncToService() {
        RailwayAIService.shared.syncCredentials(endpoint: endpoint, apiKey: apiKey, token: nil)
    }
}
