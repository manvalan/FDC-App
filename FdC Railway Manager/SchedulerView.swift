import SwiftUI
import UniformTypeIdentifiers
import Foundation
import Charts

struct SchedulerView: View {
    @ObservedObject var network: RailwayNetwork
    @EnvironmentObject var trainManager: TrainManager

    @State private var schedulerResult: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showTrains = false
    @EnvironmentObject var appState: AppState
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
                Section(header: Text("Treni da schedulare")) {
                    Button("Gestisci treni") { showTrains = true }
                    ForEach(trainManager.trains) { train in
                        VStack(alignment: .leading) {
                            Text(train.name).font(.headline)
                            Text("Tipo: \(train.type), Velocità max: \(train.maxSpeed) km/h").font(.caption)
                        }
                    }
                }
                Section(header: Text("Simulazione Orari e Traffico")) {
                    Button("Calcola Orari e Conflitti") {
                        isLoading = true
                        schedulerResult = "Calcolo in corso..."
                        errorMessage = nil
                        sendToScheduler(network: network, trains: trainManager.trains) { result in
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
                    }.disabled(isLoading || trainManager.trains.isEmpty)
                    Button("Esporta risultato") {
                        showExport = true
                    }.disabled(schedulerResult.isEmpty)
                    Button("Visualizza grafico orari") {
                        showChart = true
                    }.disabled(schedulerResult.isEmpty)
                }
                Section(header: Text("Infrastruttura Locale (FDC Engine)")) {
                    Button("Simula Rete Completa") {
                        simulateLocally()
                    }.disabled(trainManager.trains.isEmpty || network.lines.isEmpty)
                    
                    if !appState.simulator.schedules.isEmpty {
                        ForEach(appState.simulator.schedules) { schedule in
                            Button(action: { selectedSchedule = schedule }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(schedule.trainName).font(.headline)
                                        Text("\(schedule.stops.count) fermate").font(.caption)
                                    }
                                    Spacer()
                                    if schedule.totalDelayMinutes > 0 {
                                        Text("+\(schedule.totalDelayMinutes)m")
                                            .font(.caption).padding(4).background(Color.red.opacity(0.1)).cornerRadius(4)
                                    }
                                    Image(systemName: "chevron.right")
                                }
                            }
                        }
                    }
                }
                if !appState.simulator.activeConflicts.isEmpty {
                    Section(header: Text("Conflitti Operativi")) {
                        ForEach(appState.simulator.activeConflicts) { conflict in
                            VStack(alignment: .leading) {
                                HStack {
                                    Image(systemName: conflict.type == .stationOverlap ? "building.2.fill" : "rail.tracks")
                                    Text("\(conflict.type.rawValue) a \(conflict.locationId)").bold()
                                }
                                Text(conflict.trainNames.joined(separator: " vs "))
                                    .font(.caption).foregroundColor(.red)
                            }
                        }
                    }
                }
                Section(header: Text("Editing manuale orari")) {
                    Button("Modifica orari manualmente") {
                        showManualEdit = true
                    }.disabled(schedulerResult.isEmpty)
                }
                Section(header: Text("Esportazione avanzata e stampa")) {
                    Button("Copia risultato negli appunti") {
                        UIPasteboard.general.string = schedulerResult
                    }.disabled(schedulerResult.isEmpty)
                    Button("Stampa risultato") {
                        showPrint = true
                    }.disabled(schedulerResult.isEmpty)
                }
                Section(header: Text("Importazione file")) {
                    Button("Importa file .fdc o .txt") {
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
                    Section(header: Text("Risultato Orari/Conflitti")) {
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
                            Section(header: Text("Conflitti rilevati")) {
                                ForEach(conflicts, id: \.self) { conflict in
                                    Text(conflict).foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Scheduler")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showImport = true }) {
                        Label("Importa .fdc", systemImage: "tray.and.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $showTrains) {
                TrainsDetailView(manager: trainManager)
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
            var newSchedules: [TrainSchedule] = []
            
            // For each line in the network, try to assign a train and build a schedule
            for (index, line) in network.lines.enumerated() {
                // Pick a train for this line (simple mapping)
                guard index < trainManager.trains.count else { break }
                let train = trainManager.trains[index]
                
                // Build schedule starting today at 08:00 + index * 10 mins
                let baseTime = Calendar.current.date(bySettingHour: 8, minute: index * 15, second: 0, of: Date()) ?? Date()
                
                if let schedule = FDCSchedulerEngine.buildSchedule(train: train, network: network, route: line.stations, startTime: baseTime) {
                    newSchedules.append(schedule)
                }
            }
            
            appState.simulator.schedules = newSchedules
            appState.simulator.resolveConflicts(trains: trainManager.trains, network: network)
            isLoading = false
        }
    }
}

// MARK: - TimetableChartView
struct TimetableChartView: View {
    let schedulerResult: String
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack {
            Text("Grafico Orari Treni")
                .font(.title2)
                .padding(.top)
            TimetableChart(data: TimetableChartData.parse(from: schedulerResult))
                .frame(height: 400)
                .padding()
            Button("Chiudi") { dismiss() }
                .padding(.bottom)
        }
    }
}

struct TimetableChart: View {
    @EnvironmentObject var appState: AppState
    let data: [TimetableChartData] // Fallback for remote results
    
    var body: some View {
        Chart {
            if !appState.simulator.schedules.isEmpty {
                // Professional view from simulator data
                ForEach(appState.simulator.schedules) { schedule in
                    ForEach(schedule.stops) { stop in
                        if let arr = stop.arrivalTime {
                            PointMark(
                                x: .value("Tempo", arr),
                                y: .value("Stazione", stop.stationName)
                            )
                            .foregroundStyle(by: .value("Treno", schedule.trainName))
                            .symbolSize(20)
                        }
                        
                        if let dep = stop.departureTime {
                            PointMark(
                                x: .value("Tempo", dep),
                                y: .value("Stazione", stop.stationName)
                            )
                            .foregroundStyle(by: .value("Treno", schedule.trainName))
                            .symbolSize(20)
                        }
                        
                        // Line segment within the station (Dwelling)
                        if let arr = stop.arrivalTime, let dep = stop.departureTime {
                            LineMark(
                                x: .value("Tempo", arr),
                                y: .value("Stazione", stop.stationName)
                            )
                            .foregroundStyle(by: .value("Treno", schedule.trainName))
                            .lineStyle(StrokeStyle(lineWidth: 4))
                            
                            LineMark(
                                x: .value("Tempo", dep),
                                y: .value("Stazione", stop.stationName)
                            )
                            .foregroundStyle(by: .value("Treno", schedule.trainName))
                            .lineStyle(StrokeStyle(lineWidth: 4))
                        }
                    }
                    
                    // Connecting lines between stations
                    ForEach(0..<schedule.stops.count-1, id: \.self) { i in
                        let start = schedule.stops[i]
                        let end = schedule.stops[i+1]
                        if let t1 = start.departureTime ?? start.arrivalTime,
                           let t2 = end.arrivalTime ?? end.departureTime {
                            LineMark(x: .value("T", t1), y: .value("S", start.stationName))
                                .foregroundStyle(by: .value("Treno", schedule.trainName))
                            LineMark(x: .value("T", t2), y: .value("S", end.stationName))
                                .foregroundStyle(by: .value("Treno", schedule.trainName))
                        }
                    }
                }
                
                // Conflict annotations
                ForEach(appState.simulator.activeConflicts) { conflict in
                    RuleMark(x: .value("Conflitto", conflict.startTime))
                        .foregroundStyle(.red.opacity(0.3))
                        .annotation(position: .top) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                }
            } else {
                // Fallback for legacy text results
                ForEach(data) { item in
                    LineMark(
                        x: .value("Orario", item.date),
                        y: .value("Stazione", item.station)
                    )
                    .foregroundStyle(by: .value("Treno", item.train))
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartYAxisLabel("Stazione")
        .chartLegend(position: .bottom)
        .padding()
    }
}

struct TimetableChartData: Identifiable {
    let id = UUID()
    let train: String
    let station: String
    let time: Double // minutes since midnight
    var date: Date {
        let start = Calendar.current.startOfDay(for: Date())
        return Date(timeInterval: time * 60.0, since: start)
    }
    // Parsing semplice da testo (adatta secondo il formato reale)
    static func parse(from result: String) -> [TimetableChartData] {
        var data: [TimetableChartData] = []
        let lines = result.components(separatedBy: "\n")
        for line in lines {
            // Esempio: "Treno: Frecciarossa 9600 | Stazione: Milano | Orario: 8.00"
            if line.contains("Treno:") && line.contains("Stazione:") && line.contains("Orario:") {
                let comps = line.components(separatedBy: "|")
                if comps.count == 3 {
                    let train = comps[0].replacingOccurrences(of: "Treno:", with: "").trimmingCharacters(in: .whitespaces)
                    let station = comps[1].replacingOccurrences(of: "Stazione:", with: "").trimmingCharacters(in: .whitespaces)
                    let timeStr = comps[2].replacingOccurrences(of: "Orario:", with: "").trimmingCharacters(in: .whitespaces)
                    if let norm = FDCParser.normalizeTimeString(timeStr) {
                        let parts = norm.split(separator: ":").map { Int($0) ?? 0 }
                        if parts.count == 2 {
                            let minutes = Double(parts[0] * 60 + parts[1])
                            data.append(TimetableChartData(train: train, station: station, time: minutes))
                        }
                    } else if let time = Double(timeStr.replacingOccurrences(of: ",", with: ".")) {
                        let hours = Int(floor(time))
                        let minutes = Int(((time - Double(hours)) * 60).rounded())
                        data.append(TimetableChartData(train: train, station: station, time: Double(hours * 60 + minutes)))
                    }
                }
            } else {
                // Fallback parsing
                let tokens = line.components(separatedBy: "|")
                var train = ""
                var station = ""
                var foundTimeToken: String? = nil
                for tok in tokens {
                    if tok.localizedCaseInsensitiveContains("treno") || tok.localizedCaseInsensitiveContains("train") {
                        train = tok.replacingOccurrences(of: "Treno:", with: "").replacingOccurrences(of: "Train:", with: "").trimmingCharacters(in: .whitespaces)
                    } else if tok.localizedCaseInsensitiveContains("stazione") || tok.localizedCaseInsensitiveContains("station") {
                        station = tok.replacingOccurrences(of: "Stazione:", with: "").replacingOccurrences(of: "Station:", with: "").trimmingCharacters(in: .whitespaces)
                    } else if FDCParser.normalizeTimeString(tok) != nil {
                        foundTimeToken = tok.trimmingCharacters(in: .whitespaces)
                    }
                }
                if (train.isEmpty || station.isEmpty), tokens.count == 1 {
                    let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if parts.count >= 3 {
                        train = parts.first ?? ""
                        station = parts.last ?? ""
                        for part in parts { if FDCParser.normalizeTimeString(part) != nil { foundTimeToken = part; break } }
                    }
                }
                if !train.isEmpty && !station.isEmpty, let ft = foundTimeToken, let tnorm = FDCParser.normalizeTimeString(ft) {
                    let parts = tnorm.split(separator: ":").map { Int($0) ?? 0 }
                    if parts.count == 2 {
                        let minutes = Double(parts[0] * 60 + parts[1])
                        data.append(TimetableChartData(train: train, station: station, time: minutes))
                    }
                }
            }
        }
        return data
    }
}

// MARK: - TrainsDetailView
struct TrainsDetailView: View {
    @ObservedObject var manager: TrainManager
    @State private var showAdd = false
    @State private var newName = ""
    @State private var newType = "Regionale"
    @State private var newMaxSpeed = 120
    var body: some View {
        NavigationStack {
            List {
                ForEach(manager.trains) { train in
                    VStack(alignment: .leading) {
                        Text(train.name).font(.headline)
                        Text("Tipo: \(train.type), Velocità max: \(train.maxSpeed) km/h").font(.caption)
                    }
                }
                .onDelete { manager.trains.remove(atOffsets: $0) }
            }
            .navigationTitle("Gestione Treni")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAdd = true }) {
                        Label("Aggiungi treno", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                NavigationStack {
                    Form {
                        TextField("Nome treno", text: $newName)
                        TextField("Tipo", text: $newType)
                        TextField("Velocità max (km/h)", value: $newMaxSpeed, format: .number)
                    }
                    .navigationTitle("Nuovo Treno")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Annulla") { showAdd = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Aggiungi") {
                                guard !newName.isEmpty else { return }
                                 manager.trains.append(Train(id: UUID(), name: newName, type: newType, maxSpeed: newMaxSpeed, priority: 5, acceleration: 0.5, deceleration: 0.5))
                                newName = ""
                                newType = "Regionale"
                                newMaxSpeed = 120
                                showAdd = false
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - SchedulerResultDocument
struct SchedulerResultDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType.plainText] }
    var result: String
    init(result: String) { self.result = result }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let str = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.result = str
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = result.data(using: .utf8) ?? Data()
        return .init(regularFileWithContents: data)
    }
}


struct FDCFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.fdc, .plainText] }
    var content: String
    init(content: String = "") {
        self.content = content
    }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let str = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = str
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8) ?? Data()
        return .init(regularFileWithContents: data)
    }
}

// Funzione per chiamare il backend FDC_Scheduler
@MainActor
func sendToScheduler(network: RailwayNetwork, trains: [Train], completion: @escaping (Result<String, Error>) -> Void) {
    guard let url = URL(string: "http://82.165.138.64:8080/scheduler") else {
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
    let payload = Payload(network: network.toDTO(), trains: trains)
    guard let data = try? JSONEncoder().encode(payload) else {
        completion(.failure(NSError(domain: "Serializzazione JSON fallita", code: 0)))
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
        // SchedulerResponse uses types that may be MainActor-isolated in the project.
        // Decode on the MainActor to satisfy actor isolation rules.
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

// MARK: - ManualEditView
struct ManualEditView: View {
    @Binding var schedulerResult: String
    @Environment(\.dismiss) var dismiss
    @State private var editedText: String = ""
    var body: some View {
        VStack(alignment: .leading) {
            Text("Modifica manuale orari e conflitti")
                .font(.headline)
                .padding(.top)
            TextEditor(text: $editedText)
                .font(.system(.body, design: .monospaced))
                .border(Color.gray)
                .padding(.vertical)
            HStack {
                Spacer()
                Button("Annulla") { dismiss() }
                Button("Salva") {
                    schedulerResult = editedText
                    dismiss()
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear { editedText = schedulerResult }
    }
}

// MARK: - PrintView
struct PrintView: View {
    let text: String
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(alignment: .leading) {
            Text("Anteprima di stampa")
                .font(.headline)
                .padding(.top)
            ScrollView {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            HStack {
                Spacer()
                Button("Chiudi") { dismiss() }
                Button("Stampa") {
                    printText(text)
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    func printText(_ text: String) {
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "Orari e conflitti"
        printController.printInfo = printInfo
        let formatter = UISimpleTextPrintFormatter(text: text)
        printController.printFormatter = formatter
        printController.present(animated: true, completionHandler: nil)
    }
}

// Funzioni per il caricamento e il salvataggio della rete ferroviaria
extension SchedulerView {
    @MainActor
    func loadRailwayNetwork(from url: URL) {
        do {
            let loadedNetwork = try RailwayNetwork.loadFromFile(url: url)
            network.name = loadedNetwork.name
            network.nodes = loadedNetwork.nodes
            network.edges = loadedNetwork.edges
        } catch {
            errorMessage = "Errore durante il caricamento della rete: \(error.localizedDescription)"
        }
    }

    @MainActor
    func saveRailwayNetwork(to url: URL) {
        do {
            try network.saveToFile(url: url)
        } catch {
            errorMessage = "Errore durante il salvataggio della rete: \(error.localizedDescription)"
        }
    }
}
