import SwiftUI

struct StationEditView: View {
    @Binding var station: RailwayNode
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loader: AppLoaderService
    @StateObject private var viewModel: StationEditViewModel
    @Environment(\.dismiss) var dismiss
    
    var onDelete: (() -> Void)? = nil
    @State private var showDeleteConfirmation = false
    @State private var isRoutingSheetPresented = false
    @State private var localConstraints: [RoutingConstraint] = []
    @State private var localPlatforms: Int = 2
    
    init(station: Binding<RailwayNode>, onDelete: (() -> Void)? = nil) {
        self._station = station
        self.onDelete = onDelete
        self._viewModel = StateObject(wrappedValue: StationEditViewModel())
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                basicInfoSection
                hubsSection
                StationEditVisualSection(station: $station)
                coordinatesSection
                routingConstraintsSummary
                deleteButton
            }
            .padding()
            .disabled(!appState.isInspectorEditingMode)
        }
        .onAppear { 
            viewModel.appState = appState
            localConstraints = station.routingConstraints
            localPlatforms = station.platforms ?? 2
            appState.isInspectorEditingMode = true
        }
        .sheet(isPresented: $isRoutingSheetPresented) {
            RoutingConstraintsSheet(station: $station, localConstraints: $localConstraints, viewModel: viewModel)
        }
        .alert("delete_station".localized, isPresented: $showDeleteConfirmation) {
            Button("cancel".localized, role: .cancel) { }
            Button("delete".localized, role: .destructive) { onDelete?() }
        }
        .onDisappear {
            appState.isInspectorEditingMode = false
            Task { await loader.saveCurrentState() }
        }
    }
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "building.2.fill").font(.largeTitle).foregroundColor(appState.theme.accent)
            VStack(alignment: .leading) {
                Text(station.name).font(.title).fontWeight(.bold)
                Text("edit_station".localized).font(.subheadline).foregroundColor(appState.theme.medium)
            }
            Spacer()
        }
        .padding().background(appState.theme.backgroundSecondary).cornerRadius(12)
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("station_name".localized, text: $station.name).textFieldStyle(.roundedBorder)
            
            Picker("functional_type".localized, selection: $station.type) {
                Text("standard_station".localized).tag(RailwayNode.NodeType.station)
                Text("interchange".localized).tag(RailwayNode.NodeType.interchange)
                Text("depot".localized).tag(RailwayNode.NodeType.depot)
            }
            .pickerStyle(.segmented)
            
            Stepper(value: $localPlatforms, in: 1...20, step: 1) {
                HStack {
                    Text("platform_count".localized)
                    Spacer()
                    Text("\(localPlatforms)").bold()
                }
            }
            .onChange(of: localPlatforms) { station.platforms = $0 }
        }
        .padding().background(appState.theme.backgroundSecondary).cornerRadius(12)
    }

    private var hubsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Centro Scambio").font(.caption.bold()).foregroundColor(appState.theme.medium)
            Picker("Appartiene a", selection: $station.parentHubId) {
                Text("Nessuno").tag(String?.none)
                ForEach(appState.railroad.network.nodes.filter { $0.id != station.id && $0.parentHubId == nil }) { Text($0.name).tag(String?.some($0.id)) }
            }
            if station.parentHubId != nil {
                Picker("Posizione Offset", selection: $station.hubOffsetDirection) {
                    Text("Standard").tag(RailwayNode.HubOffsetDirection?.none)
                    ForEach(RailwayNode.HubOffsetDirection.allCases) { Text($0.localizedName).tag(RailwayNode.HubOffsetDirection?.some($0)) }
                }
                .pickerStyle(.menu)
            }
        }
        .padding().background(appState.theme.backgroundSecondary).cornerRadius(12)
    }

    private var coordinatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COORDINATE").font(.caption.bold()).foregroundColor(appState.theme.medium)
            HStack { 
                Text("Lat")
                TextField("", value: Binding(get: { station.latitude ?? 0.0 }, set: { station.latitude = $0 }), format: .number)
                    .textFieldStyle(.roundedBorder) 
            }
            HStack { 
                Text("Lon")
                TextField("", value: Binding(get: { station.longitude ?? 0.0 }, set: { station.longitude = $0 }), format: .number)
                    .textFieldStyle(.roundedBorder) 
            }
        }
        .padding().background(appState.theme.backgroundSecondary).cornerRadius(12)
    }

    private var routingConstraintsSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("VINCOLI BINARI").font(.caption.bold())
                Spacer()
                Button("Configura") { isRoutingSheetPresented = true }.buttonStyle(.bordered)
            }
            Text("\(station.routingConstraints.count) vincoli attivi").font(.subheadline).foregroundColor(appState.theme.medium)
        }
        .padding().background(appState.theme.backgroundSecondary).cornerRadius(12)
    }

    private var deleteButton: some View {
        Button(role: .destructive) { showDeleteConfirmation = true } label: {
            Text("Elimina Stazione").frame(maxWidth: .infinity).padding().background(Color.red.opacity(0.1)).cornerRadius(12)
        }
    }
}
