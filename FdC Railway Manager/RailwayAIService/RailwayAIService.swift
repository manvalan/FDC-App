import Foundation
import Combine

@MainActor
class RailwayAIService: ObservableObject {
    static let shared = RailwayAIService()
    
    struct RouteAnalysis: Codable {
        let maxFrequency: String?
        let recommendedFrequency: String?
        let optimalOffsetAB: Int? // In minutes
        
        // Extended fields from the AI V2 Analysis engine
        let travelTimeMin: Double?
        let crossingPointsCount: Int?
        let minHeadwayMin: Double?
        let optimalHeadwayMin: Double?
        let optimalOffsetMin: Double?
        let recommendation: String?
        
        enum CodingKeys: String, CodingKey {
            case maxFrequency = "max_frequency"
            case recommendedFrequency = "recommended_frequency"
            case optimalOffsetAB = "optimal_offset_ab"
            case travelTimeMin = "travel_time_min"
            case crossingPointsCount = "crossing_points_count"
            case minHeadwayMin = "min_headway_min"
            case optimalHeadwayMin = "optimal_headway_min"
            case optimalOffsetMin = "optimal_offset_min"
            case recommendation
        }
    }
    
    var baseURL = URL(string: "https://railway-ai.michelebigi.it/api/v1")!
    var token: String? = nil
    var apiKey: String? = nil
    
    var stationMapping: [String: Int] = [:]
    var trackMapping: [String: Int] = [:]
    var trainMapping: [UUID: Int] = [:]
    
    enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case unauthorized
        case error(String)
    }
    
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    @Published var lastRequestJSON: String = "" // Per ispezione da iPad
    var webSocket: URLSessionWebSocketTask? 
    @Published var wsMessages: [WSMessage] = [] 
    @Published var isWsConnected = false
    
    func syncCredentials(endpoint: String, apiKey: String, token: String? = nil) {
        var cleanEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Robust Endpoint Sanitization: ensure /api/v1 is present
        if !cleanEndpoint.isEmpty {
            if !cleanEndpoint.contains("/api/v1") && !cleanEndpoint.contains("/token") {
                if cleanEndpoint.hasSuffix("/") {
                    cleanEndpoint += "api/v1"
                } else {
                    cleanEndpoint += "/api/v1"
                }
            }
        }
        
        if let url = URL(string: cleanEndpoint), !cleanEndpoint.isEmpty {
            self.baseURL = url
            // Update AuthManager with the base server URL (stripping /api/v1 if present)
            var baseServer = cleanEndpoint.replacingOccurrences(of: "/api/v1", with: "")
            if baseServer.hasSuffix("/") { baseServer.removeLast() }
            AuthenticationManager.shared.updateBaseURL(baseServer)
        }
        
        // Use API Key exactly as provided - only trim whitespace
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = cleanKey.isEmpty ? nil : cleanKey
        
        // If a new token is provided, use it (temporary session). 
        // Otherwise, if we are syncing without a token, ensure it's cleared.
        if let t = token, !t.isEmpty {
            self.token = t
        } else if token == nil {
            // Only clear if explicitly nil (not just omitted if we had a default which we don't here as it's an override)
            // Wait, the signature is token: String? = nil.
            // If called as syncCredentials(..., token: nil), we clear.
            self.token = nil
        }
        
        // Update AuthManager as well
        if let key = self.apiKey { AuthenticationManager.shared.setAPIKey(key) }
        if let t = self.token { AuthenticationManager.shared.setToken(t) } else { AuthenticationManager.shared.setToken("") }
        
        RailwayAILogger.shared.log("Sync Complete. Endpoint: \(self.baseURL)", type: .info)
        RailwayAILogger.shared.log("API Key: \(self.apiKey != nil ? "Presente" : "Assente"), Token: \(self.token != nil ? "Presente" : "Assente")", type: .info)
    }
    
    struct TokenResponse: Codable {
        let access_token: String
        let token_type: String
    }
    struct APIKeyResponse: Codable {
        let api_key: String
    }
    

}
