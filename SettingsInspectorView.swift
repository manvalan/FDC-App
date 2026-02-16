import SwiftUI

enum SettingsPage: Equatable {
    case main
    case trainParams
    case visualization
    case aiSettings
    case diagnostics
}

struct SettingsInspectorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var network: NetworkModel
    @EnvironmentObject var trainManager: LinesManager
    @State private var showDeleteConfirmation = false
    @State private var showColorAssignmentConfirmation = false
    @State private var showGrid = true
    @State private var currentPage: SettingsPage = .main
    @State private var navigationStack: [SettingsPage] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Header with Back Button
            if currentPage != .main {
                HStack {
                    Button(action: navigateBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Indietro")
                                .font(.subheadline)
                        }
                        .foregroundColor(appState.theme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(appState.theme.accent.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(appState.theme.backgroundSecondary)
                
                Divider()
                    .background(appState.theme.line.opacity(0.2))
            }
            
            // Content
            ScrollView {
                Group {
                    switch currentPage {
                    case .main:
                        mainSettingsView
                    case .trainParams:
                        TrainTrackParametersView()
                    case .visualization:
                        VisualizationSettingsView(showGrid: $showGrid)
                    case .aiSettings:
                        AISettingsView()
                    case .diagnostics:
                        DiagnosticsSettingsView()
                    }
                }
                .padding()
            }
            .background(appState.theme.background)
        }
        .alert("reset_confirm_title".localized, isPresented: $showDeleteConfirmation) {
            Button("cancel".localized, role: .cancel) { }
            Button("confirm".localized, role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("reset_confirm_message".localized)
        }
        .alert("Assegnazione Colori", isPresented: $showColorAssignmentConfirmation) {
            Button("cancel".localized, role: .cancel) { }
            Button("Assegna", role: .none) {
                assignColorsToAllLines()
            }
        } message: {
            Text("L'algoritmo intelligente assegnerà colori con massimo contrasto alle linee che condividono stazioni, ottimizzando la leggibilità nei nodi complessi come Bywater Pool.")
        }
    }
    
    // MARK: - Navigation
    
    private func navigateTo(_ page: SettingsPage) {
        navigationStack.append(currentPage)
        withAnimation {
            currentPage = page
        }
    }
    
    private func navigateBack() {
        if let previous = navigationStack.popLast() {
            withAnimation {
                currentPage = previous
            }
        }
    }
    
    private var mainSettingsView: some View {
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
            advancedSettingsSectionModern
            
            // Danger Zone
            dangerZoneSection
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
            
            // Theme Preview
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
                showColorAssignmentConfirmation = true
            }) {
                HStack {
                    Image(systemName: "paintpalette.fill")
                        .foregroundColor(appState.theme.accent)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Assegna Colori Automaticamente")
                            .font(.subheadline.bold())
                            .foregroundColor(appState.theme.dark)
                        Text("Massimo contrasto per linee adiacenti")
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
            
            Text("Utilizza un algoritmo intelligente che assegna colori con massima distanza visiva alle linee che condividono stazioni, migliorando la leggibilità nei nodi complessi")
                .font(.caption)
                .foregroundColor(appState.theme.medium)
                .padding(.horizontal, 4)
        }
        .padding()
        .background(appState.theme.backgroundSecondary)
        .cornerRadius(12)
    }
    
    private var advancedSettingsSectionModern: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "slider.horizontal.3", title: "Impostazioni Avanzate")
            
            VStack(spacing: 8) {
                settingsNavigationRowModern(
                    icon: "slider.horizontal.3",
                    title: "train_params".localized,
                    page: .trainParams
                )
                
                Divider()
                    .background(appState.theme.line.opacity(0.1))
                
                settingsNavigationRowModern(
                    icon: "eye",
                    title: "visualization".localized,
                    page: .visualization
                )
                
                Divider()
                    .background(appState.theme.line.opacity(0.1))
                
                settingsNavigationRowModern(
                    icon: "sparkles",
                    title: "railway_ai".localized,
                    page: .aiSettings
                )
                
                Divider()
                    .background(appState.theme.line.opacity(0.1))
                
                settingsNavigationRowModern(
                    icon: "info.circle",
                    title: "diagnostics".localized,
                    page: .diagnostics
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
    
    private func settingsNavigationRowModern(icon: String, title: String, page: SettingsPage) -> some View {
        Button(action: { navigateTo(page) }) {
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
    
    private func resetAllData() {
        network.nodes.removeAll()
        network.edges.removeAll()
        trainManager.trains.removeAll()
        trainManager.lines.removeAll()
        appState.simulator.schedules.removeAll()
        print("🗑️ Tutti i dati sono stati eliminati")
    }
}

// MARK: - Preview Support

#Preview {
    let network = NetworkModel()
    let manager = LinesManager(network: network)
    
    SettingsInspectorView()
        .environmentObject(AppState.shared)
        .environmentObject(network)
        .environmentObject(manager)
}
