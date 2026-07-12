import SwiftUI
import UIKit

struct StationInlineEditor: View {
    @Binding var node: Node
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    
    @State private var localPlatforms: Int = 2
    @State private var latitudeText: String = ""
    @State private var longitudeText: String = ""
    @State private var isEditingCoordinates: Bool = false
    
    private var availableHubs: [RailwayNode] {
        appState.railroad.network.nodes
            .filter { $0.id != node.id && $0.parentHubId == nil }
            .sorted { $0.name < $1.name }
    }

    private var hubTopology: HubTopology {
        HubTopology(nodes: appState.railroad.network.nodes)
    }

    private var canCreateAVSatellite: Bool {
        node.parentHubId == nil && hubTopology.avSatellite(for: node.id) == nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 24))
                    .foregroundColor(appState.theme.accent)
                    .frame(width: 40, height: 40)
                    .background(appState.theme.accent.opacity(0.1))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.name)
                        .font(.headline)
                        .foregroundColor(appState.theme.dark)
                    Text(node.type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(appState.theme.medium)
                }
                Spacer()
            }
            .padding()
            .background(appState.theme.surface)
            .cornerRadius(12)
            
            // Quick Stats (always visible)
            VStack(alignment: .leading, spacing: 10) {
                CompactInfoRow(label: "Binari", value: "\(node.platforms ?? 1)")
                CompactInfoRow(label: "Capacità", value: "\(node.capacity ?? 10) treni")
                if let hub = node.parentHubId {
                    CompactInfoRow(label: "Hub", value: appState.railroad.network.nodes.first(where: { $0.id == hub })?.name ?? hub)
                }
                if let lat = node.latitude, let lon = node.longitude {
                    CompactInfoRow(label: "Coordinate", value: String(format: "%.4f, %.4f", lat, lon))
                }
            }
            .padding()
            .background(appState.theme.light.opacity(0.3))
            .cornerRadius(10)
            
            // Edit mode toggle hint - Solo se NON siamo in modalità Design
            if !appState.isInspectorEditingMode && appState.currentMode != .design {
                HStack {
                    Image(systemName: "hand.tap.fill")
                        .foregroundColor(appState.theme.accent)
                    Text("Tieni premuto per 1 secondo per modificare")
                        .font(.caption)
                        .foregroundColor(appState.theme.medium)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(appState.theme.accent.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Editable fields (only when edit mode is active)
            Group {
                // Station Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("NOME STAZIONE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                    TextField("Nome", text: $node.name)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Type
                VStack(alignment: .leading, spacing: 6) {
                    Text("TIPO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                    Picker("Tipo", selection: $node.type) {
                        Text("Stazione").tag(RailwayNode.NodeType.station)
                        Text("Interscambio").tag(RailwayNode.NodeType.interchange)
                        Text("Deposito").tag(RailwayNode.NodeType.depot)
                        Text("Bivio").tag(RailwayNode.NodeType.junction)
                    }
                    .pickerStyle(.segmented)
                }
                
                // Visual Symbol
                VStack(alignment: .leading, spacing: 6) {
                    Text("SIMBOLO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                    Picker("Simbolo", selection: $node.visualType) {
                        Text("Default").tag(RailwayNode.StationVisualType?.none)
                        ForEach(RailwayNode.StationVisualType.allCases) { type in
                            Text(type.rawValue).tag(RailwayNode.StationVisualType?.some(type))
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Custom Color
                VStack(alignment: .leading, spacing: 6) {
                    Text("COLORE PERSONALIZZATO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                    
                    HStack(spacing: 12) {
                        // Color preview
                        if let colorHex = node.customColor, let color = Color(hex: colorHex) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(appState.theme.line, lineWidth: 1)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(appState.theme.light)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(appState.theme.line, lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Hex color (es: #FF5733)", text: Binding(
                                get: { node.customColor ?? "" },
                                set: { newValue in
                                    node.customColor = newValue.isEmpty ? nil : newValue
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            
                            // Quick color presets
                            HStack(spacing: 6) {
                                ForEach(["#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#007AFF", "#5856D6", "#AF52DE"], id: \.self) { colorHex in
                                    if let color = Color(hex: colorHex) {
                                        Button(action: {
                                            node.customColor = colorHex
                                        }) {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 28, height: 28)
                                                .overlay(
                                                    Circle()
                                                        .stroke(node.customColor == colorHex ? appState.theme.accent : Color.clear, lineWidth: 2)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    
                    if node.customColor != nil {
                        Button(action: {
                            node.customColor = nil
                        }) {
                            Text("Rimuovi colore personalizzato")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Platforms
                VStack(alignment: .leading, spacing: 6) {
                    Text("BINARI")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                    Stepper(value: $localPlatforms, in: 1...20) {
                        HStack {
                            Text("Numero di binari")
                                .foregroundColor(appState.theme.dark)
                            Spacer()
                            Text("\(localPlatforms)")
                                .fontWeight(.bold)
                                .foregroundColor(appState.theme.accent)
                        }
                    }
                    .onChange(of: localPlatforms) { _, newValue in
                        node.platforms = newValue
                    }
                }
                
                // Taktfahrplan Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("ORARIO TIPO (TAKTMORE)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                    
                    Text("Convergenza oraria - garantisce corrispondenze tra linee")
                        .font(.caption2)
                        .foregroundColor(appState.theme.medium)
                    
                    Picker("Minuto Takt", selection: $node.taktMinutes) {
                        Text("Off").tag(Int?.none)
                        Text(":00").tag(Int?.some(0))
                        Text(":15").tag(Int?.some(15))
                        Text(":30").tag(Int?.some(30))
                        Text(":45").tag(Int?.some(45))
                    }
                    .pickerStyle(.segmented)
                }
                .padding(10)
                .background(appState.theme.accent.opacity(0.05))
                .cornerRadius(10)
                
                // Hub
                VStack(alignment: .leading, spacing: 6) {
                    Text("HUB AV / CLASSICO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                    Text("L'hub unisce la stazione classica (centro) e la stazione AV (offset). I binari AV collegano i satelliti.")
                        .font(.caption2)
                        .foregroundColor(appState.theme.medium)

                    if node.parentHubId != nil {
                        Picker("Stazione classica", selection: $node.parentHubId) {
                            Text("Nessun Hub").tag(String?.none)
                            ForEach(availableHubs) { hub in
                                Text(hub.name).tag(String?.some(hub.id))
                            }
                        }
                    } else if canCreateAVSatellite {
                        Button {
                            if let satellite = appState.railroad.addHubAVSatellite(for: node.id) {
                                appState.selectedNodeId = satellite.id
                            }
                        } label: {
                            Label("Crea stazione AV satellite", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    } else if let satellite = hubTopology.avSatellite(for: node.id) {
                        CompactInfoRow(label: "Satellite AV", value: satellite.name)
                    }
                }

                // Hub Offset (satellite AV o stazione collegata a hub)
                if node.parentHubId != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("POSIZIONE NELL'HUB")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(appState.theme.medium)
                        Picker("Posizione", selection: $node.hubOffsetDirection) {
                            Text("Standard").tag(RailwayNode.HubOffsetDirection?.none)
                            ForEach(RailwayNode.HubOffsetDirection.allCases) { dir in
                                Text(dir.localizedName).tag(RailwayNode.HubOffsetDirection?.some(dir))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                // Coordinates
                VStack(alignment: .leading, spacing: 6) {
                    Text("COORDINATE GPS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(appState.theme.medium)
                    
                    HStack {
                        Text("Lat").font(.caption).foregroundColor(appState.theme.medium).frame(width: 30, alignment: .leading)
                        TextField("0.0", text: $latitudeText)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numbersAndPunctuation)
                            .onSubmit {
                                if let value = Double(latitudeText) {
                                    node.latitude = value
                                }
                            }
                    }
                    
                    HStack {
                        Text("Lon").font(.caption).foregroundColor(appState.theme.medium).frame(width: 30, alignment: .leading)
                        TextField("0.0", text: $longitudeText)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numbersAndPunctuation)
                            .onSubmit {
                                if let value = Double(longitudeText) {
                                    node.longitude = value
                                }
                            }
                    }
                    
                    Text("Puoi anche trascinare la stazione sulla mappa (long press)")
                        .font(.caption)
                        .foregroundColor(appState.theme.medium)
                }
            }
            .disabled(!appState.isInspectorEditingMode && appState.currentMode != .design)
            .opacity((appState.isInspectorEditingMode || appState.currentMode == .design) ? 1 : 0.5)
        }
        .onAppear {
            localPlatforms = node.platforms ?? 2
            if let lat = node.latitude {
                latitudeText = String(lat)
            }
            if let lon = node.longitude {
                longitudeText = String(lon)
            }
        }
        .onChange(of: node.id) { _, _ in
            // Refresh when station changes
            if let lat = node.latitude {
                latitudeText = String(lat)
            }
            if let lon = node.longitude {
                longitudeText = String(lon)
            }
        }
        .onLongPressGesture(minimumDuration: 1.0) {
            appState.isInspectorEditingMode.toggle()
        }
    }
}
