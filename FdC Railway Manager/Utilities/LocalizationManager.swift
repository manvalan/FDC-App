import Foundation
import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case italian = "it"
    case english = "en"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .italian: return "Italiano"
        case .english: return "English"
        }
    }
}

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
        }
    }
    
    private init() {
        let stored = UserDefaults.standard.string(forKey: "app_language") ?? "it"
        self.currentLanguage = AppLanguage(rawValue: stored) ?? .italian
    }
    
    func string(for key: String) -> String {
        return Self.string(for: key, language: currentLanguage)
    }
    
    static func string(for key: String, language: AppLanguage) -> String {
        let dict = (language == .italian) ? italianDict : englishDict
        return dict[key] ?? key
    }
}

extension String {
    var localized: String {
        return LocalizationManager.shared.string(for: self)
    }
    
    func localizedFormat(_ arguments: CVarArg...) -> String {
        let format = self.localized
        if arguments.isEmpty { return format }
        return String(format: format, arguments: arguments)
    }
}
