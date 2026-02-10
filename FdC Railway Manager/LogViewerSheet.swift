import SwiftUI

struct LogViewerSheet: View {
    @ObservedObject var logger = RailwayAILogger.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List(logger.logs.reversed()) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(typeString(entry.type))
                            .font(.caption2.bold())
                            .foregroundColor(typeColor(entry.type))
                    }
                    
                    Text(entry.message)
                        .font(.system(.caption, design: .monospaced))
                }
            }
            .navigationTitle("diagnostics_log".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close".localized) { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("clear".localized) { logger.logs.removeAll() }
                }
            }
        }
    }
    
    private func typeString(_ type: RailwayAILogger.LogType) -> String {
        switch type {
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERR"
        case .success: return "OK"
        }
    }
    
    private func typeColor(_ type: RailwayAILogger.LogType) -> Color {
        switch type {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
}
