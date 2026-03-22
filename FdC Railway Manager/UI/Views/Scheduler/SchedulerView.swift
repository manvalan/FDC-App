import SwiftUI
import Combine
import UniformTypeIdentifiers
import Foundation
import Charts

// MARK: - ViewModel

@MainActor
final class SchedulerViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var schedulerResult = ""
    @Published var errorMessage: String? = nil

    func calculateTimetables(
        network: NetworkModel,
        lines: LinesManager,
        aiService: RailwayAIService
    ) {
        isLoading = true
        schedulerResult = "calculating_in_progress".localized
        errorMessage = nil
        let dto = RailwayNetworkDTO(
            name: "Temp",
            nodes: network.nodes,
            edges: network.edges,
            lines: network.lines,
            routes: lines.routes,
            trains: lines.trains,
            vehicles: lines.vehicles
        )
        sendToScheduler(dto: dto, trains: lines.trains, aiService: aiService) { [weak self] result in
            self?.isLoading = false
            switch result {
            case .success(let response):
                self?.schedulerResult = response
            case .failure(let error):
                self?.schedulerResult = ""
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    func simulateLocally(lines: LinesManager) {
        isLoading = true
        errorMessage = nil
        Task { @MainActor in
            lines.refreshSchedules()
            lines.validateSchedules()
            self.isLoading = false
        }
    }

    func conflicts(in result: String) -> [String]? {
        let conflictLines = result.components(separatedBy: "\n")
            .filter {
                $0.localizedCaseInsensitiveContains("conflitto") ||
                $0.localizedCaseInsensitiveContains("conflict")
            }
        return conflictLines.isEmpty ? nil : conflictLines
    }
}

// MARK: - View

struct SchedulerView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var aiService: RailwayAIService
    @StateObject private var viewModel = SchedulerViewModel()

    private var railroad: RailroadNetwork { appState.railroad }
    private var network: NetworkModel { railroad.network }
    private var lines: LinesManager { railroad.lines }

    @State private var showTrains = false
    @State private var selectedSchedule: TrainSchedule? = nil
    @State private var showExport = false
    @State private var showChart = false
    @State private var showManualEdit = false
    @State private var showPrint = false
    @State private var showImport = false
    @State private var selectedTrain: String = ""
    @State private var selectedStation: String = ""
    @State private var filterTimeFrom: Double? = nil
    @State private var filterTimeTo: Double? = nil

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    trainsSection
                    timetableSection
                    localSimulationSection
                    conflictDashboardSection
                    manualEditSection
                    exportSection
                    importSection
                    statusSection
                    resultSection
                }
            }
            .navigationTitle("scheduler_title".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showImport = true }) {
                        Label(
                            "import_fdc_button".localized,
                            systemImage: "tray.and.arrow.down"
                        )
                    }
                }
            }
            .sheet(isPresented: $showTrains) {
                TrainsDetailView(manager: lines)
            }
            .fileExporter(
                isPresented: $showExport,
                document: SchedulerResultDocument(result: viewModel.schedulerResult),
                contentType: .plainText,
                defaultFilename: "orari_conflitti.txt"
            ) { _ in }
            .sheet(isPresented: $showChart) {
                TimetableChartView(schedulerResult: viewModel.schedulerResult)
            }
            .sheet(isPresented: $showManualEdit) {
                ManualEditView(schedulerResult: $viewModel.schedulerResult)
            }
            .sheet(isPresented: $showPrint) {
                PrintView(text: viewModel.schedulerResult)
            }
            .fileImporter(
                isPresented: $showImport,
                allowedContentTypes: [.fdc, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first,
                       let data = try? Data(contentsOf: url),
                       let str = String(data: data, encoding: .utf8) {
                        viewModel.schedulerResult = str
                    }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
            .sheet(item: $selectedSchedule) { schedule in
                TrainTimetableView(schedule: schedule, simulator: appState.simulator)
            }
        }
    }

    // MARK: - Sections

    private var trainsSection: some View {
        Section(header: Text("trains_to_schedule".localized)) {
            Button("manage_trains".localized) { showTrains = true }
            ForEach(lines.trains) { train in
                VStack(alignment: .leading) {
                    Text(train.name).font(.headline)
                    Text(
                        String(format: "type_speed_label".localized, train.type, train.maxSpeed)
                    ).font(.caption)
                }
            }
        }
    }

    private var timetableSection: some View {
        Section(header: Text("timetable_traffic_sim".localized)) {
            Button("calculate_timetables".localized) {
                viewModel.calculateTimetables(
                    network: network,
                    lines: lines,
                    aiService: aiService
                )
            }.disabled(viewModel.isLoading || lines.trains.isEmpty)
            Button("export_result".localized) {
                showExport = true
            }.disabled(viewModel.schedulerResult.isEmpty)
            Button("view_timetable_chart".localized) {
                showChart = true
            }.disabled(viewModel.schedulerResult.isEmpty)
        }
    }

    private var localSimulationSection: some View {
        Section(header: Text("local_infrastructure".localized)) {
            Button("simulate_full_network".localized) {
                viewModel.simulateLocally(lines: lines)
            }.disabled(lines.trains.isEmpty || lines.routes.isEmpty)

            ForEach(appState.simulator.schedules) { schedule in
                Button(action: { selectedSchedule = schedule }) {
                    scheduleRow(schedule)
                }
            }
        }
    }

    private var conflictDashboardSection: some View {
        Group {
            if !appState.simulator.activeConflicts.isEmpty {
                Section(header: Text("conflict_dashboard".localized)) {
                    ConflictDashboardView(
                        conflicts: appState.simulator.activeConflicts.map(mapConflict),
                        network: network,
                        trains: lines.trains,
                        onFocusConflict: { _ in }
                    )
                    .listRowInsets(EdgeInsets())
                    .background(Color.clear)
                }
            }
        }
    }

    private var manualEditSection: some View {
        Section(header: Text("manual_timetable_edit".localized)) {
            Button("edit_timetables_manually".localized) {
                showManualEdit = true
            }.disabled(viewModel.schedulerResult.isEmpty)
        }
    }

    private var exportSection: some View {
        Section(header: Text("advanced_export_print".localized)) {
            Button("copy_to_clipboard".localized) {
                UIPasteboard.general.string = viewModel.schedulerResult
            }.disabled(viewModel.schedulerResult.isEmpty)
            Button("print_result".localized) {
                showPrint = true
            }.disabled(viewModel.schedulerResult.isEmpty)
        }
    }

    private var importSection: some View {
        Section(header: Text("file_import".localized)) {
            Button("import_fdc_txt".localized) { showImport = true }
        }
    }

    private var statusSection: some View {
        Group {
            if viewModel.isLoading { ProgressView() }
            if let message = viewModel.errorMessage {
                Section { Text(message).foregroundColor(.red) }
            }
        }
    }

    private var resultSection: some View {
        Group {
            if !viewModel.schedulerResult.isEmpty {
                Section(header: Text("timetables_conflicts_result".localized)) {
                    ScrollView {
                        Text(viewModel.schedulerResult)
                            .font(.body)
                            .foregroundColor(.purple)
                            .lineLimit(nil)
                            .padding(.vertical, 4)
                    }
                    timetableChart
                    conflictList
                }
            }
        }
    }

    private var timetableChart: some View {
        let filteredData = TimetableChartData.parse(from: viewModel.schedulerResult).filter {
            (selectedTrain.isEmpty || $0.train == selectedTrain) &&
            (selectedStation.isEmpty || $0.station == selectedStation) &&
            (filterTimeFrom == nil || $0.time >= filterTimeFrom!) &&
            (filterTimeTo == nil || $0.time <= filterTimeTo!)
        }
        return Group {
            if filteredData.count > 0 {
                TimetableChart(data: filteredData)
                    .frame(height: 400)
                    .padding(.vertical)
            }
        }
    }

    private var conflictList: some View {
        Group {
            if let conflicts = viewModel.conflicts(in: viewModel.schedulerResult),
               !conflicts.isEmpty {
                Section(header: Text("detected_conflicts".localized)) {
                    ForEach(conflicts, id: \.self) { conflict in
                        Text(conflict).foregroundColor(.red)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func scheduleRow(_ schedule: TrainSchedule) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(schedule.trainName).font(.headline)
                Text(
                    String(format: "stops_count_label".localized, schedule.stops.count)
                ).font(.caption)
            }
            Spacer()
            if schedule.totalDelayMinutes > 0 {
                Text("+\(schedule.totalDelayMinutes)\("min_short".localized)")
                    .font(.caption)
                    .padding(4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(4)
            }
            Image(systemName: "chevron.right")
        }
    }

    private func mapConflict(_ c: Conflict) -> ScheduleConflict {
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
    }
}

// MARK: - Backend call (Infrastructure)

@MainActor
func sendToScheduler(
    dto: RailwayNetworkDTO,
    trains: [Train],
    aiService: RailwayAIService,
    completion: @escaping (Result<String, Error>) -> Void
) {
    let baseURL = aiService.baseURL
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
    aiService.authManager.attachAuthHeaders(to: &request)
    request.httpBody = data

    let task = URLSession.shared.dataTask(with: request) { data, _, error in
        if let error = error { completion(.failure(error)); return }
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
