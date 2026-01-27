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
    
    var body: some View {
        HStack(spacing: 0) {
            // Main Content (Left)
            VStack(spacing: 0) {
                // Picker
                Picker("Vista", selection: $mode) {
                    ForEach(ScheduleMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
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
            
            // Inspector (Right)
            if let selection = selectedStation, let station = network.nodes.first(where: { $0.id == selection.id }) {
                Divider()
                
                VStack(spacing: 0) {
                    HStack {
                        Text(station.name).font(.headline)
                        Spacer()
                        Button(action: { selectedStation = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    
                    // Inspector View Mode Picker
                    Picker("Vista Dettaglio", selection: $inspectorMode) {
                        ForEach(InspectorMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    if inspectorMode == .schedule {
                        StationScheduleView(station: station)
                    } else {
                        StationOccupancyView(station: station)
                    }
                }
                .frame(width: 350) 
                .background(Color(UIColor.systemBackground))
                .transition(.move(edge: .trailing))
            }
        }
        .navigationTitle("Orario: \(line.name)")
        .onAppear {
            calculateLineGeometry()
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
