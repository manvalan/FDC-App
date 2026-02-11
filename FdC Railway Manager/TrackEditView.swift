import SwiftUI

struct TrackEditView: View {
    @Binding var edge: Edge
    @EnvironmentObject var network: RailwayNetwork
    var onDelete: () -> Void
    var onBack: () -> Void
    
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirmation = false
    
    private var fromStation: Node? {
        network.nodes.first(where: { $0.id == edge.from })
    }
    
    private var toStation: Node? {
        network.nodes.first(where: { $0.id == edge.to })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Back Button
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title3.bold())
                        .foregroundColor(appState.theme.medium)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Modifica Tratta")
                    .font(.headline)
                    .foregroundColor(appState.theme.dark)
                
                Spacer()
                
                // Invisible spacer to balance the header
                Image(systemName: "chevron.left").font(.title3).opacity(0)
            }
            .padding()
            .background(appState.theme.surface)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Route Info
                    HStack(spacing: 16) {
                        Image(systemName: "tram.fill")
                            .font(.system(size: 24))
                            .foregroundColor(appState.theme.accent)
                            .frame(width: 40, height: 40)
                            .background(appState.theme.accent.opacity(0.1))
                            .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fromStation?.name ?? "Stop \(edge.from)")
                                .font(.subheadline)
                                .foregroundColor(appState.theme.dark)
                            Image(systemName: "arrow.down")
                                .font(.caption2)
                                .foregroundColor(appState.theme.medium)
                                .padding(.leading, 4)
                            Text(toStation?.name ?? "Stop \(edge.to)")
                                .font(.subheadline)
                                .foregroundColor(appState.theme.dark)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(appState.theme.surface)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
                    
                    // Track Type Combo Box
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TIPO BINARIO")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(appState.theme.medium)
                            .padding(.leading, 4)
                        
                        HStack {
                            Menu {
                                Button(action: { updateTrackType(.single) }) {
                                    Label("Binario Singolo", systemImage: "1.circle")
                                }
                                Button(action: { updateTrackType(.double) }) {
                                    Label("Doppio Binario", systemImage: "2.circle")
                                }
                                Button(action: { updateTrackType(.highSpeed) }) {
                                    Label("Alta Velocità", systemImage: "bolt.fill")
                                }
                                Button(action: { updateTrackType(.regional) }) {
                                    Label("Linea Regionale", systemImage: "tram")
                                }
                            } label: {
                                HStack {
                                    trackIcon(for: edge.trackType)
                                    Text(trackLabel(for: edge.trackType))
                                        .foregroundColor(appState.theme.dark)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundColor(appState.theme.medium)
                                }
                                .padding()
                                .background(appState.theme.surface)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(appState.theme.line.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .onChange(of: edge.trackType) { newType in
                        updateCapacity(for: newType)
                    }
                    
                    // Parameters Grid
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PARAMETRI FISICI")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(appState.theme.medium)
                            .padding(.leading, 4)
                        
                        VStack(spacing: 12) {
                            // Distance
                            HStack {
                                Text("Distanza").foregroundColor(appState.theme.dark)
                                Spacer()
                                TextField("0", value: $edge.distance, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.decimalPad)
                                    .frame(width: 80)
                                Text("km").foregroundColor(appState.theme.medium).font(.caption)
                            }
                            Divider()
                            // Max Speed
                            HStack {
                                Text("Vel. Max").foregroundColor(appState.theme.dark)
                                Spacer()
                                TextField("0", value: $edge.maxSpeed, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.numberPad)
                                    .frame(width: 80)
                                Text("km/h").foregroundColor(appState.theme.medium).font(.caption)
                            }
                            Divider()
                            // Capacity
                            HStack {
                                Text("Capacità").foregroundColor(appState.theme.dark)
                                Spacer()
                                TextField("0", value: $edge.capacity, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.numberPad)
                                    .frame(width: 80)
                                Text("t/h").foregroundColor(appState.theme.medium).font(.caption)
                            }
                        }
                        .padding()
                        .background(appState.theme.surface)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
                    }
                    
                    // Danger Zone
                    Button(action: { showDeleteConfirmation = true }) {
                        HStack {
                            Spacer()
                            Text("Elimina Binario")
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                    }
                    .padding(.top, 20)
                }
                .padding(16)
            }
        }
        .background(appState.theme.backgroundSecondary.ignoresSafeArea())
        .alert("Conferma eliminazione", isPresented: $showDeleteConfirmation) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Sei sicuro di voler rimuovere questo binario? La connessione tra le stazioni verrà interrotta.")
        }
    }
    
    private func updateCapacity(for type: Edge.TrackType) {
        switch type {
        case .single: edge.capacity = 6
        case .double: edge.capacity = 24
        case .highSpeed: edge.capacity = 15
        case .regional: edge.capacity = 6 // Slightly higher capacity usually? Kept as per old logic
        }
        
        // Also update speed limits based on global settings if available
        switch type {
        case .single: edge.maxSpeed = Int(appState.singleTrackMaxSpeed)
        case .double: edge.maxSpeed = Int(appState.doubleTrackMaxSpeed)
        case .highSpeed: edge.maxSpeed = Int(appState.highSpeedTrackMaxSpeed)
        case .regional: edge.maxSpeed = Int(appState.regionalTrackMaxSpeed)
        }
    }
    
    private func trackLabel(for type: Edge.TrackType) -> String {
        switch type {
        case .single: return "Binario Singolo"
        case .double: return "Doppio Binario"
        case .highSpeed: return "Alta Velocità"
        case .regional: return "Linea Regionale"
        }
    }
    
    private func trackIcon(for type: Edge.TrackType) -> Image {
        switch type {
        case .single: return Image(systemName: "1.circle")
        case .double: return Image(systemName: "2.circle")
        case .highSpeed: return Image(systemName: "bolt.fill")
        case .regional: return Image(systemName: "tram")
        }
    }
}
