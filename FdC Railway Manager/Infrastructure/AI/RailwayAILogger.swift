import Foundation
import Combine

class RailwayAILogger: ObservableObject {
    static let shared = RailwayAILogger()
    
    @Published var logs: [LogEntry] = []
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp = Date()
        let message: String
        let type: LogType
    }
    
    enum LogType {
        case info, warning, error, success
    }
    
    func log(_ message: String, type: LogType = .info) {
        DispatchQueue.main.async {
            self.logs.append(LogEntry(message: message, type: type))
            if self.logs.count > 200 {
                self.logs.removeFirst()
            }
            print("[RailwayAILogger] \(message)")
        }
    }
}
