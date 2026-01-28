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
    
    @Published var aiEndpoint: String {
        didSet { UserDefaults.standard.set(aiEndpoint, forKey: "ai_endpoint") }
    }
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
    
    init() {
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
        
        // Initial sync of credentials to the singleton service
        RailwayAIService.shared.syncCredentials(endpoint: endpoint, apiKey: apiKey, token: token)
        RailwayAIService.shared.verifyConnection()
    }
}
