import Foundation
import SwiftUI

struct FerrovieListPopover: View {

    @EnvironmentObject var appState: AppState
    var onSelect: (Ferrovia) -> Void
    var onCreate: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                Text("Ferrovie")
                    .font(.headline)
                Spacer()
                Button(action: onCreate) {
                    Image(systemName: "plus")
                }
            }
            .padding()
            
            if appState.railroad.network.ferrovie.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Nessuna ferrovia")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Crea una ferrovia per definire un percorso fisico della rete")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List {
                    ForEach(appState.railroad.network.ferrovie) { ferrovia in
                        Button(action: { onSelect(ferrovia) }) {
                           HStack {
                               Circle()
                                   .fill(ferrovia.uiColor)
                                   .frame(width: 8, height: 8)
                               Text(ferrovia.name)
                               Spacer()
                               Text("\(ferrovia.stationIds.count) staz.")
                                   .font(.caption)
                                   .foregroundColor(.secondary)
                           }
                           .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteFerrovia)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(UIColor.systemBackground))
    }
    
    func deleteFerrovia(at offsets: IndexSet) {
        offsets.forEach { index in
            let fer = appState.railroad.network.ferrovie[index]
            if appState.selectedFerroviaId == fer.id {
                appState.selectedFerroviaId = nil
            }
            appState.railroad.network.ferrovie.removeAll { $0.id == fer.id }
        }
    }
}
// MARK: - Ferrovia Inspector List
/// Lista ferrovie per il pannello inspector laterale
struct FerrovieInspectorList: View {
    @EnvironmentObject var appState: AppState
    var onSelect: (Ferrovia) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if appState.railroad.network.ferrovie.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    Text("Nessuna ferrovia")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Seleziona 2 o più stazioni sulla mappa e usa l'icona 'F' per creare una ferrovia")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(appState.railroad.network.ferrovie) { ferrovia in
                            Button(action: {
                                onSelect(ferrovia)
                            }) {
                                HStack(spacing: 12) {
                                    // Color indicator
                                    Circle()
                                        .fill(ferrovia.uiColor)
                                        .frame(width: 12, height: 12)
                                    
                                    // Ferrovia info
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(ferrovia.name)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.primary)
                                        
                                        Text("\(ferrovia.stationIds.count) stazioni")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Arrow indicator
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(UIColor.tertiarySystemBackground))
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(UIColor.systemBackground))
    }
}

