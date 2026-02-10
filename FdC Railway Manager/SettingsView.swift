import SwiftUI
import Combine

struct SettingsView: View {
    @EnvironmentObject var network: NetworkModel
    @EnvironmentObject var trainManager: LinesManager
    @EnvironmentObject var appState: AppState
    @Binding var showGrid: Bool 
    
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var showCredits = false
    @State private var importError: String? = nil
    @State private var showLogs = false
    @State private var showDeleteConfirmation = false
    
    // Debug State
    struct DebugContent: Identifiable {
        let id = UUID()
        let title: String
        let json: String
    }
    @State private var debugContent: DebugContent? = nil
    
    private func showJsonInspector<T: Encodable>(for data: T, title: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        if let jsonData = try? encoder.encode(data), let jsonString = String(data: jsonData, encoding: .utf8) {
             debugContent = DebugContent(title: title, json: jsonString)
        } else {
             debugContent = DebugContent(title: title, json: "Errore serializzazione JSON")
        }
    }
    
    @State private var isTestLoading = false
    @State private var testResultMessage: String?
    @State private var testErrorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("language".localized)) {
                    Picker("language".localized, selection: $appState.currentLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("ai_config".localized)) {
                    NavigationLink(destination: TrainTrackParametersView()) {
                        Label("train_params".localized, systemImage: "slider.horizontal.3")
                    }
                    
                    NavigationLink(destination: VisualizationSettingsView(showGrid: $showGrid)) {
                        Label("visualization".localized, systemImage: "eye")
                    }
                }
                
                Section(header: Text("railway_ai".localized)) {
                    NavigationLink(destination: AISettingsView()) {
                        Label("railway_ai".localized, systemImage: "sparkles")
                    }
                }
                
                Section(header: Text("settings".localized)) {
                    NavigationLink(destination: DiagnosticsSettingsView()) {
                        Label("diagnostics".localized, systemImage: "info.circle")
                    }
                }
                
                Section(header: Text("danger_zone".localized)) {
                    Button(role: .destructive, action: {
                        showDeleteConfirmation = true
                    }) {
                        Label("reset_all_data".localized, systemImage: "trash.fill")
                    }
                }
            }
            .navigationTitle("settings".localized)
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
                        Button("Chiudi") { debugContent = nil }
                    }
                }
            }
            .sheet(isPresented: $showLogs) {
                LogViewerSheet()
            }
            .sheet(isPresented: $showCredits) {
                CreditsView()
            }
            .alert("reset_confirm_title".localized, isPresented: $showDeleteConfirmation) {
                Button("cancel".localized, role: .cancel) { }
                Button("confirm".localized, role: .destructive) {
                    // Reset Logic
                    network.nodes.removeAll()
                    network.edges.removeAll()
                    trainManager.trains.removeAll()
                    appState.simulator.schedules.removeAll()
                }
            } message: {
                Text("reset_confirm_message".localized)
            }
        }
    }
}
