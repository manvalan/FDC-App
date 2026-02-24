import SwiftUI

// MARK: - Track Inspector
struct TrackInspectorView: View {
    @Binding var edge: RailwayEdge
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var loader: AppLoaderService
    
    var onDelete: (() -> Void)?
    var onBack: (() -> Void)?
    
    @State private var isEditingEnabled = false
    
    private var fromStation: RailwayNode? {
        network.nodes.first { $0.id == edge.from }
    }
    
    private var toStation: RailwayNode? {
        network.nodes.first { $0.id == edge.to }
    }
    
    var body: some View {
        InspectorView(
            title: trackTitle,
            icon: "point.topleft.down.curvedto.point.bottomright.up",
            iconColor: .orange,
            onBack: onBack,
            onClose: {
                withAnimation {
                    appState.selectedEdgeId = nil
                }
            }
        ) {
            EditingModeBanner(isEditingEnabled: $isEditingEnabled)
            
            stationsSection
            trackTypeSection
            parametersSection
            
            if onDelete != nil {
                InspectorDeleteButton(label: "delete_track".localized, onDelete: onDelete ?? {})
            }
        }
        .disabled(!isEditingEnabled)
        .onLongPressGesture(minimumDuration: 1.0) {
            isEditingEnabled.toggle()
        }
        .onAppear {
            isEditingEnabled = true
        }
        .onDisappear {
            isEditingEnabled = false
            Task { loader.saveCurrentState() }
        }
    }
    
    // MARK: - Sections
    
    private var trackTitle: String {
        if let from = fromStation, let to = toStation {
            return "\(from.name) → \(to.name)"
        }
        return "track".localized
    }
    
    private var stationsSection: some View {
        InspectorSection(title: "connection".localized, icon: "arrow.left.and.right", iconColor: .blue) {
            VStack(spacing: 12) {
                stationRow(
                    station: fromStation,
                    label: "from".localized,
                    icon: "arrow.up.circle.fill",
                    color: .green
                )
                
                Divider()
                
                stationRow(
                    station: toStation,
                    label: "to".localized,
                    icon: "arrow.down.circle.fill",
                    color: .red
                )
            }
        }
    }
    
    private func stationRow(station: RailwayNode?, label: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(station?.name ?? "unknown".localized)
                    .font(.subheadline.bold())
            }
            
            Spacer()
        }
    }
    
    private var trackTypeSection: some View {
        InspectorSection(title: "track_type".localized, icon: "signpost.right.fill", iconColor: .purple) {
            Picker("type".localized, selection: $edge.trackType) {
                Label("single_track".localized, systemImage: "1.circle").tag(RailwayEdge.TrackType.single)
                Label("double_track".localized, systemImage: "2.circle").tag(RailwayEdge.TrackType.double)
                Label("high_speed_track".localized, systemImage: "bolt.fill").tag(RailwayEdge.TrackType.highSpeed)
                Label("regional_track".localized, systemImage: "tram").tag(RailwayEdge.TrackType.regional)
            }
            .pickerStyle(.menu)
            .onChange(of: edge.trackType) { oldValue, newValue in
                updateParametersForTrackType(newValue)
            }
            
            HStack {
                Image(systemName: trackTypeIcon)
                    .foregroundColor(trackTypeColor)
                Text(trackTypeLabel)
                    .font(.caption)
                Spacer()
            }
            .padding(8)
            .background(trackTypeColor.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private var parametersSection: some View {
        InspectorSection(title: "physical_parameters".localized, icon: "gauge.medium", iconColor: .orange) {
            VStack(spacing: 12) {
                // Distance
                HStack {
                    Text("distance".localized)
                    Spacer()
                    TextField("0", value: $edge.distance, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                    Text("km")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Max Speed
                HStack {
                    Text("max_speed".localized)
                    Spacer()
                    TextField("0", value: $edge.maxSpeed, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                    Text("km/h")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Capacity
                HStack {
                    Text("capacity".localized)
                    Spacer()
                    TextField("0", value: $edge.capacity, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                    Text("t/h")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var trackTypeIcon: String {
        switch edge.trackType {
        case .single: return "1.circle"
        case .double: return "2.circle"
        case .highSpeed: return "bolt.fill"
        case .regional: return "tram"
        }
    }
    
    private var trackTypeLabel: String {
        switch edge.trackType {
        case .single: return "single_track".localized
        case .double: return "double_track".localized
        case .highSpeed: return "high_speed_track".localized
        case .regional: return "regional_track".localized
        }
    }
    
    private var trackTypeColor: Color {
        switch edge.trackType {
        case .single: return .blue
        case .double: return .green
        case .highSpeed: return .purple
        case .regional: return .orange
        }
    }
    
    private func updateParametersForTrackType(_ type: RailwayEdge.TrackType) {
        switch type {
        case .single:
            edge.capacity = 6
            edge.maxSpeed = Int(appState.singleTrackMaxSpeed)
        case .double:
            edge.capacity = 24
            edge.maxSpeed = Int(appState.doubleTrackMaxSpeed)
        case .highSpeed:
            edge.capacity = 15
            edge.maxSpeed = Int(appState.highSpeedTrackMaxSpeed)
        case .regional:
            edge.capacity = 6
            edge.maxSpeed = Int(appState.regionalTrackMaxSpeed)
        }
    }
}
