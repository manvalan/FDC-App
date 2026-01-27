import SwiftUI

struct CreditsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Header with Larger Splash Image
                    VStack {
                        Image("SplashImage")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 400)
                            .shadow(radius: 10)
                        
                        Text("FdC Railway Manager")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .padding(.top, 10)
                    }
                    .padding(.top, 40)
                    
                    VStack(spacing: 15) {
                        Text("Sviluppato da")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Michele Bigi")
                            .font(.title2.bold())
                        
                        Divider()
                            .padding(.horizontal, 60)
                        
                        Text("Versione 1.2.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Informazioni sul Progetto")
                            .font(.title3.bold())
                        
                        Text("FdC Railway Manager è uno strumento avanzato per la gestione, simulazione e ottimizzazione di reti ferroviarie locali. Integra algoritmi di pathfinding, rilevamento conflitti e intelligenza artificiale per garantire orari efficienti e sicuri.")
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(5)
                        
                        Text("Tecnologie utilizzate:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            labelPair(icon: "swift", title: "SwiftUI", description: "Interfaccia Reattiva")
                            labelPair(icon: "brain.head.profile", title: "RailwayAI", description: "Ottimizzazione via ML")
                            labelPair(icon: "map.fill", title: "MapKit", description: "Visualizzazione Geografica")
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer(minLength: 50)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Credits")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func labelPair(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 25)
            VStack(alignment: .leading) {
                Text(title).bold()
                Text(description).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    CreditsView()
}
