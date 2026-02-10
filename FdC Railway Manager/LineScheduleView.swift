import SwiftUI

struct LineScheduleView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var manager: TrainManager
    let line: RailwayLine
    
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
        HStack(spacing: 0) {
            // Main Content (Left)
            VStack(spacing: 0) {
                if let selection = selectedStation, let station = network.nodes.first(where: { $0.id == selection.id }) {
                    // Panel style station schedule
                    VStack(spacing: 0) {
                        HStack {
                            Text(station.name).font(.title3).bold()
                            Spacer()
                            Button(action: {
                                withAnimation { selectedStation = nil }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        
                        StationScheduleView(station: station)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Line Content (Table or Graph)
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
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: exportPDF) {
                        Label("Esporta PDF", systemImage: "doc.plaintext.fill")
                    }
                }
            }
            
            Divider()
            
            // Side Column: Details or Graphical Line Diagram (Right)
            Group {
                if appState.selectedTrainIds.count == 1,
                   let trainId = appState.selectedTrainIds.first,
                   let train = manager.trains.first(where: { $0.id == trainId }) {
                    
                    VStack(spacing: 0) {
                        HStack {
                            Text("Dettagli Treno").font(.headline)
                            Spacer()
                            Button(action: { appState.selectedTrainIds = [] }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        
                        TrainDetailView(train: train)
                    }
                    .frame(width: 350)
                    .background(Color(UIColor.secondarySystemBackground))
                    .transition(.move(edge: .trailing))
                } else {
                    LineVerticalDiagram(
                        line: line,
                        orderedStations: orderedStations,
                        selectedStation: $selectedStation,
                        onLineClick: {
                            withAnimation { selectedStation = nil }
                        }
                    )
                    .frame(width: 250)
                    .background(Color(UIColor.secondarySystemBackground))
                }
            }
        }
        .navigationTitle("Orario: \(line.name)")
        .onAppear {
            calculateLineGeometry()
        }
        .id(line.id) // Ensure state refresh on line change
    }
    
    private func exportPDF() {
        let pdfView = LinePDFExportView(
            line: line,
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
        
        let stationIds = line.stations
        
        guard !stationIds.isEmpty else { return }
        
        // Add First Station
        if let firstId = stationIds.first, let node = network.nodes.first(where: { $0.id == firstId }) {
            stations.append(node)
            distances.append(0)
            
            var prevId = firstId
            
            // Traverse the rest
            for nextId in stationIds.dropFirst() {
                // Find distance from prev to next
                // Note: This assumes the line stations are ordered physically.
                // If they are not connected directly, findShortestPath will find the route.
                
                if let distInfo = network.findShortestPath(from: prevId, to: nextId) {
                    currentDist += distInfo.1
                } else {
                    // If no path found (disconnected graph?), add a provisional distance
                    currentDist += 10.0 
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
