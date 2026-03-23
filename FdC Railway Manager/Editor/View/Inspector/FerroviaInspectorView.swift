import SwiftUI
import Combine

struct FerroviaInspectorView: View {
    @Binding var ferrovia: Ferrovia
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var network: RailwayNetwork
    
    var onDelete: (() -> Void)?
    var onBack: (() -> Void)?
    
    @State private var isEditingEnabled = true
    
    var body: some View {
        InspectorView(
            title: ferrovia.name,
            icon: "line.3.horizontal",
            iconColor: ferrovia.displayColor,
            onBack: onBack,
            onClose: {
                appState.selectedInfraLineId = nil
                appState.showPanel(.none)
            }
        ) {
            
            basicInfoSection
            routeSection
            altimetricProfileSection
            actionsSection
            
            if onDelete != nil {
                InspectorDeleteButton(
                    label: "delete_ferrovia".localized,
                    onDelete: onDelete ?? {}
                )
            }
        }
    }
    
    private var basicInfoSection: some View {
        InspectorSection(title: "basic_info".localized, icon: "info.circle.fill", iconColor: .blue) {
            VStack(alignment: .leading, spacing: 12) {
                // Name
                HStack {
                    Text("name".localized)
                        .frame(width: 120, alignment: .leading)
                    TextField("ferrovia_name_placeholder".localized, text: $ferrovia.name)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Electrification
                HStack {
                    Text("electrification".localized)
                        .frame(width: 120, alignment: .leading)
                    Picker("", selection: $ferrovia.electrification) {
                        ForEach(ElectrificationType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Color
                HStack {
                    Text("color".localized)
                        .frame(width: 120, alignment: .leading)
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: ferrovia.color ?? "#3498db") ?? .blue },
                        set: { ferrovia.color = $0.toHex() }
                    ))
                }
            }
        }
    }
    
    private var routeSection: some View {
        InspectorSection(title: "route_path".localized, icon: "point.topleft.down.curvedto.point.bottomright.up", iconColor: .orange) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(ferrovia.nodeIds, id: \.self) { stationId in
                    if let node = network.nodes.first(where: { $0.id == stationId }) {
                        HStack(spacing: 12) {
                            // Use NetworkSymbols for consistent station display
                            NetworkSymbols.stationSymbol(for: node, size: 12)
                            
                            Text(node.name ?? node.id)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            // Tap to view station
                            Button(action: {
                                appState.selectedNodeId = stationId
                            }) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundColor(.blue.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if ferrovia.nodeIds.isEmpty {
                    Text("no_stations_in_ferrovia".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
    }
    
    // MARK: - Profilo altimetrico (read-only)

    private var altimetricProfileSection: some View {
        let pts = ferroviaProfilePoints
        return InspectorSection(
            title: "Profilo altimetrico",
            icon: "chart.xyaxis.line",
            iconColor: .teal
        ) {
            if pts.count >= 2 {
                TrackAltitudeChart(profilePoints: pts)
                    .frame(height: 80)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                Text("Modifica le quote nei singoli inspector di binario.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Aggiungi almeno due stazioni con quota per visualizzare il profilo.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// Concatenates the altitude profile of all edges along the ferrovia path.
    private var ferroviaProfilePoints: [(distance: Double, altitude: Double)] {
        let nodeIds = ferrovia.nodeIds
        guard nodeIds.count >= 2 else { return [] }
        var pts: [(Double, Double)] = []
        var cumulativeDistance: Double = 0

        for i in 0 ..< nodeIds.count - 1 {
            let fromId = nodeIds[i]
            let toId   = nodeIds[i + 1]
            guard let fromNode = network.nodes.first(where: { $0.id == fromId }),
                  let edge = network.edges.first(where: {
                      ($0.from == fromId && $0.to == toId) ||
                      ($0.from == toId   && $0.to == fromId)
                  })
            else { continue }

            if pts.isEmpty { pts.append((0, fromNode.altitude ?? 0)) }
            cumulativeDistance += edge.distance
            let toNode = network.nodes.first { $0.id == toId }
            pts.append((cumulativeDistance, toNode?.altitude ?? 0))
        }
        return pts
    }

    private var actionsSection: some View {
        InspectorSection(title: "actions".localized, icon: "bolt.fill", iconColor: .yellow) {
            VStack(spacing: 10) {
                Button(action: {
                    InfrastructureService(network: network).propagateElectrification(to: ferrovia)
                    appState.objectWillChange.send()
                }) {
                    Label("propagate_electrification".localized, systemImage: "bolt.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .help("propagate_electrification_help".localized)
                
                Text("propagate_electrification_description".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
