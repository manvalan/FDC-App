import Foundation

enum AppEnvironment {
    case development
    case production
}

struct AppConfig {
    // Setting to .production as per user instructions
    static let currentEnvironment: AppEnvironment = .production
    
    static let apiBaseURL: String = {
        switch currentEnvironment {
        case .development:
            #if targetEnvironment(simulator)
            return "http://localhost:8000"
            #else
            return "http://railway-ai.michelebigi.it:8080"
            #endif
        case .production:
            return "http://railway-ai.michelebigi.it:8080"
        }
    }()
    
    static let proposeScheduleEndpoint = "\(apiBaseURL)/api/v1/propose_schedule"
}
