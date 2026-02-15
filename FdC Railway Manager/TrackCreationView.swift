import SwiftUI
import CoreLocation

struct TrackCreationView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var network: RailwayNetwork
    
    @State private var fromStationId: String = ""
    @State private var toStationId: String = ""
    @State private var trackType: Edge.TrackType = .single
    @State private var distance: Double = 0.0
    @State private var maxSpeed: Int = 120
    @State private var capacity: Int = 6
    @State private var isDistanceManuallySet: Bool = false
    
    var onBack: () -> Void
    var onCreate: () -> Void
    
    private var canCreate: Bool {
        !fromStationId.isEmpty && !toStationId.isEmpty && fromStationId != toStationId
    }
    
    private var fromStation: Node? {
        network.nodes.first(where: { $0.id == fromStationId })
    }
    
    private var toStation: Node? {
        network.nodes.first(where: { $0.id == toStationId })
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
                
                Text("Nuovo Binario")
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
                    
                    // Station Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("STAZIONI")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(appState.theme.medium)
                            .padding(.leading, 4)
                        
                        // From Station
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Stazione di partenza")
                                .font(.caption)
                                .foregroundColor(appState.theme.medium)
                            
                            if let from = fromStation {
                                HStack {
                                    Image(systemName: "building.2.fill")
                                        .foregroundColor(appState.theme.accent)
                                    Text(from.name)
                                        .foregroundColor(appState.theme.dark)
                                    Spacer()
                                    Button(action: { 
                                        fromStationId = ""
                                        isDistanceManuallySet = false
                                        if toStationId.isEmpty {
                                            distance = 0.0
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(appState.theme.medium)
                                    }
                                }
                                .padding()
                                .background(appState.theme.accent.opacity(0.1))
                                .cornerRadius(10)
                            } else {
                                Menu {
                                    ForEach(network.nodes.sorted(by: { $0.name < $1.name })) { node in
                                        Button(action: { fromStationId = node.id }) {
                                            Text(node.name)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "building.2")
                                            .foregroundColor(appState.theme.medium)
                                        Text("Seleziona o clicca sulla mappa")
                                            .foregroundColor(appState.theme.medium)
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
                        
                        // Arrow
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.down")
                                .foregroundColor(appState.theme.medium)
                            Spacer()
                        }
                        
                        // To Station
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Stazione di arrivo")
                                .font(.caption)
                                .foregroundColor(appState.theme.medium)
                            
                            if let to = toStation {
                                HStack {
                                    Image(systemName: "building.2.fill")
                                        .foregroundColor(appState.theme.accent)
                                    Text(to.name)
                                        .foregroundColor(appState.theme.dark)
                                    Spacer()
                                    Button(action: { 
                                        toStationId = ""
                                        isDistanceManuallySet = false
                                        if fromStationId.isEmpty {
                                            distance = 0.0
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(appState.theme.medium)
                                    }
                                }
                                .padding()
                                .background(appState.theme.accent.opacity(0.1))
                                .cornerRadius(10)
                            } else {
                                Menu {
                                    ForEach(network.nodes.filter({ $0.id != fromStationId }).sorted(by: { $0.name < $1.name })) { node in
                                        Button(action: { toStationId = node.id }) {
                                            Text(node.name)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "building.2")
                                            .foregroundColor(appState.theme.medium)
                                        Text("Seleziona o clicca sulla mappa")
                                            .foregroundColor(appState.theme.medium)
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
                    }
                    .padding()
                    .background(appState.theme.surface)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
                    
                    // Track Type Selection
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
                                    trackIcon(for: trackType)
                                    Text(trackLabel(for: trackType))
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
                    
                    // Parameters Grid
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PARAMETRI FISICI")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(appState.theme.medium)
                            .padding(.leading, 4)
                        
                        VStack(spacing: 12) {
                            // Distance
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Distanza").foregroundColor(appState.theme.dark)
                                    Spacer()
                                    TextField("0", value: $distance, format: .number)
                                        .multilineTextAlignment(.trailing)
                                        .keyboardType(.decimalPad)
                                        .frame(width: 80)
                                        .onChange(of: distance) { oldValue, newValue in
                                            // Mark as manually set if user changes it
                                            if oldValue != newValue && newValue != 0 {
                                                isDistanceManuallySet = true
                                            }
                                        }
                                    Text("km").foregroundColor(appState.theme.medium).font(.caption)
                                }
                                
                                // Info message when distance is auto-calculated or GPS unavailable
                                if !fromStationId.isEmpty && !toStationId.isEmpty {
                                    if let from = fromStation, let to = toStation {
                                        if from.coordinate != nil && to.coordinate != nil {
                                            Text("Distanza calcolata automaticamente da GPS")
                                                .font(.system(size: 9))
                                                .foregroundColor(appState.theme.medium.opacity(0.8))
                                        } else {
                                            Text("⚠️ Coordinate GPS mancanti, inserisci manualmente")
                                                .font(.system(size: 9))
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                            }
                            Divider()
                            // Max Speed
                            HStack {
                                Text("Vel. Max").foregroundColor(appState.theme.dark)
                                Spacer()
                                TextField("0", value: $maxSpeed, format: .number)
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
                                TextField("0", value: $capacity, format: .number)
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
                    
                    // Create Button
                    Button(action: createTrack) {
                        HStack {
                            Spacer()
                            Text("Crea Binario")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding()
                        .background(canCreate ? appState.theme.accent : appState.theme.light)
                        .foregroundColor(canCreate ? .white : appState.theme.medium)
                        .cornerRadius(10)
                    }
                    .disabled(!canCreate)
                    .padding(.top, 20)
                }
                .padding(16)
            }
        }
        .background(appState.theme.backgroundSecondary.ignoresSafeArea())
        .onAppear {
            updateTrackType(.single)
        }
        // Listen for station selections from map
        .onChange(of: appState.selectedNodeId) { oldId, newId in
            if let nodeId = newId, appState.isCreatingTrack {
                if fromStationId.isEmpty {
                    fromStationId = nodeId
                } else if toStationId.isEmpty && nodeId != fromStationId {
                    toStationId = nodeId
                }
            }
        }
        // Auto-calculate distance when both stations are selected
        .onChange(of: fromStationId) { oldValue, newValue in
            if !newValue.isEmpty && !toStationId.isEmpty && !isDistanceManuallySet {
                calculateDistance()
            }
        }
        .onChange(of: toStationId) { oldValue, newValue in
            if !newValue.isEmpty && !fromStationId.isEmpty && !isDistanceManuallySet {
                calculateDistance()
            }
        }
    }
    
    private func updateTrackType(_ type: Edge.TrackType) {
        trackType = type
        
        // Update capacity based on type
        switch type {
        case .single: capacity = 6
        case .double: capacity = 24
        case .highSpeed: capacity = 15
        case .regional: capacity = 6
        }
        
        // Update speed limits based on global settings
        switch type {
        case .single: maxSpeed = Int(appState.singleTrackMaxSpeed)
        case .double: maxSpeed = Int(appState.doubleTrackMaxSpeed)
        case .highSpeed: maxSpeed = Int(appState.highSpeedTrackMaxSpeed)
        case .regional: maxSpeed = Int(appState.regionalTrackMaxSpeed)
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
    
    private func calculateDistance() {
        guard let from = fromStation, let to = toStation else { return }
        guard let fromCoord = from.coordinate, let toCoord = to.coordinate else { return }
        
        // Calculate distance using Haversine formula
        let fromLocation = CLLocation(latitude: fromCoord.latitude, longitude: fromCoord.longitude)
        let toLocation = CLLocation(latitude: toCoord.latitude, longitude: toCoord.longitude)
        let distanceInMeters = fromLocation.distance(from: toLocation)
        let distanceInKm = distanceInMeters / 1000.0
        
        // Round to 1 decimal place
        distance = round(distanceInKm * 10) / 10
    }
    
    private func createTrack() {
        guard canCreate else { return }
        
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
        appState.selectedEdgeId = newEdge.id.uuidString
        onCreate()
    }
}
