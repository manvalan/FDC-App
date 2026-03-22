import SwiftUI

struct LineScheduleView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var manager: TrainManager
    let line: TrainRoute
    
    // View Mode
    enum ScheduleMode: String, CaseIterable, Identifiable {
        case graph = "Grafico"
        case table = "Tabella"
        var id: String { self.rawValue }
    }
    @State private var mode: ScheduleMode = .graph
    
    // Shared Data (Calculated Once)
    @State private var orderedStations: [Node] = []
    @State private var stationDistances: [Double] = [] // Cumulative distance
    @State private var maxDistance: Double = 0
    enum InspectorMode: String, CaseIterable, Identifiable {
        case schedule = "Tabellone"
        case occupancy = "Occupazione"
        var id: String { rawValue }
    }
    @State private var inspectorMode: InspectorMode = .schedule
    
    // Selection State
    struct StationSelection: Identifiable {
        let id: String
    }
    @State private var selectedStation: StationSelection? = nil
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        mainContent
            .navigationTitle("Orario: \(line.name)")
            .onAppear {
                calculateLineGeometry()
            }
            .onChange(of: appState.selectedTrainIds) { ids in
                if !ids.isEmpty {
                    appState.activePanel = .inspector
                }
            }
    }
    
    
    @ViewBuilder
    var mainContent: some View {
        // MAIN CONTENT
        VStack(spacing: 0) {
            if let selection = selectedStation, let station = network.nodes.first(where: { $0.id == selection.id }) {
                // Station Schedule Mode
                VStack(spacing: 0) {
                    HStack {
                        Text(station.name).font(.title3).bold()
                        Spacer()
                        Button(action: { withAnimation { selectedStation = nil } }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(appState.theme.light.opacity(0.3))
                    
                    StationScheduleView(station: station)
                }
            } else {
                // Line Mode (Graph/Table)
                VStack(spacing: 0) {
                    Picker("Vista", selection: $mode) {
                        ForEach(ScheduleMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    Group {
                        switch mode {
                        case .graph:
                            LineGraphView(
                                line: line,
                                orderedStations: orderedStations,
                                stationDistances: stationDistances,
                                maxDistance: maxDistance,
                                selectedStation: $selectedStation
                            )
                        case .table:
                            LineTableView(
                                line: line,
                                orderedStations: orderedStations,
                                selectedStation: $selectedStation
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
    }
    
    private func exportPDF() {
        let pdfView = LinePDFExportView(
            route: line,
            orderedStations: orderedStations,
            trains: manager.trains,
            network: network
        )
        
        if let url = ExportUtils.exportViewAsPDF(content: pdfView, fileName: "Orario_\(line.name)") {
            ExportUtils.shareItem(url)
        }
    }
    
    // MARK: - Geometry Calculation
    // MARK: - Geometry Calculation
    private func calculateLineGeometry() {
        // Use the Line's defined station list as the master skeleton
        // This ensures the graph/table shows the full infrastructure, not just one train's path.
        
        var stations: [Node] = []
        var distances: [Double] = []
        var currentDist: Double = 0
        
        let stationIds = line.stationIds
        
        guard !stationIds.isEmpty else { return }
        
        // Add First Station
        if let firstId = stationIds.first, let node = network.nodes.first(where: { $0.id == firstId }) {
            stations.append(node)
            distances.append(0)
            
            var prevId = firstId
            
                // Traverse the rest
            for nextId in stationIds.dropFirst() {
                if let edge = network.findEdge(from: prevId, to: nextId) {
                    currentDist += edge.distance
                } else if let distInfo = network.findShortestPath(from: prevId, to: nextId, ignoreDirection: true) {
                    currentDist += distInfo.1
                } else {
                    currentDist += 5.0 
                }
                
                if let node = network.nodes.first(where: { $0.id == nextId }) {
                    stations.append(node)
                    distances.append(currentDist)
                }
                
                prevId = nextId
            }
        }
        
        self.orderedStations = stations
        self.stationDistances = distances
        self.maxDistance = currentDist
    }
}
