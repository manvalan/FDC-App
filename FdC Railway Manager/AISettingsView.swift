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
            
            Section(header: Text("ai_api_key_auth".localized)) {
                SecureField("API Key (rw-...)", text: $appState.aiApiKey)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text("ai_get_key_instruction".localized)
                            .font(.caption)
                    } icon: {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ai_step_1".localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("ai_step_2".localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("ai_step_3".localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("ai_step_4".localized)
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
                        Label("ai_open_dashboard".localized, systemImage: "arrow.up.forward.app")
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
                        Text("ai_verify_key".localized)
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
                    self.testErrorMessage = String(format: "ai_key_invalid".localized, error.localizedDescription)
                }
            } receiveValue: { keyInfo in
                self.testResultMessage = String(format: "ai_key_valid_fmt".localized, keyInfo.username, Int(keyInfo.remaining_days))
                
                // Warn if expiring soon
                if keyInfo.remaining_days < 7 {
                    self.testErrorMessage = String(format: "ai_key_expiring_fmt".localized, Int(keyInfo.remaining_days))
                }
            }
            .store(in: &cancellables)
    }
}
