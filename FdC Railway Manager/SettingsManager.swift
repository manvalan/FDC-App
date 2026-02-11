import Foundation
import SwiftUI
import Combine

/// Dati di setup e preferenze dell'utente.
@MainActor
final class SettingsManager: ObservableObject {
    @Published var globalLineWidth: Double {
        didSet { UserDefaults.standard.set(globalLineWidth, forKey: "global_line_width") }
    }
    @Published var globalFontSize: Double {
        didSet { UserDefaults.standard.set(globalFontSize, forKey: "global_font_size") }
    }
    
    // Train Parameters
    @Published var regionalMaxSpeed: Double
    @Published var regionalAcceleration: Double
    @Published var regionalDeceleration: Double
    @Published var regionalPriority: Double
    
    @Published var intercityMaxSpeed: Double
    @Published var intercityAcceleration: Double
    @Published var intercityDeceleration: Double
    @Published var intercityPriority: Double
    
    @Published var highSpeedMaxSpeed: Double
    @Published var highSpeedAcceleration: Double
    @Published var highSpeedDeceleration: Double
    @Published var highSpeedPriority: Double
    
    init() {
        self.globalLineWidth = UserDefaults.standard.double(forKey: "global_line_width") > 0 ? UserDefaults.standard.double(forKey: "global_line_width") : 12.0
        self.globalFontSize = UserDefaults.standard.double(forKey: "global_font_size") > 0 ? UserDefaults.standard.double(forKey: "global_font_size") : 14.0
        
        self.regionalMaxSpeed = UserDefaults.standard.double(forKey: "regional_max_speed") > 0 ? UserDefaults.standard.double(forKey: "regional_max_speed") : 120
        self.regionalAcceleration = UserDefaults.standard.double(forKey: "regional_acceleration") > 0 ? UserDefaults.standard.double(forKey: "regional_acceleration") : 0.5
        self.regionalDeceleration = UserDefaults.standard.double(forKey: "regional_deceleration") > 0 ? UserDefaults.standard.double(forKey: "regional_deceleration") : 0.5
        self.regionalPriority = UserDefaults.standard.double(forKey: "regional_priority") > 0 ? UserDefaults.standard.double(forKey: "regional_priority") : 3
        
        self.intercityMaxSpeed = UserDefaults.standard.double(forKey: "intercity_max_speed") > 0 ? UserDefaults.standard.double(forKey: "intercity_max_speed") : 160
        self.intercityAcceleration = UserDefaults.standard.double(forKey: "intercity_acceleration") > 0 ? UserDefaults.standard.double(forKey: "intercity_acceleration") : 0.7
        self.intercityDeceleration = UserDefaults.standard.double(forKey: "intercity_deceleration") > 0 ? UserDefaults.standard.double(forKey: "intercity_deceleration") : 0.7
        self.intercityPriority = UserDefaults.standard.double(forKey: "intercity_priority") > 0 ? UserDefaults.standard.double(forKey: "intercity_priority") : 6
        
        self.highSpeedMaxSpeed = UserDefaults.standard.double(forKey: "highspeed_max_speed") > 0 ? UserDefaults.standard.double(forKey: "highspeed_max_speed") : 300
        self.highSpeedAcceleration = UserDefaults.standard.double(forKey: "highspeed_acceleration") > 0 ? UserDefaults.standard.double(forKey: "highspeed_acceleration") : 1.0
        self.highSpeedDeceleration = UserDefaults.standard.double(forKey: "highspeed_deceleration") > 0 ? UserDefaults.standard.double(forKey: "highspeed_deceleration") : 1.0
        self.highSpeedPriority = UserDefaults.standard.double(forKey: "highspeed_priority") > 0 ? UserDefaults.standard.double(forKey: "highspeed_priority") : 10
    }
}
