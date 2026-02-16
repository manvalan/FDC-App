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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection
                    
                    // Language
                    languageSection
                    
                    // Appearance
                    appearanceSection
                    
                    // Line Management
                    lineManagementSection
                    
                    // Advanced Settings
                    advancedSettingsSection
                    
                    // Danger Zone
                    dangerZoneSection
                }
                .padding()
            }
            .background(appState.theme.background)
            .navigationTitle("settings".localized)
            .navigationBarTitleDisplayMode(.inline)
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
    
    // MARK: - Sections
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "gearshape.fill")
                .font(.largeTitle)
                .foregroundColor(appState.theme.accent)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("settings".localized)
                    .font(.title.bold())
                    .foregroundColor(appState.theme.dark)
                Text("Configura l'applicazione")
                    .font(.subheadline)
                    .foregroundColor(appState.theme.medium)
            }
            
            Spacer()
        }
        .padding()
        .background(appState.theme.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "globe", title: "language".localized)
            
            Picker("language".localized, selection: $appState.currentLanguage) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            
            Text("Cambia la lingua dell'interfaccia")
                .font(.caption)
                .foregroundColor(appState.theme.medium)
        }
        .padding()
        .background(appState.theme.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "paintbrush", title: "Aspetto")
            
            HStack(spacing: 12) {
                ForEach([("Chiaro", FdCTheme.light), ("Scuro", FdCTheme.dark)], id: \.0) { name, theme in
                    Button(action: {
                        withAnimation {
                            appState.theme = theme
                        }
                    }) {
                        VStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Circle().fill(theme.accent).frame(width: 16, height: 16)
                                Circle().fill(theme.dark).frame(width: 16, height: 16)
                                Circle().fill(theme.medium).frame(width: 16, height: 16)
                            }
                            Text(name)
                                .font(.caption.bold())
                                .foregroundColor(appState.theme.dark)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(appState.theme == theme ? appState.theme.accent.opacity(0.1) : appState.theme.surface)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(appState.theme == theme ? appState.theme.accent : appState.theme.line.opacity(0.1), lineWidth: appState.theme == theme ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(appState.theme.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private var lineManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "line.3.horizontal", title: "Gestione Linee")
            
            Button(action: {
                assignColorsToAllLines()
            }) {
                HStack {
                    Image(systemName: "paintpalette.fill")
                        .foregroundColor(appState.theme.accent)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Assegna Colori Automaticamente")
                            .font(.subheadline.bold())
                            .foregroundColor(appState.theme.dark)
                        Text("Colori coordinati per tipo di linea")
                            .font(.caption)
                            .foregroundColor(appState.theme.medium)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(appState.theme.medium)
                }
                .padding()
                .background(appState.theme.surface)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            Text("Assegna automaticamente colori simili a linee con caratteristiche simili (AV, Regionali, IC, Merci)")
                .font(.caption)
                .foregroundColor(appState.theme.medium)
                .padding(.horizontal, 4)
        }
        .padding()
        .background(appState.theme.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "slider.horizontal.3", title: "Impostazioni Avanzate")
            
            VStack(spacing: 8) {
                settingsNavigationRow(
                    icon: "slider.horizontal.3",
                    title: "train_params".localized,
                    destination: AnyView(TrainTrackParametersView())
                )
                
                Divider()
                    .background(appState.theme.line.opacity(0.1))
                
                settingsNavigationRow(
                    icon: "eye",
                    title: "visualization".localized,
                    destination: AnyView(VisualizationSettingsView(showGrid: $showGrid))
                )
                
                Divider()
                    .background(appState.theme.line.opacity(0.1))
                
                settingsNavigationRow(
                    icon: "sparkles",
                    title: "railway_ai".localized,
                    destination: AnyView(AISettingsView())
                )
                
                Divider()
                    .background(appState.theme.line.opacity(0.1))
                
                settingsNavigationRow(
                    icon: "info.circle",
                    title: "diagnostics".localized,
                    destination: AnyView(DiagnosticsSettingsView())
                )
            }
            .padding()
            .background(appState.theme.surface)
            .cornerRadius(8)
        }
        .padding()
        .background(appState.theme.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("danger_zone".localized)
                    .font(.headline)
                    .foregroundColor(appState.theme.dark)
            }
            
            Button(action: {
                showDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("reset_all_data".localized)
                            .font(.subheadline.bold())
                            .foregroundColor(.red)
                        Text("Elimina tutti i dati dell'applicazione")
                            .font(.caption)
                            .foregroundColor(appState.theme.medium)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.05))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(appState.theme.backgroundSecondary)
        .cornerRadius(12)
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(appState.theme.accent)
            Text(title)
                .font(.headline)
                .foregroundColor(appState.theme.dark)
        }
    }
    
    private func settingsNavigationRow(icon: String, title: String, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(appState.theme.accent)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(appState.theme.dark)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(appState.theme.medium)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func assignColorsToAllLines() {
        // Usa l'algoritmo intelligente che evita colori simili per linee adiacenti
        let updatedLines = LineColorAssigner.assignSmartColors(to: trainManager.lines, in: network)
        trainManager.lines = updatedLines
        print("✅ Colori intelligenti assegnati a \(updatedLines.count) linee (massimo contrasto)")
    }
}
