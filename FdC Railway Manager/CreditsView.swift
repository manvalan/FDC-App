import SwiftUI
import Combine

struct CreditsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Header Section
                Section {
                    VStack(spacing: 20) {
                        Image("SplashImage") // Ensure this asset exists, or use a system placeholder if unsure
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .shadow(radius: 8)
                            .padding(.vertical, 10)
                        
                        Text("FdC Railway Manager")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        Text("Gestione avanzata e simulazione\ndel traffico ferroviario")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                
                // Developer Section
                Section("Sviluppo") {
                    HStack {
                        Text("Progettato e Sviluppato da")
                        Spacer()
                        Text("Michele Bigi")
                            .bold()
                            .foregroundStyle(.primary)
                    }
                    HStack {
                        Text("Versione")
                        Spacer()
                        Text("1.2.0")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Technologies Section
                Section(header: Text("Tecnologie Utilizzate"), footer: Text("L'architettura unisce la potenza nativa di Swift con l'intelligenza di Python.")) {
                    technologyRow(name: "SwiftUI & Combine", icon: "swift", color: .orange)
                    technologyRow(name: "Python Backend", icon: "server.rack", color: .blue)
                    technologyRow(name: "Overpass API", icon: "map", color: .green)
                    technologyRow(name: "TorchScript & PyTorch", icon: "brain.head.profile", color: .purple)
                }
                
                // Links Section
                Section("Informazioni Legali") {
                    Link(destination: URL(string: "https://railway-ai.michelebigi.it")!) {
                        Label("Railway-AI Portal", systemImage: "globe")
                    }
                    
                    Link(destination: URL(string: "https://railway-ai.michelebigi.it/disclaimer")!) { // Assuming disclaimer path
                        Label("Disclaimer & Termini", systemImage: "exclamationmark.shield")
                    }
                }
                
                Section {
                    Text("Questa applicazione utilizza dati geografici e ferroviari a scopo dimostrativo e di simulazione. L'uso dell'Intelligenza Artificiale per l'ottimizzazione è sperimentale.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
    
    private func technologyRow(name: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(name)
                .font(.body)
        }
    }
}

#Preview {
    CreditsView()
}
