import SwiftUI
import Combine

struct AISettingsView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var isTestLoading = false
    @State private var testResultMessage: String? = nil
    @State private var testErrorMessage: String? = nil
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        Form {
            Section(header: Text("server_config".localized)) {
                HStack {
                    TextField("api_base_url".localized, text: $appState.aiEndpoint)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button(action: {
                        appState.aiEndpoint = "https://railway-ai.michelebigi.it"
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("restore_default_url".localized)
                }
            }
            
            Section(header: Text("API Key Authentication")) {
                SecureField("API Key (rw-...)", text: $appState.aiApiKey)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("Per ottenere la tua API Key:")
                            .font(.caption)
                    } icon: {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Vai su https://railway-ai.michelebigi.it/static/index.html")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("2. Effettua il login con le tue credenziali")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("3. Copia la tua API Key dalla dashboard")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("4. Incollala nel campo sopra")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 24)
                    
                    Button(action: {
                        if let url = URL(string: "https://railway-ai.michelebigi.it/static/index.html") {
                            #if os(macOS)
                            NSWorkspace.shared.open(url)
                            #else
                            UIApplication.shared.open(url)
                            #endif
                        }
                    }) {
                        Label("Apri Railway AI Dashboard", systemImage: "arrow.up.forward.app")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("authentication".localized)) {
                Button(action: testConnection) {
                    if isTestLoading {
                        ProgressView()
                    } else {
                        Text("Verifica API Key")
                    }
                }
                .disabled(isTestLoading || appState.aiApiKey.isEmpty)
                
                if let result = testResultMessage {
                    Text(result).foregroundColor(.green).font(.caption)
                }
                if let error = testErrorMessage {
                    Text(error).foregroundColor(.red).font(.caption)
                }
            }
        }
        .navigationTitle("railway_ai".localized)
    }
    
    private func testConnection() {
        isTestLoading = true
        testResultMessage = nil
        testErrorMessage = nil
        
        // Test API Key validity by calling /api/v1/key-info
        RailwayAIService.shared.syncCredentials(
            endpoint: appState.aiEndpoint,
            apiKey: appState.aiApiKey,
            token: nil
        )
        
        RailwayAIService.shared.checkKeyStatus()
            .sink { completion in
                self.isTestLoading = false
                if case .failure(let error) = completion {
                    self.testErrorMessage = "API Key non valida: \(error.localizedDescription)"
                }
            } receiveValue: { keyInfo in
                self.testResultMessage = "✓ API Key valida - Utente: \(keyInfo.username) - Scadenza: \(Int(keyInfo.remaining_days)) giorni"
                
                // Warn if expiring soon
                if keyInfo.remaining_days < 7 {
                    self.testErrorMessage = "⚠️ Attenzione: La chiave scade tra \(Int(keyInfo.remaining_days)) giorni!"
                }
            }
            .store(in: &cancellables)
    }
}
