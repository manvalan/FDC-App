import SwiftUI
 
 /// Inspector per i binari (Archi della rete).
 /// Permette di modificare parametri fisici e tracciamento.

// MARK: - Track Inspector
struct TrackInspectorView: View {
    @Binding var edge: RailwayEdge
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var loader: AppLoaderService
    
    var onDelete: (() -> Void)?
    var onBack: (() -> Void)?
    
    @State private var isEditingEnabled = false
    @State private var showProfileSheet = false
    @State private var showPairedDeleteConfirmation = false
    
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
            stationsSection
            trackTypeSection
            parametersSection
            altimetricProfileSection

            if onDelete != nil {
                if edge.pairedEdgeId != nil {
                    InspectorDeleteButton(
                        label: "delete_track".localized,
                        onDelete: { showPairedDeleteConfirmation = true }
                    )
                } else {
                    InspectorDeleteButton(label: "delete_track".localized, onDelete: onDelete ?? {})
                }
            }
        }
        .sheet(isPresented: $showProfileSheet) {
            TrackProfileSheet(edge: $edge)
        }
        .confirmationDialog(
            "Binario in doppio tracciato",
            isPresented: $showPairedDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Elimina entrambi i binari", role: .destructive) {
                appState.railroad.removeEdge(edge.id, includingPaired: true)
                onDelete?()
            }
            Button("Elimina solo questo", role: .destructive) {
                appState.railroad.removeEdge(edge.id, includingPaired: false)
                onDelete?()
            }
            Button("Annulla", role: .cancel) { }
        } message: {
            Text("Questo binario fa parte di un doppio tracciato. Vuoi eliminare entrambe le direzioni?")
        }
        .onAppear {
            isEditingEnabled = true
        }
        .onChange(of: appState.railroad.topologyId) {
            if let edgeId = appState.selectedEdgeId,
               !network.edges.contains(where: { $0.id.uuidString == edgeId }) {
                appState.selectedEdgeId = nil
            }
        }
        .onDisappear {
            isEditingEnabled = false
            Task { loader.saveCurrentState() }
        }
    }
    
    // MARK: - Sezioni Interfaccia
    
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
            Picker("type".localized, selection: layoutModeBinding) {
                ForEach(TrackLayoutMode.allCases) { mode in
                    Label(mode.localizationKey.localized, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var layoutModeBinding: Binding<TrackLayoutMode> {
        Binding(
            get: {
                guard let edgeId = appState.selectedEdgeId,
                      let live = network.edges.first(where: { $0.id.uuidString == edgeId })
                else { return .single }
                return TrackLayoutMode.from(live, in: network.edges)
            },
            set: { newMode in
                guard let edgeId = appState.selectedEdgeId.flatMap(UUID.init(uuidString:)),
                      let live = network.edges.first(where: { $0.id == edgeId }),
                      network.edges.contains(where: { $0.id == edgeId }),
                      TrackLayoutMode.from(live, in: network.edges) != newMode
                else { return }
                appState.railroad.applyTrackLayout(
                    newMode,
                    to: edgeId,
                    singleMaxSpeed: Int(appState.singleTrackMaxSpeed),
                    highSpeedMaxSpeed: Int(appState.highSpeedTrackMaxSpeed)
                )
            }
        )
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

                if let warning = parametersWarning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(), value: parametersWarning)
        }
    }
    
    private var parametersWarning: String? {
        if edge.maxSpeed > 350 { return "Velocità eccessiva (>350 km/h)" }
        if edge.trackType == .single && edge.maxSpeed > 160 { return "Velocità elevata per binario singolo" }
        if edge.distance <= 0 { return "Distanza non valida" }
        if (edge.capacity ?? 0) < 1 { return "Capacità insufficiente" }
        return nil
    }
    
    // MARK: - Profilo altimetrico

    private var altimetricProfileSection: some View {
        InspectorSection(
            title: "Profilo altimetrico",
            icon: "chart.xyaxis.line",
            iconColor: .teal
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 24) {
                    altitudeStat("Quota Da", altitude: fromStation?.altitude)
                    altitudeStat("Quota A",  altitude: toStation?.altitude)
                    altitudeStat("Pendenza", text: averageSlopeText)
                }
                Button("Modifica profilo...") { showProfileSheet = true }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func altitudeStat(_ label: String, altitude: Double? = nil, text: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(text ?? (altitude.map { "\(Int($0)) m" } ?? "— m"))
                .font(.subheadline.bold())
        }
    }

    private var averageSlopeText: String {
        let dAlt = (toStation?.altitude ?? 0) - (fromStation?.altitude ?? 0)
        let distM = edge.distance * 1000.0
        guard distM > 0 else { return "—" }
        return String(format: "%.1f ‰", (dAlt / distM) * 1000.0)
    }
}
