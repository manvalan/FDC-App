import SwiftUI

// MARK: - Generic Entity Creation System
// Sistema generico per creare entità seguendo il pattern: Empty → Building → Details → Save

/// Protocollo per entità creabili con wizard multi-step
protocol CreatableEntity {
    associatedtype BuildingState
    associatedtype DetailsState
    
    static func emptyBuildingState() -> BuildingState
    static func emptyDetailsState() -> DetailsState
    static func create(from building: BuildingState, details: DetailsState) -> Self
}

/// Configurazione del wizard di creazione
struct EntityCreationConfig {
    let entityName: String
    let icon: String
    let emptyStateTitle: String
    let emptyStateMessage: String
    let buildingStateTitle: String
    let confirmButtonTitle: String
    let saveButtonTitle: String
}

/// View generica per la creazione di entità con pattern Empty → Building → Details
struct EntityCreationView<BuildingView: View, DetailsView: View>: View {
    let config: EntityCreationConfig
    let isEmpty: Bool
    let onClose: () -> Void
    
    @ViewBuilder let buildingContent: () -> BuildingView
    @ViewBuilder let detailsContent: () -> DetailsView
    
    @State private var showingDetails: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            if isEmpty {
                emptyStateView
            } else if !showingDetails {
                buildingStateView
            } else {
                detailsStateView
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: config.icon)
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.3))
            
            Text(config.emptyStateTitle)
                .font(.headline)
            
            Text(config.emptyStateMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Building State
    
    private var buildingStateView: some View {
        VStack(spacing: 0) {
            buildingContent()
            
            Divider()
            
            Button(action: { showingDetails = true }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text(config.confirmButtonTitle)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    // MARK: - Details State
    
    private var detailsStateView: some View {
        VStack(spacing: 0) {
            detailsContent()
            
            HStack(spacing: 12) {
                Button(action: { showingDetails = false }) {
                    Text("back".localized)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}

// MARK: - Entity Creation Coordinator
// Coordina la creazione di diverse entità usando lo stesso pattern

enum CreationEntityType {
    case station
    case track
    case train
    case vehicle
    case line
}

struct EntityCreationCoordinator: View {
    @EnvironmentObject var appState: AppState
    let entityType: CreationEntityType
    
    var body: some View {
        switch entityType {
        case .station:
            StationCreationWizard()
        case .track:
            TrackCreationWizard()
        case .train:
            TrainCreationWizard()
        case .vehicle:
            VehicleCreationWizard()
        case .line:
            LineCreationInspectorView()
        }
    }
}

// MARK: - Station Creation Wizard

struct StationCreationWizard: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var network: RailwayNetwork
    
    @State private var stationName: String = ""
    @State private var stationType: Node.NodeType = .station
    @State private var platforms: Int = 2
    @State private var latitude: Double = 0.0
    @State private var longitude: Double = 0.0
    @State private var isPlacingOnMap: Bool = false
    
    private var hasPosition: Bool {
        latitude != 0.0 || longitude != 0.0 || isPlacingOnMap
    }
    
    var body: some View {
        EntityCreationView(
            config: EntityCreationConfig(
                entityName: "station".localized,
                icon: "building.2.fill",
                emptyStateTitle: "tap_map_to_place_station".localized,
                emptyStateMessage: "station_creation_hint".localized,
                buildingStateTitle: "place_station".localized,
                confirmButtonTitle: "confirm_position".localized,
                saveButtonTitle: "create_station".localized
            ),
            isEmpty: !hasPosition,
            onClose: {
                // appState.isCreatingStation = false
            },
            buildingContent: {
                buildingView
            },
            detailsContent: {
                detailsView
            }
        )
        .onAppear {
            setupMapPicking()
        }
        .onDisappear {
            cleanupMapPicking()
        }
    }
    
    private var buildingView: some View {
        VStack(spacing: 16) {
            if isPlacingOnMap {
                VStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("position_selected".localized)
                        .font(.headline)
                    
                    Text(String(format: "coordinates_fmt".localized, latitude, longitude))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding()
            }
        }
    }
    
    private var detailsView: some View {
        Form {
            Section(header: Text("station_details".localized)) {
                TextField("station_name".localized, text: $stationName)
                
                Picker("functional_type".localized, selection: $stationType) {
                    Text("standard_station".localized).tag(Node.NodeType.station)
                    Text("interchange".localized).tag(Node.NodeType.interchange)
                    Text("depot".localized).tag(Node.NodeType.depot)
                }
                .pickerStyle(.segmented)
                
                Stepper(value: $platforms, in: 1...20) {
                    HStack {
                        Text("platform_count".localized)
                        Spacer()
                        Text("\(platforms)")
                            .foregroundColor(.secondary)
                            .fontWeight(.bold)
                    }
                }
            }
            
            Section {
                Button(action: saveStation) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("create_station".localized)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .disabled(stationName.isEmpty)
            }
        }
    }
    
    private func setupMapPicking() {
        appState.stationPickingCallback = { _ in }
        // Implementare logica di picking dalla mappa
    }
    
    private func cleanupMapPicking() {
        appState.stationPickingCallback = nil
    }
    
    private func saveStation() {
        let newStation = Node(
            id: UUID().uuidString,
            name: stationName,
            type: stationType,
            visualType: nil,
            customColor: nil,
            latitude: latitude,
            longitude: longitude,
            platforms: platforms,
            parentHubId: nil,
            hubOffsetDirection: nil
        )
        
        network.nodes.append(newStation)
        // appState.isCreatingStation = false
    }
}

// MARK: - Track Creation Wizard

struct TrackCreationWizard: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var network: RailwayNetwork
    
    @State private var fromStationId: String? = nil
    @State private var toStationId: String? = nil
    
    private var hasSelection: Bool {
        fromStationId != nil && toStationId != nil
    }
    
    var body: some View {
        EntityCreationView(
            config: EntityCreationConfig(
                entityName: "track".localized,
                icon: "point.topleft.down.curvedto.point.bottomright.up",
                emptyStateTitle: "select_two_stations".localized,
                emptyStateMessage: "track_creation_hint".localized,
                buildingStateTitle: "selected_stations".localized,
                confirmButtonTitle: "confirm_track".localized,
                saveButtonTitle: "create_track".localized
            ),
            isEmpty: !hasSelection,
            onClose: {
                appState.isCreatingTrack = false
            },
            buildingContent: {
                TrackCreationBuildingView(
                    fromStationId: $fromStationId,
                    toStationId: $toStationId
                )
            },
            detailsContent: {
                TrackCreationDetailsView(
                    fromStationId: fromStationId ?? "",
                    toStationId: toStationId ?? ""
                )
            }
        )
    }
}

struct TrackCreationBuildingView: View {
    @EnvironmentObject var network: RailwayNetwork
    @Binding var fromStationId: String?
    @Binding var toStationId: String?
    
    var body: some View {
        VStack(spacing: 16) {
            stationSelectionCard(
                title: "from_station".localized,
                stationId: fromStationId,
                icon: "arrow.up.circle.fill",
                color: .green
            )
            
            Image(systemName: "arrow.down")
                .foregroundColor(.secondary)
            
            stationSelectionCard(
                title: "to_station".localized,
                stationId: toStationId,
                icon: "arrow.down.circle.fill",
                color: .red
            )
        }
        .padding()
    }
    
    private func stationSelectionCard(title: String, stationId: String?, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            if let id = stationId, let station = network.nodes.first(where: { $0.id == id }) {
                Text(station.name)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("tap_on_map".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct TrackCreationDetailsView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var appState: AppState
    
    let fromStationId: String
    let toStationId: String
    
    @State private var trackType: Edge.TrackType = .single
    @State private var distance: Double = 0.0
    @State private var maxSpeed: Int = 120
    @State private var capacity: Int = 6
    
    var body: some View {
        Form {
            Section(header: Text("track_properties".localized)) {
                Picker("track_type".localized, selection: $trackType) {
                    Label("single_track".localized, systemImage: "1.circle").tag(Edge.TrackType.single)
                    Label("double_track".localized, systemImage: "2.circle").tag(Edge.TrackType.double)
                    Label("high_speed_track".localized, systemImage: "bolt.fill").tag(Edge.TrackType.highSpeed)
                    Label("regional_track".localized, systemImage: "tram").tag(Edge.TrackType.regional)
                }
                
                HStack {
                    Text("distance".localized)
                    Spacer()
                    TextField("0", value: $distance, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                    Text("km")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("max_speed".localized)
                    Spacer()
                    TextField("0", value: $maxSpeed, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                    Text("km/h")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("capacity".localized)
                    Spacer()
                    TextField("0", value: $capacity, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                    Text("t/h")
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                Button(action: saveTrack) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("create_track".localized)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
        .onAppear {
            calculateDistance()
            updateParametersForTrackType(trackType)
        }
        .onChange(of: trackType) { _, newValue in
            updateParametersForTrackType(newValue)
        }
    }
    
    private func calculateDistance() {
        // Calcola distanza tra le stazioni se hanno coordinate GPS
    }
    
    private func updateParametersForTrackType(_ type: Edge.TrackType) {
        switch type {
        case .single:
            capacity = 6
            maxSpeed = Int(appState.singleTrackMaxSpeed)
        case .double:
            capacity = 24
            maxSpeed = Int(appState.doubleTrackMaxSpeed)
        case .highSpeed:
            capacity = 15
            maxSpeed = Int(appState.highSpeedTrackMaxSpeed)
        case .regional:
            capacity = 6
            maxSpeed = Int(appState.regionalTrackMaxSpeed)
        }
    }
    
    private func saveTrack() {
        let newEdge = Edge(
            id: UUID(),
            from: fromStationId,
            to: toStationId,
            distance: distance,
            trackType: trackType,
            maxSpeed: maxSpeed,
            capacity: capacity
        )
        
        network.edges.append(newEdge)
        appState.isCreatingTrack = false
    }
}

// MARK: - Train & Vehicle Creation Wizards (Placeholder)

struct TrainCreationWizard: View {
    var body: some View {
        Text("Train Creation Wizard - TODO")
    }
}

struct VehicleCreationWizard: View {
    var body: some View {
        Text("Vehicle Creation Wizard - TODO")
    }
}
