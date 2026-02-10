import Foundation
import SwiftUI
import Combine

struct LogEntry: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogType
    
    enum LogType {
        case info, warning, error, success
    }
}

@MainActor
final class SimulationLogManager: ObservableObject {
    @Published var entries: [LogEntry] = []
    
    func addLog(_ message: String, type: LogEntry.LogType = .info, timestamp: Date = Date()) {
        let entry = LogEntry(timestamp: timestamp, message: message, type: type)
        entries.insert(entry, at: 0)
        if entries.count > 100 {
            entries.removeLast()
        }
    }
    
    func clear() {
        entries = []
    }
}
