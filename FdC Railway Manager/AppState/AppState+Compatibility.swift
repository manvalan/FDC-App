import Foundation
import SwiftUI
import Combine

extension AppState {
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
    

}
