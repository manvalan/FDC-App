import SwiftUI
import Combine
import UniformTypeIdentifiers
import Foundation
import Charts

struct SchedulerView: View {
    @EnvironmentObject var appState: AppState
    private var railroad: RailroadNetwork { appState.railroad }
    private var network: NetworkModel { railroad.network }
    private var lines: LinesManager { railroad.lines }

    @State private var schedulerResult: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showTrains = false
    @State private var selectedSchedule: TrainSchedule? = nil
    @State private var showExport = false
    @State private var showChart = false
    @State private var showManualEdit = false
    @State private var showPrint = false
    @State private var showImport = false
    // Filtri per la visualizzazione grafica e testuale
    @State private var selectedTrain: String = ""
    @State private var selectedStation: String = ""
    @State private var filterTimeFrom: Double? = nil
    @State private var filterTimeTo: Double? = nil
    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section(header: Text("trains_to_schedule".localized)) {
                        Button("manage_trains".localized) { showTrains = true }
                    ForEach(lines.trains) { train in
                        VStack(alignment: .leading) {
                            Text(train.name).font(.headline)
                            Text(String(format: "type_speed_label".localized, train.type, train.maxSpeed)).font(.caption)
                        }
                    }
                }
                Section(header: Text("timetable_traffic_sim".localized)) {
                    Button("calculate_timetables".localized) {
                        isLoading = true
                        schedulerResult = "calculating_in_progress".localized
                        errorMessage = nil
                        let dto = RailwayNetworkDTO(name: "Temp", nodes: network.nodes, edges: network.edges, lines: network.lines, routes: lines.routes, trains: lines.trains, vehicles: lines.vehicles)
                        sendToScheduler(dto: dto, trains: lines.trains) { result in
                            DispatchQueue.main.async {
                                isLoading = false
                                switch result {
                                case .success(let response):
                                    schedulerResult = response
                                case .failure(let error):
                                    schedulerResult = ""
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    }.disabled(isLoading || lines.trains.isEmpty)
                    Button("export_result".localized) {
                        showExport = true
                    }.disabled(schedulerResult.isEmpty)
                    Button("view_timetable_chart".localized) {
                        showChart = true
                    }.disabled(schedulerResult.isEmpty)
                }
                Section(header: Text("local_infrastructure".localized)) {
                    Button("simulate_full_network".localized) {
                        simulateLocally()
                    }.disabled(lines.trains.isEmpty || lines.routes.isEmpty)
                    
                    if !appState.simulator.schedules.isEmpty {
                        ForEach(appState.simulator.schedules) { schedule in
                            Button(action: { selectedSchedule = schedule }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(schedule.trainName).font(.headline)
                                        Text(String(format: "stops_count_label".localized, schedule.stops.count)).font(.caption)
                                    }
                                    Spacer()
                                    if schedule.totalDelayMinutes > 0 {
                                        Text("+\(schedule.totalDelayMinutes)\("min_short".localized)")
                                            .font(.caption).padding(4).background(Color.red.opacity(0.1)).cornerRadius(4)
                                    }
                                    Image(systemName: "chevron.right")
                                }
                            }
                        }
                    }
                }
                if !appState.simulator.activeConflicts.isEmpty {
                    Section(header: Text("conflict_dashboard".localized)) {
                        ConflictDashboardView(
                            conflicts: appState.simulator.activeConflicts.map { c in
                                ScheduleConflict(
                                    trainAId: c.trainIds.first ?? UUID(),
                                    trainBId: c.trainIds.last ?? UUID(),
                                    trainAName: c.trainNames.first ?? "unknown_train".localized,
                                    trainBName: c.trainNames.last ?? "unknown_train".localized,
                                    locationType: c.type == .stationOverlap ? .station : .line,
                                    locationName: network.nodes.first(where: { $0.id == c.locationId })?.name ?? c.locationId,
                                    locationId: c.locationId,
                                    timeStart: c.startTime,
                                    timeEnd: c.endTime,
                                    capacity: 1,
                                    occupantsCount: 2
                                )
                            },
                            network: network,
                            trains: lines.trains,
                            onFocusConflict: { conflict in
                                // Optional: logic to center map on conflict
                            }
                        )
                        .listRowInsets(EdgeInsets())
                        .background(Color.clear)
                    }
                }
                Section(header: Text("manual_timetable_edit".localized)) {
                    Button("edit_timetables_manually".localized) {
                        showManualEdit = true
                    }.disabled(schedulerResult.isEmpty)
                }
                Section(header: Text("advanced_export_print".localized)) {
                    Button("copy_to_clipboard".localized) {
                        UIPasteboard.general.string = schedulerResult
                    }.disabled(schedulerResult.isEmpty)
                    Button("print_result".localized) {
                        showPrint = true
                    }.disabled(schedulerResult.isEmpty)
                }
                Section(header: Text("file_import".localized)) {
                    Button("import_fdc_txt".localized) {
                        showImport = true
                    }
                }
                if isLoading {
                    ProgressView()
                }
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }
                if !schedulerResult.isEmpty {
                    Section(header: Text("timetables_conflicts_result".localized)) {
                        ScrollView {
                            Text(schedulerResult)
                                .font(.body)
                                .foregroundColor(.purple)
                                .lineLimit(nil)
                                .padding(.vertical, 4)
                        }
                        // Visualizzazione grafica filtrata
                        let filteredData = TimetableChartData.parse(from: schedulerResult).filter { item in
                            (selectedTrain.isEmpty || item.train == selectedTrain) &&
                            (selectedStation.isEmpty || item.station == selectedStation) &&
                            (filterTimeFrom == nil || item.time >= filterTimeFrom!) &&
                            (filterTimeTo == nil || item.time <= filterTimeTo!)
                        }
                        if filteredData.count > 0 {
                            TimetableChart(data: filteredData)
                                .frame(height: 400)
                                .padding(.vertical)
                        }
                        // Gestione conflitti dettagliata
                        if let conflicts = parseConflicts(from: schedulerResult), !conflicts.isEmpty {
                            Section(header: Text("detected_conflicts".localized)) {
                                ForEach(conflicts, id: \.self) { conflict in
                                    Text(conflict).foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
                }
            }
            .navigationTitle("scheduler_title".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showImport = true }) {
                        Label("import_fdc_button".localized, systemImage: "tray.and.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $showTrains) {
                TrainsDetailView(manager: lines)
            }
            .fileExporter(isPresented: $showExport, document: SchedulerResultDocument(result: schedulerResult), contentType: .plainText, defaultFilename: "orari_conflitti.txt") { _ in }
            .sheet(isPresented: $showChart) {
                TimetableChartView(schedulerResult: schedulerResult)
            }
            .sheet(isPresented: $showManualEdit) {
                ManualEditView(schedulerResult: $schedulerResult)
            }
            .sheet(isPresented: $showPrint) {
                PrintView(text: schedulerResult)
            }
            .fileImporter(isPresented: $showImport, allowedContentTypes: [.fdc, .plainText], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first, let data = try? Data(contentsOf: url), let str = String(data: data, encoding: .utf8) {
                        schedulerResult = str
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .sheet(item: $selectedSchedule) { schedule in
                TrainTimetableView(schedule: schedule, simulator: appState.simulator)
            }
        }
    }
    
    func simulateLocally() {
        isLoading = true
        errorMessage = nil
        
        // Use a MainActor task for simulation to safely access @Published properties
        Task { @MainActor in
            lines.refreshSchedules()
            lines.validateSchedules()
            isLoading = false
        }
    }
}

extension SchedulerView {
    @MainActor
    func loadRailwayNetwork(from url: URL) {
        do {
            let loadedNetwork = try RailwayNetwork.loadFromFile(url: url)
            network.name = loadedNetwork.name
            network.nodes = loadedNetwork.nodes
            network.edges = loadedNetwork.edges
        } catch {
            errorMessage = String(format: "network_load_error".localized, error.localizedDescription)
        }
    }

    @MainActor
    func saveRailwayNetwork(to url: URL) {
        do {
            try network.saveToFile(url: url)
        } catch {
            errorMessage = String(format: "network_save_error".localized, error.localizedDescription)
        }
    }
}

// Funzione per chiamare il backend FDC_Scheduler
@MainActor
func sendToScheduler(dto: RailwayNetworkDTO, trains: [Train], completion: @escaping (Result<String, Error>) -> Void) {
    let baseURL = RailwayAIService.shared.baseURL
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    components?.path = "/scheduler"
    
    guard let url = components?.url else {
        completion(.failure(NSError(domain: "URL non valida", code: 0)))
        return
    }
    
    struct Payload: Codable {
        let network: RailwayNetworkDTO
        let trains: [Train]
    }
    struct SchedulerResponse: Codable {
        let result: String
    }
    let payload = Payload(network: dto, trains: trains)
    guard let data = try? JSONEncoder().encode(payload) else {
        completion(.failure(NSError(domain: "Serializzazione JSON fallita", code: 0)))
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    AuthenticationManager.shared.attachAuthHeaders(to: &request)
    
    request.httpBody = data
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        guard let data = data else {
            completion(.failure(NSError(domain: "Nessun dato ricevuto", code: 0)))
            return
        }
        Task { @MainActor in
            do {
                let decoded = try JSONDecoder().decode(SchedulerResponse.self, from: data)
                completion(.success(decoded.result))
            } catch {
                completion(.failure(error))
            }
        }
     }
     task.resume()
}

// Funzione per parsing conflitti
func parseConflicts(from result: String) -> [String]? {
    let lines = result.components(separatedBy: "\n")
    let conflicts = lines.filter { $0.localizedCaseInsensitiveContains("conflitto") || $0.localizedCaseInsensitiveContains("conflict") }
    return conflicts.isEmpty ? nil : conflicts
}
