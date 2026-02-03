import SwiftUI

struct DiagnosticsSettingsView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var trainManager: TrainManager
    
    @State private var showLogs = false
    @State private var showCredits = false
    @State private var debugContent: DebugContent? = nil
    
    var body: some View {
        Form {
            Section(header: Text("diagnostics".localized)) {
                Button(action: { showLogs = true }) {
                    Label("show_network_logs".localized, systemImage: "list.bullet.rectangle.portrait")
                }
            }
            
            Section(header: Text("info".localized)) {
                Button(action: { showCredits = true }) {
                    Label("credits_author".localized, systemImage: "info.circle")
                }
            }
            
            Section(header: Text("debug_data_json".localized)) {
                Button(action: {
                    showJsonInspector(for: network.lines, title: String(format: "show_json_lines".localized, network.lines.count))
                }) {
                    Label("show_json_lines".localized, systemImage: "curlybraces")
                }
                Button(action: {
                    showJsonInspector(for: trainManager.trains, title: String(format: "show_json_trains".localized, trainManager.trains.count))
                }) {
                    Label("show_json_trains".localized, systemImage: "curlybraces")
                }
            }
        }
        .navigationTitle("diagnostics_and_info".localized)
        .sheet(item: $debugContent) { content in
            NavigationStack {
                ScrollView {
                    Text(content.json)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .textSelection(.enabled)
                }
                .navigationTitle(content.title)
                .toolbar {
                    Button("close".localized) { debugContent = nil }
                }
            }
        }
        .sheet(isPresented: $showLogs) {
            LogViewerSheet()
        }
        .sheet(isPresented: $showCredits) {
            CreditsView()
        }
    }
    
    private func showJsonInspector<T: Encodable>(for data: T, title: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let jsonData = try? encoder.encode(data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            debugContent = DebugContent(title: title, json: jsonString)
        }
    }
}


struct DebugContent: Identifiable {
    let id = UUID()
    let title: String
    let json: String
}
