import SwiftUI
import UIKit

struct TrackInlineEditor: View {
    @Binding var edge: RailwayEdge
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirmation = false
    
    private var fromStation: RailwayNode? {
        appState.railroad.network.nodes.first(where: { $0.id == edge.from })
    }
    
    private var toStation: RailwayNode? {
        appState.railroad.network.nodes.first(where: { $0.id == edge.to })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Quick stats sempre visibili
            VStack(alignment: .leading, spacing: 12) {
                // Stazioni
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
                
                // Tipo Binario
                VStack(alignment: .leading, spacing: 8) {
                    Text("TIPO BINARIO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                        .padding(.leading, 4)
                    
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
                    .disabled(!appState.isInspectorEditingMode && appState.currentMode != .design)
                }
                
                // Parametri Fisici
                VStack(alignment: .leading, spacing: 8) {
                    Text("PARAMETRI FISICI")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                        .padding(.leading, 4)
                    
                    VStack(spacing: 12) {
                        // Distanza
                        HStack {
                            Text("Distanza").foregroundColor(appState.theme.dark)
                            Spacer()
                            TextField("0", value: $edge.distance, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(width: 80)
                                .disabled(!appState.isInspectorEditingMode && appState.currentMode != .design)
                            Text("km").foregroundColor(appState.theme.medium).font(.caption)
                        }
                        Divider()
                        // Velocità Max
                        HStack {
                            Text("Vel. Max").foregroundColor(appState.theme.dark)
                            Spacer()
                            TextField("0", value: $edge.maxSpeed, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                                .frame(width: 80)
                                .disabled(!appState.isInspectorEditingMode && appState.currentMode != .design)
                            Text("km/h").foregroundColor(appState.theme.medium).font(.caption)
                        }
                        Divider()
                        // Capacità
                        HStack {
                            Text("Capacità").foregroundColor(appState.theme.dark)
                            Spacer()
                            TextField("0", value: $edge.capacity, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                                .frame(width: 80)
                                .disabled(!appState.isInspectorEditingMode && appState.currentMode != .design)
                            Text("t/h").foregroundColor(appState.theme.medium).font(.caption)
                        }
                    }
                    .padding()
                    .background(appState.theme.surface)
                    .cornerRadius(12)
                }
                
                // Geometry Points (Punti Intermedi Personalizzati)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("GEOMETRIA PERSONALIZZATA")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(appState.theme.medium)
                            .padding(.leading, 4)
                        
                        Spacer()
                        
                        if appState.isInspectorEditingMode || appState.currentMode == .design {
                            Button(action: addGeometryPoint) {
                                Label("Aggiungi", systemImage: "plus.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(appState.theme.accent)
                            }
                        }
                    }
                    
                    if let points = edge.geometryPoints, !points.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(appState.theme.accent)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Punto \(index + 1)")
                                            .font(.caption.bold())
                                            .foregroundColor(appState.theme.dark)
                                        Text("Lat: \(point.latitude, specifier: "%.6f"), Lon: \(point.longitude, specifier: "%.6f")")
                                            .font(.system(size: 10))
                                            .foregroundColor(appState.theme.medium)
                                    }
                                    
                                    Spacer()
                                    
                                    if appState.isInspectorEditingMode || appState.currentMode == .design {
                                        Button(action: { removeGeometryPoint(at: index) }) {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(appState.theme.surface.opacity(0.5))
                                .cornerRadius(8)
                            }
                        }
                    } else {
                        Text("Nessun punto intermedio. Il percorso viene calcolato automaticamente.")
                            .font(.caption)
                            .foregroundColor(appState.theme.medium)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(appState.theme.surface.opacity(0.3))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(appState.theme.backgroundSecondary)
                .cornerRadius(12)
                
                // Danger Zone (solo in modalità edit o design)
                if appState.isInspectorEditingMode || appState.currentMode == .design {
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
                    .padding(.top, 10)
                }
            }
            
            // Edit mode indicator
            if appState.isInspectorEditingMode || appState.currentMode == .design {
                HStack {
                    Spacer()
                    Text(appState.currentMode == .design ? "Editing Infrastruttura Attivo" : "Modalità Modifica Attiva")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            } else {
                HStack {
                    Spacer()
                    Text("Long press per modificare")
                        .font(.caption2)
                        .foregroundColor(appState.theme.medium)
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(appState.theme.light.opacity(0.3))
                .cornerRadius(8)
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 1.0) {
            appState.isInspectorEditingMode.toggle()
        }
        .alert("Conferma eliminazione", isPresented: $showDeleteConfirmation) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                appState.railroad.network.removeEdge(from: edge.from, to: edge.to)
                appState.selectedEdgeId = nil
            }
        } message: {
            Text("Sei sicuro di voler rimuovere questo binario? La connessione tra le stazioni verrà interrotta.")
        }
    }
    
    private func updateTrackType(_ type: RailwayEdge.TrackType) {
        edge.trackType = type
        updateCapacity(for: type)
    }
    
    private func updateCapacity(for type: RailwayEdge.TrackType) {
        switch type {
        case .single: edge.capacity = 6
        case .double: edge.capacity = 24
        case .highSpeed: edge.capacity = 15
        case .regional: edge.capacity = 6
        }
        
        switch type {
        case .single: edge.maxSpeed = Int(appState.singleTrackMaxSpeed)
        case .double: edge.maxSpeed = Int(appState.doubleTrackMaxSpeed)
        case .highSpeed: edge.maxSpeed = Int(appState.highSpeedTrackMaxSpeed)
        case .regional: edge.maxSpeed = Int(appState.regionalTrackMaxSpeed)
        }
    }
    
    private func trackLabel(for type: RailwayEdge.TrackType) -> String {
        switch type {
        case .single: return "Binario Singolo"
        case .double: return "Doppio Binario"
        case .highSpeed: return "Alta Velocità"
        case .regional: return "Linea Regionale"
        }
    }
    
    private func trackIcon(for type: RailwayEdge.TrackType) -> Image {
        switch type {
        case .single: return Image(systemName: "1.circle")
        case .double: return Image(systemName: "2.circle")
        case .highSpeed: return Image(systemName: "bolt.fill")
        case .regional: return Image(systemName: "tram")
        }
    }
    
    private func addGeometryPoint() {
        // Calculate a midpoint between from and to stations as default
        guard let fromNode = fromStation, let toNode = toStation,
              let fromLat = fromNode.latitude, let fromLon = fromNode.longitude,
              let toLat = toNode.latitude, let toLon = toNode.longitude else { return }
        
        let midLat = (fromLat + toLat) / 2.0
        let midLon = (fromLon + toLon) / 2.0
        
        let newPoint = Edge.GeometryPoint(latitude: midLat, longitude: midLon)
        
        if edge.geometryPoints == nil {
            edge.geometryPoints = []
        }
        edge.geometryPoints?.append(newPoint)
    }
    
    private func removeGeometryPoint(at index: Int) {
        edge.geometryPoints?.remove(at: index)
        if edge.geometryPoints?.isEmpty == true {
            edge.geometryPoints = nil
        }
    }
}
